import 'package:dartkds/models/database.dart';
import 'package:dartkds/models/order_status.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// The seeding statements below run against a bare executor, before any
/// `KDSDatabase` owns it, so drift has no `QueryExecutorUser` to hand out yet.
/// Its [schemaVersion] is irrelevant here — the migration is driven by
/// `PRAGMA user_version`, which [_seed] sets after the tables exist.
class _SeedUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor e, OpeningDetails details) async {}

  Future<void> applyMigration(
    QueryExecutor e,
    int from,
    int to,
    MigrationStrategy strategy,
  ) async {}
}

/// The `k_d_s_orders` schema as it looked at version 12, i.e. with the `is_tab`
/// flag that version 13 retired. Only the tables the v13 migration touches are
/// reproduced here; a partial schema is fine because nothing else is queried.
const _v12Orders = '''
CREATE TABLE "k_d_s_orders" (
  "uuid" TEXT NOT NULL CHECK (LENGTH("uuid") BETWEEN 36 AND 36),
  "customer_name" TEXT NOT NULL CHECK (LENGTH("customer_name") BETWEEN 1 AND 255),
  "timestamp" DATETIME NOT NULL,
  "status" INTEGER NOT NULL,
  "updated_at_ms" INTEGER NOT NULL DEFAULT 0,
  "is_tab" INTEGER NOT NULL DEFAULT TRUE CHECK ("is_tab" IN (0, 1)),
  PRIMARY KEY ("uuid")
)''';

/// The same table without `is_tab`, i.e. as it looked at version 11. A device
/// that never ran the v12 migration has nothing for v13 to drop.
const _v11Orders = '''
CREATE TABLE "k_d_s_orders" (
  "uuid" TEXT NOT NULL CHECK (LENGTH("uuid") BETWEEN 36 AND 36),
  "customer_name" TEXT NOT NULL CHECK (LENGTH("customer_name") BETWEEN 1 AND 255),
  "timestamp" DATETIME NOT NULL,
  "status" INTEGER NOT NULL,
  "updated_at_ms" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ("uuid")
)''';

const _v11Items = '''
CREATE TABLE "k_d_s_items" (
  "id" INTEGER NOT NULL,
  "uuid" TEXT NOT NULL,
  "order_uuid" TEXT NOT NULL REFERENCES k_d_s_orders (uuid),
  "name" TEXT NOT NULL,
  "modifiers" TEXT NOT NULL,
  "station_tag" TEXT NOT NULL,
  "status" INTEGER NOT NULL,
  "price" REAL NOT NULL DEFAULT 0.0,
  "updated_at_ms" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ("id")
)''';

final _uuidA = const Uuid().v4();
final _uuidB = const Uuid().v4();

/// Builds a database pinned to [schemaVersion] (`PRAGMA user_version`, which is
/// what drift reads to decide which migrations to run), holding one order
/// created by the tabs-era UI and one created by the Square webhook.
Future<QueryExecutor> _seed(int schemaVersion, String ordersDdl) async {
  final executor = NativeDatabase.memory(
    setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
  );
  await executor.ensureOpen(_SeedUser());
  await executor.runCustom(ordersDdl);
  await executor.runCustom(_v11Items);
  await executor.runCustom(
    'CREATE INDEX order_status ON k_d_s_orders (status)',
  );
  await executor.runCustom(
    'CREATE INDEX order_time ON k_d_s_orders (timestamp)',
  );
  // Drift stores DateTime as Unix seconds, not as a formatted string.
  const stampA = 1767261600; // 2026-01-01 10:00:00 UTC
  const stampB = 1767265200; // 2026-01-01 11:00:00 UTC
  await executor.runCustom(
    'INSERT INTO k_d_s_orders '
    '(uuid, customer_name, timestamp, status, updated_at_ms) VALUES '
    "('$_uuidA', 'Table 4', $stampA, 0, 5), "
    "('$_uuidB', 'Square POS', $stampB, 1, 7)",
  );
  await executor.runCustom(
    'INSERT INTO k_d_s_items '
    '(id, uuid, order_uuid, name, modifiers, station_tag, status) VALUES '
    "(1, '${const Uuid().v4()}', '$_uuidA', 'Burger', '', 'GRILL', 0), "
    "(2, '${const Uuid().v4()}', '$_uuidB', 'Fries', '', 'FRY', 0)",
  );
  await executor.runCustom('PRAGMA user_version = $schemaVersion');
  return executor;
}

void main() {
  group('kds_orders migration to version 13', () {
    test('drops is_tab and keeps orders, indices and foreign keys', () async {
      final executor = await _seed(12, _v12Orders);
      final db = KDSDatabase.forTesting(executor);

      // Touching the database is what runs the migration.
      await db.customSelect('SELECT 1').get();

      expect(db.schemaVersion, 13);

      final orders = await db.select(db.kDSOrders).get();
      expect(
        orders.map((o) => o.customerName).toSet(),
        {'Table 4', 'Square POS'},
      );
      expect(orders.map((o) => o.updatedAtMs).toSet(), {5, 7});
      expect(
        orders.map((o) => o.status).toSet(),
        {OrderStatus.pending, OrderStatus.partial},
      );

      final items = await db.select(db.kDSItems).get();
      expect(items.length, 2);

      // Both indices the v10 migration created must still be there, otherwise
      // every kitchen query that sorts or filters by order pays a table scan.
      final indices = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'k_d_s_orders' AND name LIKE 'order%'",
          )
          .get();
      expect(indices.map((r) => r.read<String>('name')).toSet(), {
        'order_status',
        'order_time',
      });

      // The child reference still has to be enforced.
      await expectLater(
        db.customStatement(
          'INSERT INTO k_d_s_items (id, uuid, order_uuid, name, modifiers, '
          "station_tag, status) VALUES (3, '${const Uuid().v4()}', "
          "'${const Uuid().v4()}', 'Ghost', '', 'GRILL', 0)",
        ),
        throwsA(anything),
      );

      await db.close();
    });

    test('is a no-op for a database that predates the is_tab column', () async {
      final executor = await _seed(11, _v11Orders);
      final db = KDSDatabase.forTesting(executor);

      await db.customSelect('SELECT 1').get();

      expect(db.schemaVersion, 13);
      expect((await db.select(db.kDSOrders).get()).length, 2);
      expect((await db.select(db.kDSItems).get()).length, 2);

      await db.close();
    });
  });
}
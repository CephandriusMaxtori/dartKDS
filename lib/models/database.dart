import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/isolate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'order_status.dart';
import 'item_status.dart';

part 'database.g.dart';

@DataClassName('KDSOrderData')
class KDSOrders extends Table {
  TextColumn get uuid => text().withLength(min: 36, max: 36)();
  TextColumn get customerName => text().withLength(min: 1, max: 255)();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get status => intEnum<OrderStatus>()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('MenuItemData')
class MenuItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get category => text().withLength(min: 1, max: 255)();
  TextColumn get defaultStation => text().withLength(min: 1, max: 50)();
  TextColumn get modifiers => text().map(const ListStringConverter())();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  TextColumn get requiredModifiers => text().map(const NullableListStringConverter()).nullable()();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
}

@DataClassName('StationData')
class Stations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
}

@DataClassName('GlobalModifierData')
class GlobalModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();
}

@DataClassName('KDSItemData')
class KDSItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(min: 36, max: 36)();
  TextColumn get orderUuid => text().references(KDSOrders, #uuid)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get modifiers => text().map(const ListStringConverter())();
  TextColumn get stationTag => text().withLength(min: 1, max: 50)();
  IntColumn get status => intEnum<ItemStatus>()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
}

class ListStringConverter extends TypeConverter<List<String>, String> {
  const ListStringConverter();
  @override
  List<String> fromSql(String fromDb) {
    return fromDb.split('|').where((s) => s.isNotEmpty).toList();
  }
  @override
  String toSql(List<String> value) => value.join('|');
}

class NullableListStringConverter extends TypeConverter<List<String>, String?> {
  const NullableListStringConverter();
  @override
  List<String> fromSql(String? fromDb) {
    if (fromDb == null) return [];
    return fromDb.split('|').where((s) => s.isNotEmpty).toList();
  }
  @override
  String? toSql(List<String> value) {
    if (value.isEmpty) return null;
    return value.join('|');
  }
}

@DriftDatabase(tables: [KDSOrders, KDSItems, MenuItems, Stations, GlobalModifiers])
class KDSDatabase extends _$KDSDatabase {
  KDSDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7; // Incremented to 7

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // Seed default station
        await into(stations).insert(StationsCompanion.insert(name: 'Main Station'));
        
        // Seed some common modifiers
        await into(globalModifiers).insert(GlobalModifiersCompanion.insert(name: 'No Bun'));
        await into(globalModifiers).insert(GlobalModifiersCompanion.insert(name: 'No Cheese'));
        await into(globalModifiers).insert(GlobalModifiersCompanion.insert(name: 'See Cashier'));
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(menuItems);
        }
        if (from < 3) {
          await m.createTable(stations);
          await batch((batch) {
            batch.insertAll(stations, [
              StationsCompanion.insert(name: 'Main Station'),
            ]);
          });
        }
        if (from < 4) {
          await m.createTable(globalModifiers);
        }
        if (from < 5) {
          await m.addColumn(menuItems, menuItems.price);
          await m.addColumn(kDSItems, kDSItems.price);
        }
        if (from < 6) {
          // Version 6 added requiredModifiers. If it already exists, ignore error.
          try {
            await m.addColumn(menuItems, menuItems.requiredModifiers);
          } catch (e) {
            // Likely already exists
          }
        }
        if (from < 7) {
          await m.addColumn(menuItems, menuItems.stockQuantity);
          await m.addColumn(menuItems, menuItems.trackStock);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'db.sqlite'));
      return NativeDatabase(file);
    } catch (e) {
      // If we can't open the DB, we're in trouble. 
      // This will at least let the StreamBuilder catch an error.
      throw Exception("Failed to open database: $e");
    }
  });
}

Future<DriftIsolate> _createDriftIsolate(String path) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    _startBackground,
    _IsolateStartRequest(receivePort.sendPort, path),
  );

  return await receivePort.first as DriftIsolate;
}

void _startBackground(_IsolateStartRequest request) {
  final executor = NativeDatabase(File(request.path));
  final driftIsolate = DriftIsolate.inCurrent(
    () => DatabaseConnection(executor),
  );
  request.sendPort.send(driftIsolate);
}

class _IsolateStartRequest {
  final SendPort sendPort;
  final String path;
  _IsolateStartRequest(this.sendPort, this.path);
}

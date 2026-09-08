import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
}

@DataClassName('StationData')
class Stations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
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
}

class ListStringConverter extends TypeConverter<List<String>, String> {
  const ListStringConverter();
  @override
  List<String> fromSql(String fromDb) => fromDb.split('|').where((s) => s.isNotEmpty).toList();
  @override
  String toSql(List<String> value) => value.join('|');
}

@DriftDatabase(tables: [KDSOrders, KDSItems, MenuItems, Stations])
class KDSDatabase extends _$KDSDatabase {
  KDSDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // Incremented to 3

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // Seed default stations
        await batch((batch) {
          batch.insertAll(stations, [
            StationsCompanion.insert(name: 'Hot Line'),
            StationsCompanion.insert(name: 'Cold Line'),
            StationsCompanion.insert(name: 'Expo'),
          ]);
        });
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(menuItems);
        }
        if (from < 3) {
          await m.createTable(stations);
          // Seed default stations
          await batch((batch) {
            batch.insertAll(stations, [
              StationsCompanion.insert(name: 'Hot Line'),
              StationsCompanion.insert(name: 'Cold Line'),
              StationsCompanion.insert(name: 'Expo'),
            ]);
          });
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

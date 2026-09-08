// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $KDSOrdersTable extends KDSOrders
    with TableInfo<$KDSOrdersTable, KDSOrderData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KDSOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<OrderStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<OrderStatus>($KDSOrdersTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [uuid, customerName, timestamp, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'k_d_s_orders';
  @override
  VerificationContext validateIntegrity(Insertable<KDSOrderData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    context.handle(_statusMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  KDSOrderData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KDSOrderData(
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      status: $KDSOrdersTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
    );
  }

  @override
  $KDSOrdersTable createAlias(String alias) {
    return $KDSOrdersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OrderStatus, int, int> $converterstatus =
      const EnumIndexConverter<OrderStatus>(OrderStatus.values);
}

class KDSOrderData extends DataClass implements Insertable<KDSOrderData> {
  final String uuid;
  final String customerName;
  final DateTime timestamp;
  final OrderStatus status;
  const KDSOrderData(
      {required this.uuid,
      required this.customerName,
      required this.timestamp,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['customer_name'] = Variable<String>(customerName);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['status'] =
          Variable<int>($KDSOrdersTable.$converterstatus.toSql(status));
    }
    return map;
  }

  KDSOrdersCompanion toCompanion(bool nullToAbsent) {
    return KDSOrdersCompanion(
      uuid: Value(uuid),
      customerName: Value(customerName),
      timestamp: Value(timestamp),
      status: Value(status),
    );
  }

  factory KDSOrderData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KDSOrderData(
      uuid: serializer.fromJson<String>(json['uuid']),
      customerName: serializer.fromJson<String>(json['customerName']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      status: $KDSOrdersTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'customerName': serializer.toJson<String>(customerName),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'status': serializer
          .toJson<int>($KDSOrdersTable.$converterstatus.toJson(status)),
    };
  }

  KDSOrderData copyWith(
          {String? uuid,
          String? customerName,
          DateTime? timestamp,
          OrderStatus? status}) =>
      KDSOrderData(
        uuid: uuid ?? this.uuid,
        customerName: customerName ?? this.customerName,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
      );
  @override
  String toString() {
    return (StringBuffer('KDSOrderData(')
          ..write('uuid: $uuid, ')
          ..write('customerName: $customerName, ')
          ..write('timestamp: $timestamp, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uuid, customerName, timestamp, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KDSOrderData &&
          other.uuid == this.uuid &&
          other.customerName == this.customerName &&
          other.timestamp == this.timestamp &&
          other.status == this.status);
}

class KDSOrdersCompanion extends UpdateCompanion<KDSOrderData> {
  final Value<String> uuid;
  final Value<String> customerName;
  final Value<DateTime> timestamp;
  final Value<OrderStatus> status;
  final Value<int> rowid;
  const KDSOrdersCompanion({
    this.uuid = const Value.absent(),
    this.customerName = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KDSOrdersCompanion.insert({
    required String uuid,
    required String customerName,
    required DateTime timestamp,
    required OrderStatus status,
    this.rowid = const Value.absent(),
  })  : uuid = Value(uuid),
        customerName = Value(customerName),
        timestamp = Value(timestamp),
        status = Value(status);
  static Insertable<KDSOrderData> custom({
    Expression<String>? uuid,
    Expression<String>? customerName,
    Expression<DateTime>? timestamp,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (customerName != null) 'customer_name': customerName,
      if (timestamp != null) 'timestamp': timestamp,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KDSOrdersCompanion copyWith(
      {Value<String>? uuid,
      Value<String>? customerName,
      Value<DateTime>? timestamp,
      Value<OrderStatus>? status,
      Value<int>? rowid}) {
    return KDSOrdersCompanion(
      uuid: uuid ?? this.uuid,
      customerName: customerName ?? this.customerName,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($KDSOrdersTable.$converterstatus.toSql(status.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KDSOrdersCompanion(')
          ..write('uuid: $uuid, ')
          ..write('customerName: $customerName, ')
          ..write('timestamp: $timestamp, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KDSItemsTable extends KDSItems
    with TableInfo<$KDSItemsTable, KDSItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KDSItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 36, maxTextLength: 36),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _orderUuidMeta =
      const VerificationMeta('orderUuid');
  @override
  late final GeneratedColumn<String> orderUuid = GeneratedColumn<String>(
      'order_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES k_d_s_orders (uuid)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _modifiersMeta =
      const VerificationMeta('modifiers');
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> modifiers =
      GeneratedColumn<String>('modifiers', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>($KDSItemsTable.$convertermodifiers);
  static const VerificationMeta _stationTagMeta =
      const VerificationMeta('stationTag');
  @override
  late final GeneratedColumn<String> stationTag = GeneratedColumn<String>(
      'station_tag', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumnWithTypeConverter<ItemStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<ItemStatus>($KDSItemsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns =>
      [id, uuid, orderUuid, name, modifiers, stationTag, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'k_d_s_items';
  @override
  VerificationContext validateIntegrity(Insertable<KDSItemData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('order_uuid')) {
      context.handle(_orderUuidMeta,
          orderUuid.isAcceptableOrUnknown(data['order_uuid']!, _orderUuidMeta));
    } else if (isInserting) {
      context.missing(_orderUuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    context.handle(_modifiersMeta, const VerificationResult.success());
    if (data.containsKey('station_tag')) {
      context.handle(
          _stationTagMeta,
          stationTag.isAcceptableOrUnknown(
              data['station_tag']!, _stationTagMeta));
    } else if (isInserting) {
      context.missing(_stationTagMeta);
    }
    context.handle(_statusMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KDSItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KDSItemData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      orderUuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_uuid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      modifiers: $KDSItemsTable.$convertermodifiers.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modifiers'])!),
      stationTag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_tag'])!,
      status: $KDSItemsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
    );
  }

  @override
  $KDSItemsTable createAlias(String alias) {
    return $KDSItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertermodifiers =
      const ListStringConverter();
  static JsonTypeConverter2<ItemStatus, int, int> $converterstatus =
      const EnumIndexConverter<ItemStatus>(ItemStatus.values);
}

class KDSItemData extends DataClass implements Insertable<KDSItemData> {
  final int id;
  final String uuid;
  final String orderUuid;
  final String name;
  final List<String> modifiers;
  final String stationTag;
  final ItemStatus status;
  const KDSItemData(
      {required this.id,
      required this.uuid,
      required this.orderUuid,
      required this.name,
      required this.modifiers,
      required this.stationTag,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['order_uuid'] = Variable<String>(orderUuid);
    map['name'] = Variable<String>(name);
    {
      map['modifiers'] =
          Variable<String>($KDSItemsTable.$convertermodifiers.toSql(modifiers));
    }
    map['station_tag'] = Variable<String>(stationTag);
    {
      map['status'] =
          Variable<int>($KDSItemsTable.$converterstatus.toSql(status));
    }
    return map;
  }

  KDSItemsCompanion toCompanion(bool nullToAbsent) {
    return KDSItemsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      orderUuid: Value(orderUuid),
      name: Value(name),
      modifiers: Value(modifiers),
      stationTag: Value(stationTag),
      status: Value(status),
    );
  }

  factory KDSItemData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KDSItemData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      orderUuid: serializer.fromJson<String>(json['orderUuid']),
      name: serializer.fromJson<String>(json['name']),
      modifiers: serializer.fromJson<List<String>>(json['modifiers']),
      stationTag: serializer.fromJson<String>(json['stationTag']),
      status: $KDSItemsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'orderUuid': serializer.toJson<String>(orderUuid),
      'name': serializer.toJson<String>(name),
      'modifiers': serializer.toJson<List<String>>(modifiers),
      'stationTag': serializer.toJson<String>(stationTag),
      'status': serializer
          .toJson<int>($KDSItemsTable.$converterstatus.toJson(status)),
    };
  }

  KDSItemData copyWith(
          {int? id,
          String? uuid,
          String? orderUuid,
          String? name,
          List<String>? modifiers,
          String? stationTag,
          ItemStatus? status}) =>
      KDSItemData(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        orderUuid: orderUuid ?? this.orderUuid,
        name: name ?? this.name,
        modifiers: modifiers ?? this.modifiers,
        stationTag: stationTag ?? this.stationTag,
        status: status ?? this.status,
      );
  @override
  String toString() {
    return (StringBuffer('KDSItemData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('orderUuid: $orderUuid, ')
          ..write('name: $name, ')
          ..write('modifiers: $modifiers, ')
          ..write('stationTag: $stationTag, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, orderUuid, name, modifiers, stationTag, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KDSItemData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.orderUuid == this.orderUuid &&
          other.name == this.name &&
          other.modifiers == this.modifiers &&
          other.stationTag == this.stationTag &&
          other.status == this.status);
}

class KDSItemsCompanion extends UpdateCompanion<KDSItemData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> orderUuid;
  final Value<String> name;
  final Value<List<String>> modifiers;
  final Value<String> stationTag;
  final Value<ItemStatus> status;
  const KDSItemsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.orderUuid = const Value.absent(),
    this.name = const Value.absent(),
    this.modifiers = const Value.absent(),
    this.stationTag = const Value.absent(),
    this.status = const Value.absent(),
  });
  KDSItemsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String orderUuid,
    required String name,
    required List<String> modifiers,
    required String stationTag,
    required ItemStatus status,
  })  : uuid = Value(uuid),
        orderUuid = Value(orderUuid),
        name = Value(name),
        modifiers = Value(modifiers),
        stationTag = Value(stationTag),
        status = Value(status);
  static Insertable<KDSItemData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? orderUuid,
    Expression<String>? name,
    Expression<String>? modifiers,
    Expression<String>? stationTag,
    Expression<int>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (orderUuid != null) 'order_uuid': orderUuid,
      if (name != null) 'name': name,
      if (modifiers != null) 'modifiers': modifiers,
      if (stationTag != null) 'station_tag': stationTag,
      if (status != null) 'status': status,
    });
  }

  KDSItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<String>? orderUuid,
      Value<String>? name,
      Value<List<String>>? modifiers,
      Value<String>? stationTag,
      Value<ItemStatus>? status}) {
    return KDSItemsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      orderUuid: orderUuid ?? this.orderUuid,
      name: name ?? this.name,
      modifiers: modifiers ?? this.modifiers,
      stationTag: stationTag ?? this.stationTag,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (orderUuid.present) {
      map['order_uuid'] = Variable<String>(orderUuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (modifiers.present) {
      map['modifiers'] = Variable<String>(
          $KDSItemsTable.$convertermodifiers.toSql(modifiers.value));
    }
    if (stationTag.present) {
      map['station_tag'] = Variable<String>(stationTag.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($KDSItemsTable.$converterstatus.toSql(status.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KDSItemsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('orderUuid: $orderUuid, ')
          ..write('name: $name, ')
          ..write('modifiers: $modifiers, ')
          ..write('stationTag: $stationTag, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $MenuItemsTable extends MenuItems
    with TableInfo<$MenuItemsTable, MenuItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _defaultStationMeta =
      const VerificationMeta('defaultStation');
  @override
  late final GeneratedColumn<String> defaultStation = GeneratedColumn<String>(
      'default_station', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _modifiersMeta =
      const VerificationMeta('modifiers');
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> modifiers =
      GeneratedColumn<String>('modifiers', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>($MenuItemsTable.$convertermodifiers);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, category, defaultStation, modifiers];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_items';
  @override
  VerificationContext validateIntegrity(Insertable<MenuItemData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('default_station')) {
      context.handle(
          _defaultStationMeta,
          defaultStation.isAcceptableOrUnknown(
              data['default_station']!, _defaultStationMeta));
    } else if (isInserting) {
      context.missing(_defaultStationMeta);
    }
    context.handle(_modifiersMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuItemData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      defaultStation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}default_station'])!,
      modifiers: $MenuItemsTable.$convertermodifiers.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modifiers'])!),
    );
  }

  @override
  $MenuItemsTable createAlias(String alias) {
    return $MenuItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertermodifiers =
      const ListStringConverter();
}

class MenuItemData extends DataClass implements Insertable<MenuItemData> {
  final int id;
  final String name;
  final String category;
  final String defaultStation;
  final List<String> modifiers;
  const MenuItemData(
      {required this.id,
      required this.name,
      required this.category,
      required this.defaultStation,
      required this.modifiers});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['default_station'] = Variable<String>(defaultStation);
    {
      map['modifiers'] = Variable<String>(
          $MenuItemsTable.$convertermodifiers.toSql(modifiers));
    }
    return map;
  }

  MenuItemsCompanion toCompanion(bool nullToAbsent) {
    return MenuItemsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      defaultStation: Value(defaultStation),
      modifiers: Value(modifiers),
    );
  }

  factory MenuItemData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuItemData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      defaultStation: serializer.fromJson<String>(json['defaultStation']),
      modifiers: serializer.fromJson<List<String>>(json['modifiers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'defaultStation': serializer.toJson<String>(defaultStation),
      'modifiers': serializer.toJson<List<String>>(modifiers),
    };
  }

  MenuItemData copyWith(
          {int? id,
          String? name,
          String? category,
          String? defaultStation,
          List<String>? modifiers}) =>
      MenuItemData(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        defaultStation: defaultStation ?? this.defaultStation,
        modifiers: modifiers ?? this.modifiers,
      );
  @override
  String toString() {
    return (StringBuffer('MenuItemData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('defaultStation: $defaultStation, ')
          ..write('modifiers: $modifiers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, category, defaultStation, modifiers);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuItemData &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.defaultStation == this.defaultStation &&
          other.modifiers == this.modifiers);
}

class MenuItemsCompanion extends UpdateCompanion<MenuItemData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> defaultStation;
  final Value<List<String>> modifiers;
  const MenuItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.defaultStation = const Value.absent(),
    this.modifiers = const Value.absent(),
  });
  MenuItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String category,
    required String defaultStation,
    required List<String> modifiers,
  })  : name = Value(name),
        category = Value(category),
        defaultStation = Value(defaultStation),
        modifiers = Value(modifiers);
  static Insertable<MenuItemData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? defaultStation,
    Expression<String>? modifiers,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (defaultStation != null) 'default_station': defaultStation,
      if (modifiers != null) 'modifiers': modifiers,
    });
  }

  MenuItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? category,
      Value<String>? defaultStation,
      Value<List<String>>? modifiers}) {
    return MenuItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      defaultStation: defaultStation ?? this.defaultStation,
      modifiers: modifiers ?? this.modifiers,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (defaultStation.present) {
      map['default_station'] = Variable<String>(defaultStation.value);
    }
    if (modifiers.present) {
      map['modifiers'] = Variable<String>(
          $MenuItemsTable.$convertermodifiers.toSql(modifiers.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('defaultStation: $defaultStation, ')
          ..write('modifiers: $modifiers')
          ..write(')'))
        .toString();
  }
}

class $StationsTable extends Stations
    with TableInfo<$StationsTable, StationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stations';
  @override
  VerificationContext validateIntegrity(Insertable<StationData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StationData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $StationsTable createAlias(String alias) {
    return $StationsTable(attachedDatabase, alias);
  }
}

class StationData extends DataClass implements Insertable<StationData> {
  final int id;
  final String name;
  const StationData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  StationsCompanion toCompanion(bool nullToAbsent) {
    return StationsCompanion(
      id: Value(id),
      name: Value(name),
    );
  }

  factory StationData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StationData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  StationData copyWith({int? id, String? name}) => StationData(
        id: id ?? this.id,
        name: name ?? this.name,
      );
  @override
  String toString() {
    return (StringBuffer('StationData(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StationData && other.id == this.id && other.name == this.name);
}

class StationsCompanion extends UpdateCompanion<StationData> {
  final Value<int> id;
  final Value<String> name;
  const StationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  StationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<StationData> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  StationsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return StationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

abstract class _$KDSDatabase extends GeneratedDatabase {
  _$KDSDatabase(QueryExecutor e) : super(e);
  _$KDSDatabaseManager get managers => _$KDSDatabaseManager(this);
  late final $KDSOrdersTable kDSOrders = $KDSOrdersTable(this);
  late final $KDSItemsTable kDSItems = $KDSItemsTable(this);
  late final $MenuItemsTable menuItems = $MenuItemsTable(this);
  late final $StationsTable stations = $StationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [kDSOrders, kDSItems, menuItems, stations];
}

typedef $$KDSOrdersTableInsertCompanionBuilder = KDSOrdersCompanion Function({
  required String uuid,
  required String customerName,
  required DateTime timestamp,
  required OrderStatus status,
  Value<int> rowid,
});
typedef $$KDSOrdersTableUpdateCompanionBuilder = KDSOrdersCompanion Function({
  Value<String> uuid,
  Value<String> customerName,
  Value<DateTime> timestamp,
  Value<OrderStatus> status,
  Value<int> rowid,
});

class $$KDSOrdersTableTableManager extends RootTableManager<
    _$KDSDatabase,
    $KDSOrdersTable,
    KDSOrderData,
    $$KDSOrdersTableFilterComposer,
    $$KDSOrdersTableOrderingComposer,
    $$KDSOrdersTableProcessedTableManager,
    $$KDSOrdersTableInsertCompanionBuilder,
    $$KDSOrdersTableUpdateCompanionBuilder> {
  $$KDSOrdersTableTableManager(_$KDSDatabase db, $KDSOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$KDSOrdersTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$KDSOrdersTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$KDSOrdersTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<String> uuid = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<OrderStatus> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KDSOrdersCompanion(
            uuid: uuid,
            customerName: customerName,
            timestamp: timestamp,
            status: status,
            rowid: rowid,
          ),
          getInsertCompanionBuilder: ({
            required String uuid,
            required String customerName,
            required DateTime timestamp,
            required OrderStatus status,
            Value<int> rowid = const Value.absent(),
          }) =>
              KDSOrdersCompanion.insert(
            uuid: uuid,
            customerName: customerName,
            timestamp: timestamp,
            status: status,
            rowid: rowid,
          ),
        ));
}

class $$KDSOrdersTableProcessedTableManager extends ProcessedTableManager<
    _$KDSDatabase,
    $KDSOrdersTable,
    KDSOrderData,
    $$KDSOrdersTableFilterComposer,
    $$KDSOrdersTableOrderingComposer,
    $$KDSOrdersTableProcessedTableManager,
    $$KDSOrdersTableInsertCompanionBuilder,
    $$KDSOrdersTableUpdateCompanionBuilder> {
  $$KDSOrdersTableProcessedTableManager(super.$state);
}

class $$KDSOrdersTableFilterComposer
    extends FilterComposer<_$KDSDatabase, $KDSOrdersTable> {
  $$KDSOrdersTableFilterComposer(super.$state);
  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get customerName => $state.composableBuilder(
      column: $state.table.customerName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<OrderStatus, OrderStatus, int> get status =>
      $state.composableBuilder(
          column: $state.table.status,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ComposableFilter kDSItemsRefs(
      ComposableFilter Function($$KDSItemsTableFilterComposer f) f) {
    final $$KDSItemsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $state.db.kDSItems,
        getReferencedColumn: (t) => t.orderUuid,
        builder: (joinBuilder, parentComposers) =>
            $$KDSItemsTableFilterComposer(ComposerState(
                $state.db, $state.db.kDSItems, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$KDSOrdersTableOrderingComposer
    extends OrderingComposer<_$KDSDatabase, $KDSOrdersTable> {
  $$KDSOrdersTableOrderingComposer(super.$state);
  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get customerName => $state.composableBuilder(
      column: $state.table.customerName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$KDSItemsTableInsertCompanionBuilder = KDSItemsCompanion Function({
  Value<int> id,
  required String uuid,
  required String orderUuid,
  required String name,
  required List<String> modifiers,
  required String stationTag,
  required ItemStatus status,
});
typedef $$KDSItemsTableUpdateCompanionBuilder = KDSItemsCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> orderUuid,
  Value<String> name,
  Value<List<String>> modifiers,
  Value<String> stationTag,
  Value<ItemStatus> status,
});

class $$KDSItemsTableTableManager extends RootTableManager<
    _$KDSDatabase,
    $KDSItemsTable,
    KDSItemData,
    $$KDSItemsTableFilterComposer,
    $$KDSItemsTableOrderingComposer,
    $$KDSItemsTableProcessedTableManager,
    $$KDSItemsTableInsertCompanionBuilder,
    $$KDSItemsTableUpdateCompanionBuilder> {
  $$KDSItemsTableTableManager(_$KDSDatabase db, $KDSItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$KDSItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$KDSItemsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$KDSItemsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String> orderUuid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<List<String>> modifiers = const Value.absent(),
            Value<String> stationTag = const Value.absent(),
            Value<ItemStatus> status = const Value.absent(),
          }) =>
              KDSItemsCompanion(
            id: id,
            uuid: uuid,
            orderUuid: orderUuid,
            name: name,
            modifiers: modifiers,
            stationTag: stationTag,
            status: status,
          ),
          getInsertCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            required String uuid,
            required String orderUuid,
            required String name,
            required List<String> modifiers,
            required String stationTag,
            required ItemStatus status,
          }) =>
              KDSItemsCompanion.insert(
            id: id,
            uuid: uuid,
            orderUuid: orderUuid,
            name: name,
            modifiers: modifiers,
            stationTag: stationTag,
            status: status,
          ),
        ));
}

class $$KDSItemsTableProcessedTableManager extends ProcessedTableManager<
    _$KDSDatabase,
    $KDSItemsTable,
    KDSItemData,
    $$KDSItemsTableFilterComposer,
    $$KDSItemsTableOrderingComposer,
    $$KDSItemsTableProcessedTableManager,
    $$KDSItemsTableInsertCompanionBuilder,
    $$KDSItemsTableUpdateCompanionBuilder> {
  $$KDSItemsTableProcessedTableManager(super.$state);
}

class $$KDSItemsTableFilterComposer
    extends FilterComposer<_$KDSDatabase, $KDSItemsTable> {
  $$KDSItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get modifiers => $state.composableBuilder(
          column: $state.table.modifiers,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<String> get stationTag => $state.composableBuilder(
      column: $state.table.stationTag,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<ItemStatus, ItemStatus, int> get status =>
      $state.composableBuilder(
          column: $state.table.status,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  $$KDSOrdersTableFilterComposer get orderUuid {
    final $$KDSOrdersTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderUuid,
        referencedTable: $state.db.kDSOrders,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder, parentComposers) =>
            $$KDSOrdersTableFilterComposer(ComposerState(
                $state.db, $state.db.kDSOrders, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$KDSItemsTableOrderingComposer
    extends OrderingComposer<_$KDSDatabase, $KDSItemsTable> {
  $$KDSItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uuid => $state.composableBuilder(
      column: $state.table.uuid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get modifiers => $state.composableBuilder(
      column: $state.table.modifiers,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get stationTag => $state.composableBuilder(
      column: $state.table.stationTag,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$KDSOrdersTableOrderingComposer get orderUuid {
    final $$KDSOrdersTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderUuid,
        referencedTable: $state.db.kDSOrders,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder, parentComposers) =>
            $$KDSOrdersTableOrderingComposer(ComposerState(
                $state.db, $state.db.kDSOrders, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$MenuItemsTableInsertCompanionBuilder = MenuItemsCompanion Function({
  Value<int> id,
  required String name,
  required String category,
  required String defaultStation,
  required List<String> modifiers,
});
typedef $$MenuItemsTableUpdateCompanionBuilder = MenuItemsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> category,
  Value<String> defaultStation,
  Value<List<String>> modifiers,
});

class $$MenuItemsTableTableManager extends RootTableManager<
    _$KDSDatabase,
    $MenuItemsTable,
    MenuItemData,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableProcessedTableManager,
    $$MenuItemsTableInsertCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder> {
  $$MenuItemsTableTableManager(_$KDSDatabase db, $MenuItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MenuItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$MenuItemsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$MenuItemsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> defaultStation = const Value.absent(),
            Value<List<String>> modifiers = const Value.absent(),
          }) =>
              MenuItemsCompanion(
            id: id,
            name: name,
            category: category,
            defaultStation: defaultStation,
            modifiers: modifiers,
          ),
          getInsertCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String category,
            required String defaultStation,
            required List<String> modifiers,
          }) =>
              MenuItemsCompanion.insert(
            id: id,
            name: name,
            category: category,
            defaultStation: defaultStation,
            modifiers: modifiers,
          ),
        ));
}

class $$MenuItemsTableProcessedTableManager extends ProcessedTableManager<
    _$KDSDatabase,
    $MenuItemsTable,
    MenuItemData,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableProcessedTableManager,
    $$MenuItemsTableInsertCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder> {
  $$MenuItemsTableProcessedTableManager(super.$state);
}

class $$MenuItemsTableFilterComposer
    extends FilterComposer<_$KDSDatabase, $MenuItemsTable> {
  $$MenuItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get defaultStation => $state.composableBuilder(
      column: $state.table.defaultStation,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get modifiers => $state.composableBuilder(
          column: $state.table.modifiers,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$MenuItemsTableOrderingComposer
    extends OrderingComposer<_$KDSDatabase, $MenuItemsTable> {
  $$MenuItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get defaultStation => $state.composableBuilder(
      column: $state.table.defaultStation,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get modifiers => $state.composableBuilder(
      column: $state.table.modifiers,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$StationsTableInsertCompanionBuilder = StationsCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$StationsTableUpdateCompanionBuilder = StationsCompanion Function({
  Value<int> id,
  Value<String> name,
});

class $$StationsTableTableManager extends RootTableManager<
    _$KDSDatabase,
    $StationsTable,
    StationData,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableProcessedTableManager,
    $$StationsTableInsertCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder> {
  $$StationsTableTableManager(_$KDSDatabase db, $StationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$StationsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$StationsTableOrderingComposer(ComposerState(db, table)),
          getChildManagerBuilder: (p) =>
              $$StationsTableProcessedTableManager(p),
          getUpdateCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) =>
              StationsCompanion(
            id: id,
            name: name,
          ),
          getInsertCompanionBuilder: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) =>
              StationsCompanion.insert(
            id: id,
            name: name,
          ),
        ));
}

class $$StationsTableProcessedTableManager extends ProcessedTableManager<
    _$KDSDatabase,
    $StationsTable,
    StationData,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableProcessedTableManager,
    $$StationsTableInsertCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder> {
  $$StationsTableProcessedTableManager(super.$state);
}

class $$StationsTableFilterComposer
    extends FilterComposer<_$KDSDatabase, $StationsTable> {
  $$StationsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$StationsTableOrderingComposer
    extends OrderingComposer<_$KDSDatabase, $StationsTable> {
  $$StationsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class _$KDSDatabaseManager {
  final _$KDSDatabase _db;
  _$KDSDatabaseManager(this._db);
  $$KDSOrdersTableTableManager get kDSOrders =>
      $$KDSOrdersTableTableManager(_db, _db.kDSOrders);
  $$KDSItemsTableTableManager get kDSItems =>
      $$KDSItemsTableTableManager(_db, _db.kDSItems);
  $$MenuItemsTableTableManager get menuItems =>
      $$MenuItemsTableTableManager(_db, _db.menuItems);
  $$StationsTableTableManager get stations =>
      $$StationsTableTableManager(_db, _db.stations);
}

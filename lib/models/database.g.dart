// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $KDSOrdersTable extends KDSOrders with TableInfo<$KDSOrdersTable, KDSOrderData>{
@override final GeneratedDatabase attachedDatabase;
final String? _alias;
$KDSOrdersTable(this.attachedDatabase, [this._alias]);
static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
@override
late final GeneratedColumn<String> uuid = GeneratedColumn<String>('uuid', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 36,maxTextLength: 36), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _customerNameMeta = const VerificationMeta('customerName');
@override
late final GeneratedColumn<String> customerName = GeneratedColumn<String>('customer_name', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 255), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _timestampMeta = const VerificationMeta('timestamp');
@override
late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>('timestamp', aliasedName, false, type: DriftSqlType.dateTime, requiredDuringInsert: true);
static const VerificationMeta _statusMeta = const VerificationMeta('status');
@override
late final GeneratedColumnWithTypeConverter<OrderStatus, int> status = GeneratedColumn<int>('status', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true).withConverter<OrderStatus>($KDSOrdersTable.$converterstatus);
@override
List<GeneratedColumn> get $columns => [uuid, customerName, timestamp, status];
@override
String get aliasedName => _alias ?? actualTableName;
@override
 String get actualTableName => $name;
static const String $name = 'k_d_s_orders';
@override
VerificationContext validateIntegrity(Insertable<KDSOrderData> instance, {bool isInserting = false}) {
final context = VerificationContext();
final data = instance.toColumns(true);
if (data.containsKey('uuid')) {
context.handle(_uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));} else if (isInserting) {
context.missing(_uuidMeta);
}
if (data.containsKey('customer_name')) {
context.handle(_customerNameMeta, customerName.isAcceptableOrUnknown(data['customer_name']!, _customerNameMeta));} else if (isInserting) {
context.missing(_customerNameMeta);
}
if (data.containsKey('timestamp')) {
context.handle(_timestampMeta, timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));} else if (isInserting) {
context.missing(_timestampMeta);
}
context.handle(_statusMeta, const VerificationResult.success());return context;
}
@override
Set<GeneratedColumn> get $primaryKey => {uuid};
@override KDSOrderData map(Map<String, dynamic> data, {String? tablePrefix})  {
final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';return KDSOrderData(uuid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uuid'])!, customerName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!, timestamp: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!, status: $KDSOrdersTable.$converterstatus.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}status'])!), );
}
@override
$KDSOrdersTable createAlias(String alias) {
return $KDSOrdersTable(attachedDatabase, alias);}static JsonTypeConverter2<OrderStatus,int,int> $converterstatus = const EnumIndexConverter<OrderStatus>(OrderStatus.values);}class KDSOrderData extends DataClass implements Insertable<KDSOrderData> 
{
final String uuid;
final String customerName;
final DateTime timestamp;
final OrderStatus status;
const KDSOrderData({required this.uuid, required this.customerName, required this.timestamp, required this.status});@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};map['uuid'] = Variable<String>(uuid);
map['customer_name'] = Variable<String>(customerName);
map['timestamp'] = Variable<DateTime>(timestamp);
{map['status'] = Variable<int>($KDSOrdersTable.$converterstatus.toSql(status));
}return map; 
}
KDSOrdersCompanion toCompanion(bool nullToAbsent) {
return KDSOrdersCompanion(uuid: Value(uuid),customerName: Value(customerName),timestamp: Value(timestamp),status: Value(status),);
}
factory KDSOrderData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return KDSOrderData(uuid: serializer.fromJson<String>(json['uuid']),customerName: serializer.fromJson<String>(json['customerName']),timestamp: serializer.fromJson<DateTime>(json['timestamp']),status: $KDSOrdersTable.$converterstatus.fromJson(serializer.fromJson<int>(json['status'])),);}
@override Map<String, dynamic> toJson({ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return <String, dynamic>{
'uuid': serializer.toJson<String>(uuid),'customerName': serializer.toJson<String>(customerName),'timestamp': serializer.toJson<DateTime>(timestamp),'status': serializer.toJson<int>($KDSOrdersTable.$converterstatus.toJson(status)),};}KDSOrderData copyWith({String? uuid,String? customerName,DateTime? timestamp,OrderStatus? status}) => KDSOrderData(uuid: uuid ?? this.uuid,customerName: customerName ?? this.customerName,timestamp: timestamp ?? this.timestamp,status: status ?? this.status,);KDSOrderData copyWithCompanion(KDSOrdersCompanion data) {
return KDSOrderData(
uuid: data.uuid.present ? data.uuid.value : this.uuid,customerName: data.customerName.present ? data.customerName.value : this.customerName,timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,status: data.status.present ? data.status.value : this.status,);
}
@override
String toString() {return (StringBuffer('KDSOrderData(')..write('uuid: $uuid, ')..write('customerName: $customerName, ')..write('timestamp: $timestamp, ')..write('status: $status')..write(')')).toString();}
@override
 int get hashCode => Object.hash(uuid, customerName, timestamp, status);@override
bool operator ==(Object other) => identical(this, other) || (other is KDSOrderData && other.uuid == this.uuid && other.customerName == this.customerName && other.timestamp == this.timestamp && other.status == this.status);
}class KDSOrdersCompanion extends UpdateCompanion<KDSOrderData> {
final Value<String> uuid;
final Value<String> customerName;
final Value<DateTime> timestamp;
final Value<OrderStatus> status;
final Value<int> rowid;
const KDSOrdersCompanion({this.uuid = const Value.absent(),this.customerName = const Value.absent(),this.timestamp = const Value.absent(),this.status = const Value.absent(),this.rowid = const Value.absent(),});
KDSOrdersCompanion.insert({required String uuid,required String customerName,required DateTime timestamp,required OrderStatus status,this.rowid = const Value.absent(),}): uuid = Value(uuid), customerName = Value(customerName), timestamp = Value(timestamp), status = Value(status);
static Insertable<KDSOrderData> custom({Expression<String>? uuid, 
Expression<String>? customerName, 
Expression<DateTime>? timestamp, 
Expression<int>? status, 
Expression<int>? rowid, 
}) {
return RawValuesInsertable({if (uuid != null)'uuid': uuid,if (customerName != null)'customer_name': customerName,if (timestamp != null)'timestamp': timestamp,if (status != null)'status': status,if (rowid != null)'rowid': rowid,});
}KDSOrdersCompanion copyWith({Value<String>? uuid, Value<String>? customerName, Value<DateTime>? timestamp, Value<OrderStatus>? status, Value<int>? rowid}) {
return KDSOrdersCompanion(uuid: uuid ?? this.uuid,customerName: customerName ?? this.customerName,timestamp: timestamp ?? this.timestamp,status: status ?? this.status,rowid: rowid ?? this.rowid,);
}
@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};if (uuid.present) {
map['uuid'] = Variable<String>(uuid.value);}
if (customerName.present) {
map['customer_name'] = Variable<String>(customerName.value);}
if (timestamp.present) {
map['timestamp'] = Variable<DateTime>(timestamp.value);}
if (status.present) {
map['status'] = Variable<int>($KDSOrdersTable.$converterstatus.toSql(status.value));}
if (rowid.present) {
map['rowid'] = Variable<int>(rowid.value);}
return map; 
}
@override
String toString() {return (StringBuffer('KDSOrdersCompanion(')..write('uuid: $uuid, ')..write('customerName: $customerName, ')..write('timestamp: $timestamp, ')..write('status: $status, ')..write('rowid: $rowid')..write(')')).toString();}
}
class $KDSItemsTable extends KDSItems with TableInfo<$KDSItemsTable, KDSItemData>{
@override final GeneratedDatabase attachedDatabase;
final String? _alias;
$KDSItemsTable(this.attachedDatabase, [this._alias]);
static const VerificationMeta _idMeta = const VerificationMeta('id');
@override
late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false, hasAutoIncrement: true, type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
@override
late final GeneratedColumn<String> uuid = GeneratedColumn<String>('uuid', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 36,maxTextLength: 36), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _orderUuidMeta = const VerificationMeta('orderUuid');
@override
late final GeneratedColumn<String> orderUuid = GeneratedColumn<String>('order_uuid', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true, defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES k_d_s_orders (uuid)'));
static const VerificationMeta _nameMeta = const VerificationMeta('name');
@override
late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 255), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _modifiersMeta = const VerificationMeta('modifiers');
@override
late final GeneratedColumnWithTypeConverter<List<String>, String> modifiers = GeneratedColumn<String>('modifiers', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true).withConverter<List<String>>($KDSItemsTable.$convertermodifiers);
static const VerificationMeta _stationTagMeta = const VerificationMeta('stationTag');
@override
late final GeneratedColumn<String> stationTag = GeneratedColumn<String>('station_tag', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 50), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _statusMeta = const VerificationMeta('status');
@override
late final GeneratedColumnWithTypeConverter<ItemStatus, int> status = GeneratedColumn<int>('status', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true).withConverter<ItemStatus>($KDSItemsTable.$converterstatus);
static const VerificationMeta _priceMeta = const VerificationMeta('price');
@override
late final GeneratedColumn<double> price = GeneratedColumn<double>('price', aliasedName, false, type: DriftSqlType.double, requiredDuringInsert: false, defaultValue: const Constant(0.0));
@override
List<GeneratedColumn> get $columns => [id, uuid, orderUuid, name, modifiers, stationTag, status, price];
@override
String get aliasedName => _alias ?? actualTableName;
@override
 String get actualTableName => $name;
static const String $name = 'k_d_s_items';
@override
VerificationContext validateIntegrity(Insertable<KDSItemData> instance, {bool isInserting = false}) {
final context = VerificationContext();
final data = instance.toColumns(true);
if (data.containsKey('id')) {
context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));}if (data.containsKey('uuid')) {
context.handle(_uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));} else if (isInserting) {
context.missing(_uuidMeta);
}
if (data.containsKey('order_uuid')) {
context.handle(_orderUuidMeta, orderUuid.isAcceptableOrUnknown(data['order_uuid']!, _orderUuidMeta));} else if (isInserting) {
context.missing(_orderUuidMeta);
}
if (data.containsKey('name')) {
context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));} else if (isInserting) {
context.missing(_nameMeta);
}
context.handle(_modifiersMeta, const VerificationResult.success());if (data.containsKey('station_tag')) {
context.handle(_stationTagMeta, stationTag.isAcceptableOrUnknown(data['station_tag']!, _stationTagMeta));} else if (isInserting) {
context.missing(_stationTagMeta);
}
context.handle(_statusMeta, const VerificationResult.success());if (data.containsKey('price')) {
context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));}return context;
}
@override
Set<GeneratedColumn> get $primaryKey => {id};
@override KDSItemData map(Map<String, dynamic> data, {String? tablePrefix})  {
final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';return KDSItemData(id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!, uuid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uuid'])!, orderUuid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}order_uuid'])!, name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!, modifiers: $KDSItemsTable.$convertermodifiers.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}modifiers'])!), stationTag: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}station_tag'])!, status: $KDSItemsTable.$converterstatus.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}status'])!), price: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}price'])!, );
}
@override
$KDSItemsTable createAlias(String alias) {
return $KDSItemsTable(attachedDatabase, alias);}static TypeConverter<List<String>,String> $convertermodifiers = const ListStringConverter();static JsonTypeConverter2<ItemStatus,int,int> $converterstatus = const EnumIndexConverter<ItemStatus>(ItemStatus.values);}class KDSItemData extends DataClass implements Insertable<KDSItemData> 
{
final int id;
final String uuid;
final String orderUuid;
final String name;
final List<String> modifiers;
final String stationTag;
final ItemStatus status;
final double price;
const KDSItemData({required this.id, required this.uuid, required this.orderUuid, required this.name, required this.modifiers, required this.stationTag, required this.status, required this.price});@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};map['id'] = Variable<int>(id);
map['uuid'] = Variable<String>(uuid);
map['order_uuid'] = Variable<String>(orderUuid);
map['name'] = Variable<String>(name);
{map['modifiers'] = Variable<String>($KDSItemsTable.$convertermodifiers.toSql(modifiers));
}map['station_tag'] = Variable<String>(stationTag);
{map['status'] = Variable<int>($KDSItemsTable.$converterstatus.toSql(status));
}map['price'] = Variable<double>(price);
return map; 
}
KDSItemsCompanion toCompanion(bool nullToAbsent) {
return KDSItemsCompanion(id: Value(id),uuid: Value(uuid),orderUuid: Value(orderUuid),name: Value(name),modifiers: Value(modifiers),stationTag: Value(stationTag),status: Value(status),price: Value(price),);
}
factory KDSItemData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return KDSItemData(id: serializer.fromJson<int>(json['id']),uuid: serializer.fromJson<String>(json['uuid']),orderUuid: serializer.fromJson<String>(json['orderUuid']),name: serializer.fromJson<String>(json['name']),modifiers: serializer.fromJson<List<String>>(json['modifiers']),stationTag: serializer.fromJson<String>(json['stationTag']),status: $KDSItemsTable.$converterstatus.fromJson(serializer.fromJson<int>(json['status'])),price: serializer.fromJson<double>(json['price']),);}
@override Map<String, dynamic> toJson({ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return <String, dynamic>{
'id': serializer.toJson<int>(id),'uuid': serializer.toJson<String>(uuid),'orderUuid': serializer.toJson<String>(orderUuid),'name': serializer.toJson<String>(name),'modifiers': serializer.toJson<List<String>>(modifiers),'stationTag': serializer.toJson<String>(stationTag),'status': serializer.toJson<int>($KDSItemsTable.$converterstatus.toJson(status)),'price': serializer.toJson<double>(price),};}KDSItemData copyWith({int? id,String? uuid,String? orderUuid,String? name,List<String>? modifiers,String? stationTag,ItemStatus? status,double? price}) => KDSItemData(id: id ?? this.id,uuid: uuid ?? this.uuid,orderUuid: orderUuid ?? this.orderUuid,name: name ?? this.name,modifiers: modifiers ?? this.modifiers,stationTag: stationTag ?? this.stationTag,status: status ?? this.status,price: price ?? this.price,);KDSItemData copyWithCompanion(KDSItemsCompanion data) {
return KDSItemData(
id: data.id.present ? data.id.value : this.id,uuid: data.uuid.present ? data.uuid.value : this.uuid,orderUuid: data.orderUuid.present ? data.orderUuid.value : this.orderUuid,name: data.name.present ? data.name.value : this.name,modifiers: data.modifiers.present ? data.modifiers.value : this.modifiers,stationTag: data.stationTag.present ? data.stationTag.value : this.stationTag,status: data.status.present ? data.status.value : this.status,price: data.price.present ? data.price.value : this.price,);
}
@override
String toString() {return (StringBuffer('KDSItemData(')..write('id: $id, ')..write('uuid: $uuid, ')..write('orderUuid: $orderUuid, ')..write('name: $name, ')..write('modifiers: $modifiers, ')..write('stationTag: $stationTag, ')..write('status: $status, ')..write('price: $price')..write(')')).toString();}
@override
 int get hashCode => Object.hash(id, uuid, orderUuid, name, modifiers, stationTag, status, price);@override
bool operator ==(Object other) => identical(this, other) || (other is KDSItemData && other.id == this.id && other.uuid == this.uuid && other.orderUuid == this.orderUuid && other.name == this.name && other.modifiers == this.modifiers && other.stationTag == this.stationTag && other.status == this.status && other.price == this.price);
}class KDSItemsCompanion extends UpdateCompanion<KDSItemData> {
final Value<int> id;
final Value<String> uuid;
final Value<String> orderUuid;
final Value<String> name;
final Value<List<String>> modifiers;
final Value<String> stationTag;
final Value<ItemStatus> status;
final Value<double> price;
const KDSItemsCompanion({this.id = const Value.absent(),this.uuid = const Value.absent(),this.orderUuid = const Value.absent(),this.name = const Value.absent(),this.modifiers = const Value.absent(),this.stationTag = const Value.absent(),this.status = const Value.absent(),this.price = const Value.absent(),});
KDSItemsCompanion.insert({this.id = const Value.absent(),required String uuid,required String orderUuid,required String name,required List<String> modifiers,required String stationTag,required ItemStatus status,this.price = const Value.absent(),}): uuid = Value(uuid), orderUuid = Value(orderUuid), name = Value(name), modifiers = Value(modifiers), stationTag = Value(stationTag), status = Value(status);
static Insertable<KDSItemData> custom({Expression<int>? id, 
Expression<String>? uuid, 
Expression<String>? orderUuid, 
Expression<String>? name, 
Expression<String>? modifiers, 
Expression<String>? stationTag, 
Expression<int>? status, 
Expression<double>? price, 
}) {
return RawValuesInsertable({if (id != null)'id': id,if (uuid != null)'uuid': uuid,if (orderUuid != null)'order_uuid': orderUuid,if (name != null)'name': name,if (modifiers != null)'modifiers': modifiers,if (stationTag != null)'station_tag': stationTag,if (status != null)'status': status,if (price != null)'price': price,});
}KDSItemsCompanion copyWith({Value<int>? id, Value<String>? uuid, Value<String>? orderUuid, Value<String>? name, Value<List<String>>? modifiers, Value<String>? stationTag, Value<ItemStatus>? status, Value<double>? price}) {
return KDSItemsCompanion(id: id ?? this.id,uuid: uuid ?? this.uuid,orderUuid: orderUuid ?? this.orderUuid,name: name ?? this.name,modifiers: modifiers ?? this.modifiers,stationTag: stationTag ?? this.stationTag,status: status ?? this.status,price: price ?? this.price,);
}
@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};if (id.present) {
map['id'] = Variable<int>(id.value);}
if (uuid.present) {
map['uuid'] = Variable<String>(uuid.value);}
if (orderUuid.present) {
map['order_uuid'] = Variable<String>(orderUuid.value);}
if (name.present) {
map['name'] = Variable<String>(name.value);}
if (modifiers.present) {
map['modifiers'] = Variable<String>($KDSItemsTable.$convertermodifiers.toSql(modifiers.value));}
if (stationTag.present) {
map['station_tag'] = Variable<String>(stationTag.value);}
if (status.present) {
map['status'] = Variable<int>($KDSItemsTable.$converterstatus.toSql(status.value));}
if (price.present) {
map['price'] = Variable<double>(price.value);}
return map; 
}
@override
String toString() {return (StringBuffer('KDSItemsCompanion(')..write('id: $id, ')..write('uuid: $uuid, ')..write('orderUuid: $orderUuid, ')..write('name: $name, ')..write('modifiers: $modifiers, ')..write('stationTag: $stationTag, ')..write('status: $status, ')..write('price: $price')..write(')')).toString();}
}
class $MenuItemsTable extends MenuItems with TableInfo<$MenuItemsTable, MenuItemData>{
@override final GeneratedDatabase attachedDatabase;
final String? _alias;
$MenuItemsTable(this.attachedDatabase, [this._alias]);
static const VerificationMeta _idMeta = const VerificationMeta('id');
@override
late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false, hasAutoIncrement: true, type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
static const VerificationMeta _nameMeta = const VerificationMeta('name');
@override
late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 255), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _categoryMeta = const VerificationMeta('category');
@override
late final GeneratedColumn<String> category = GeneratedColumn<String>('category', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 255), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _defaultStationMeta = const VerificationMeta('defaultStation');
@override
late final GeneratedColumn<String> defaultStation = GeneratedColumn<String>('default_station', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 50), type: DriftSqlType.string, requiredDuringInsert: true);
static const VerificationMeta _modifiersMeta = const VerificationMeta('modifiers');
@override
late final GeneratedColumnWithTypeConverter<List<String>, String> modifiers = GeneratedColumn<String>('modifiers', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true).withConverter<List<String>>($MenuItemsTable.$convertermodifiers);
static const VerificationMeta _priceMeta = const VerificationMeta('price');
@override
late final GeneratedColumn<double> price = GeneratedColumn<double>('price', aliasedName, false, type: DriftSqlType.double, requiredDuringInsert: false, defaultValue: const Constant(0.0));
static const VerificationMeta _requiredModifiersMeta = const VerificationMeta('requiredModifiers');
@override
late final GeneratedColumnWithTypeConverter<List<String>, String> requiredModifiers = GeneratedColumn<String>('required_modifiers', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false).withConverter<List<String>>($MenuItemsTable.$converterrequiredModifiers);
static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
@override
late final GeneratedColumnWithTypeConverter<List<String>, String> tags = GeneratedColumn<String>('tags', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false).withConverter<List<String>>($MenuItemsTable.$convertertags);
static const VerificationMeta _stockQuantityMeta = const VerificationMeta('stockQuantity');
@override
late final GeneratedColumn<int> stockQuantity = GeneratedColumn<int>('stock_quantity', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));
static const VerificationMeta _trackStockMeta = const VerificationMeta('trackStock');
@override
late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>('track_stock', aliasedName, false, type: DriftSqlType.bool, requiredDuringInsert: false, defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("track_stock" IN (0, 1))'), defaultValue: const Constant(false));
@override
List<GeneratedColumn> get $columns => [id, name, category, defaultStation, modifiers, price, requiredModifiers, tags, stockQuantity, trackStock];
@override
String get aliasedName => _alias ?? actualTableName;
@override
 String get actualTableName => $name;
static const String $name = 'menu_items';
@override
VerificationContext validateIntegrity(Insertable<MenuItemData> instance, {bool isInserting = false}) {
final context = VerificationContext();
final data = instance.toColumns(true);
if (data.containsKey('id')) {
context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));}if (data.containsKey('name')) {
context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));} else if (isInserting) {
context.missing(_nameMeta);
}
if (data.containsKey('category')) {
context.handle(_categoryMeta, category.isAcceptableOrUnknown(data['category']!, _categoryMeta));} else if (isInserting) {
context.missing(_categoryMeta);
}
if (data.containsKey('default_station')) {
context.handle(_defaultStationMeta, defaultStation.isAcceptableOrUnknown(data['default_station']!, _defaultStationMeta));} else if (isInserting) {
context.missing(_defaultStationMeta);
}
context.handle(_modifiersMeta, const VerificationResult.success());if (data.containsKey('price')) {
context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));}context.handle(_requiredModifiersMeta, const VerificationResult.success());context.handle(_tagsMeta, const VerificationResult.success());if (data.containsKey('stock_quantity')) {
context.handle(_stockQuantityMeta, stockQuantity.isAcceptableOrUnknown(data['stock_quantity']!, _stockQuantityMeta));}if (data.containsKey('track_stock')) {
context.handle(_trackStockMeta, trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta));}return context;
}
@override
Set<GeneratedColumn> get $primaryKey => {id};
@override MenuItemData map(Map<String, dynamic> data, {String? tablePrefix})  {
final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';return MenuItemData(id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!, name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!, category: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category'])!, defaultStation: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}default_station'])!, modifiers: $MenuItemsTable.$convertermodifiers.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}modifiers'])!), price: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}price'])!, requiredModifiers: $MenuItemsTable.$converterrequiredModifiers.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}required_modifiers'])), tags: $MenuItemsTable.$convertertags.fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tags'])), stockQuantity: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}stock_quantity'])!, trackStock: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}track_stock'])!, );
}
@override
$MenuItemsTable createAlias(String alias) {
return $MenuItemsTable(attachedDatabase, alias);}static TypeConverter<List<String>,String> $convertermodifiers = const ListStringConverter();static TypeConverter<List<String>,String?> $converterrequiredModifiers = const NullableListStringConverter();static TypeConverter<List<String>,String?> $convertertags = const NullableListStringConverter();}class MenuItemData extends DataClass implements Insertable<MenuItemData> 
{
final int id;
final String name;
final String category;
final String defaultStation;
final List<String> modifiers;
final double price;
final List<String> requiredModifiers;
final List<String> tags;
final int stockQuantity;
final bool trackStock;
const MenuItemData({required this.id, required this.name, required this.category, required this.defaultStation, required this.modifiers, required this.price, required this.requiredModifiers, required this.tags, required this.stockQuantity, required this.trackStock});@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};map['id'] = Variable<int>(id);
map['name'] = Variable<String>(name);
map['category'] = Variable<String>(category);
map['default_station'] = Variable<String>(defaultStation);
{map['modifiers'] = Variable<String>($MenuItemsTable.$convertermodifiers.toSql(modifiers));
}map['price'] = Variable<double>(price);
{map['required_modifiers'] = Variable<String>($MenuItemsTable.$converterrequiredModifiers.toSql(requiredModifiers));
}{map['tags'] = Variable<String>($MenuItemsTable.$convertertags.toSql(tags));
}map['stock_quantity'] = Variable<int>(stockQuantity);
map['track_stock'] = Variable<bool>(trackStock);
return map; 
}
MenuItemsCompanion toCompanion(bool nullToAbsent) {
return MenuItemsCompanion(id: Value(id),name: Value(name),category: Value(category),defaultStation: Value(defaultStation),modifiers: Value(modifiers),price: Value(price),requiredModifiers: Value(requiredModifiers),tags: Value(tags),stockQuantity: Value(stockQuantity),trackStock: Value(trackStock),);
}
factory MenuItemData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return MenuItemData(id: serializer.fromJson<int>(json['id']),name: serializer.fromJson<String>(json['name']),category: serializer.fromJson<String>(json['category']),defaultStation: serializer.fromJson<String>(json['defaultStation']),modifiers: serializer.fromJson<List<String>>(json['modifiers']),price: serializer.fromJson<double>(json['price']),requiredModifiers: serializer.fromJson<List<String>>(json['requiredModifiers']),tags: serializer.fromJson<List<String>>(json['tags']),stockQuantity: serializer.fromJson<int>(json['stockQuantity']),trackStock: serializer.fromJson<bool>(json['trackStock']),);}
@override Map<String, dynamic> toJson({ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return <String, dynamic>{
'id': serializer.toJson<int>(id),'name': serializer.toJson<String>(name),'category': serializer.toJson<String>(category),'defaultStation': serializer.toJson<String>(defaultStation),'modifiers': serializer.toJson<List<String>>(modifiers),'price': serializer.toJson<double>(price),'requiredModifiers': serializer.toJson<List<String>>(requiredModifiers),'tags': serializer.toJson<List<String>>(tags),'stockQuantity': serializer.toJson<int>(stockQuantity),'trackStock': serializer.toJson<bool>(trackStock),};}MenuItemData copyWith({int? id,String? name,String? category,String? defaultStation,List<String>? modifiers,double? price,List<String>? requiredModifiers,List<String>? tags,int? stockQuantity,bool? trackStock}) => MenuItemData(id: id ?? this.id,name: name ?? this.name,category: category ?? this.category,defaultStation: defaultStation ?? this.defaultStation,modifiers: modifiers ?? this.modifiers,price: price ?? this.price,requiredModifiers: requiredModifiers ?? this.requiredModifiers,tags: tags ?? this.tags,stockQuantity: stockQuantity ?? this.stockQuantity,trackStock: trackStock ?? this.trackStock,);MenuItemData copyWithCompanion(MenuItemsCompanion data) {
return MenuItemData(
id: data.id.present ? data.id.value : this.id,name: data.name.present ? data.name.value : this.name,category: data.category.present ? data.category.value : this.category,defaultStation: data.defaultStation.present ? data.defaultStation.value : this.defaultStation,modifiers: data.modifiers.present ? data.modifiers.value : this.modifiers,price: data.price.present ? data.price.value : this.price,requiredModifiers: data.requiredModifiers.present ? data.requiredModifiers.value : this.requiredModifiers,tags: data.tags.present ? data.tags.value : this.tags,stockQuantity: data.stockQuantity.present ? data.stockQuantity.value : this.stockQuantity,trackStock: data.trackStock.present ? data.trackStock.value : this.trackStock,);
}
@override
String toString() {return (StringBuffer('MenuItemData(')..write('id: $id, ')..write('name: $name, ')..write('category: $category, ')..write('defaultStation: $defaultStation, ')..write('modifiers: $modifiers, ')..write('price: $price, ')..write('requiredModifiers: $requiredModifiers, ')..write('tags: $tags, ')..write('stockQuantity: $stockQuantity, ')..write('trackStock: $trackStock')..write(')')).toString();}
@override
 int get hashCode => Object.hash(id, name, category, defaultStation, modifiers, price, requiredModifiers, tags, stockQuantity, trackStock);@override
bool operator ==(Object other) => identical(this, other) || (other is MenuItemData && other.id == this.id && other.name == this.name && other.category == this.category && other.defaultStation == this.defaultStation && other.modifiers == this.modifiers && other.price == this.price && other.requiredModifiers == this.requiredModifiers && other.tags == this.tags && other.stockQuantity == this.stockQuantity && other.trackStock == this.trackStock);
}class MenuItemsCompanion extends UpdateCompanion<MenuItemData> {
final Value<int> id;
final Value<String> name;
final Value<String> category;
final Value<String> defaultStation;
final Value<List<String>> modifiers;
final Value<double> price;
final Value<List<String>> requiredModifiers;
final Value<List<String>> tags;
final Value<int> stockQuantity;
final Value<bool> trackStock;
const MenuItemsCompanion({this.id = const Value.absent(),this.name = const Value.absent(),this.category = const Value.absent(),this.defaultStation = const Value.absent(),this.modifiers = const Value.absent(),this.price = const Value.absent(),this.requiredModifiers = const Value.absent(),this.tags = const Value.absent(),this.stockQuantity = const Value.absent(),this.trackStock = const Value.absent(),});
MenuItemsCompanion.insert({this.id = const Value.absent(),required String name,required String category,required String defaultStation,required List<String> modifiers,this.price = const Value.absent(),this.requiredModifiers = const Value.absent(),this.tags = const Value.absent(),this.stockQuantity = const Value.absent(),this.trackStock = const Value.absent(),}): name = Value(name), category = Value(category), defaultStation = Value(defaultStation), modifiers = Value(modifiers);
static Insertable<MenuItemData> custom({Expression<int>? id, 
Expression<String>? name, 
Expression<String>? category, 
Expression<String>? defaultStation, 
Expression<String>? modifiers, 
Expression<double>? price, 
Expression<String>? requiredModifiers, 
Expression<String>? tags, 
Expression<int>? stockQuantity, 
Expression<bool>? trackStock, 
}) {
return RawValuesInsertable({if (id != null)'id': id,if (name != null)'name': name,if (category != null)'category': category,if (defaultStation != null)'default_station': defaultStation,if (modifiers != null)'modifiers': modifiers,if (price != null)'price': price,if (requiredModifiers != null)'required_modifiers': requiredModifiers,if (tags != null)'tags': tags,if (stockQuantity != null)'stock_quantity': stockQuantity,if (trackStock != null)'track_stock': trackStock,});
}MenuItemsCompanion copyWith({Value<int>? id, Value<String>? name, Value<String>? category, Value<String>? defaultStation, Value<List<String>>? modifiers, Value<double>? price, Value<List<String>>? requiredModifiers, Value<List<String>>? tags, Value<int>? stockQuantity, Value<bool>? trackStock}) {
return MenuItemsCompanion(id: id ?? this.id,name: name ?? this.name,category: category ?? this.category,defaultStation: defaultStation ?? this.defaultStation,modifiers: modifiers ?? this.modifiers,price: price ?? this.price,requiredModifiers: requiredModifiers ?? this.requiredModifiers,tags: tags ?? this.tags,stockQuantity: stockQuantity ?? this.stockQuantity,trackStock: trackStock ?? this.trackStock,);
}
@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};if (id.present) {
map['id'] = Variable<int>(id.value);}
if (name.present) {
map['name'] = Variable<String>(name.value);}
if (category.present) {
map['category'] = Variable<String>(category.value);}
if (defaultStation.present) {
map['default_station'] = Variable<String>(defaultStation.value);}
if (modifiers.present) {
map['modifiers'] = Variable<String>($MenuItemsTable.$convertermodifiers.toSql(modifiers.value));}
if (price.present) {
map['price'] = Variable<double>(price.value);}
if (requiredModifiers.present) {
map['required_modifiers'] = Variable<String>($MenuItemsTable.$converterrequiredModifiers.toSql(requiredModifiers.value));}
if (tags.present) {
map['tags'] = Variable<String>($MenuItemsTable.$convertertags.toSql(tags.value));}
if (stockQuantity.present) {
map['stock_quantity'] = Variable<int>(stockQuantity.value);}
if (trackStock.present) {
map['track_stock'] = Variable<bool>(trackStock.value);}
return map; 
}
@override
String toString() {return (StringBuffer('MenuItemsCompanion(')..write('id: $id, ')..write('name: $name, ')..write('category: $category, ')..write('defaultStation: $defaultStation, ')..write('modifiers: $modifiers, ')..write('price: $price, ')..write('requiredModifiers: $requiredModifiers, ')..write('tags: $tags, ')..write('stockQuantity: $stockQuantity, ')..write('trackStock: $trackStock')..write(')')).toString();}
}
class $StationsTable extends Stations with TableInfo<$StationsTable, StationData>{
@override final GeneratedDatabase attachedDatabase;
final String? _alias;
$StationsTable(this.attachedDatabase, [this._alias]);
static const VerificationMeta _idMeta = const VerificationMeta('id');
@override
late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false, hasAutoIncrement: true, type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
static const VerificationMeta _nameMeta = const VerificationMeta('name');
@override
late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 50), type: DriftSqlType.string, requiredDuringInsert: true, defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
@override
List<GeneratedColumn> get $columns => [id, name];
@override
String get aliasedName => _alias ?? actualTableName;
@override
 String get actualTableName => $name;
static const String $name = 'stations';
@override
VerificationContext validateIntegrity(Insertable<StationData> instance, {bool isInserting = false}) {
final context = VerificationContext();
final data = instance.toColumns(true);
if (data.containsKey('id')) {
context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));}if (data.containsKey('name')) {
context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));} else if (isInserting) {
context.missing(_nameMeta);
}
return context;
}
@override
Set<GeneratedColumn> get $primaryKey => {id};
@override StationData map(Map<String, dynamic> data, {String? tablePrefix})  {
final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';return StationData(id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!, name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!, );
}
@override
$StationsTable createAlias(String alias) {
return $StationsTable(attachedDatabase, alias);}}class StationData extends DataClass implements Insertable<StationData> 
{
final int id;
final String name;
const StationData({required this.id, required this.name});@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};map['id'] = Variable<int>(id);
map['name'] = Variable<String>(name);
return map; 
}
StationsCompanion toCompanion(bool nullToAbsent) {
return StationsCompanion(id: Value(id),name: Value(name),);
}
factory StationData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return StationData(id: serializer.fromJson<int>(json['id']),name: serializer.fromJson<String>(json['name']),);}
@override Map<String, dynamic> toJson({ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return <String, dynamic>{
'id': serializer.toJson<int>(id),'name': serializer.toJson<String>(name),};}StationData copyWith({int? id,String? name}) => StationData(id: id ?? this.id,name: name ?? this.name,);StationData copyWithCompanion(StationsCompanion data) {
return StationData(
id: data.id.present ? data.id.value : this.id,name: data.name.present ? data.name.value : this.name,);
}
@override
String toString() {return (StringBuffer('StationData(')..write('id: $id, ')..write('name: $name')..write(')')).toString();}
@override
 int get hashCode => Object.hash(id, name);@override
bool operator ==(Object other) => identical(this, other) || (other is StationData && other.id == this.id && other.name == this.name);
}class StationsCompanion extends UpdateCompanion<StationData> {
final Value<int> id;
final Value<String> name;
const StationsCompanion({this.id = const Value.absent(),this.name = const Value.absent(),});
StationsCompanion.insert({this.id = const Value.absent(),required String name,}): name = Value(name);
static Insertable<StationData> custom({Expression<int>? id, 
Expression<String>? name, 
}) {
return RawValuesInsertable({if (id != null)'id': id,if (name != null)'name': name,});
}StationsCompanion copyWith({Value<int>? id, Value<String>? name}) {
return StationsCompanion(id: id ?? this.id,name: name ?? this.name,);
}
@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};if (id.present) {
map['id'] = Variable<int>(id.value);}
if (name.present) {
map['name'] = Variable<String>(name.value);}
return map; 
}
@override
String toString() {return (StringBuffer('StationsCompanion(')..write('id: $id, ')..write('name: $name')..write(')')).toString();}
}
class $GlobalModifiersTable extends GlobalModifiers with TableInfo<$GlobalModifiersTable, GlobalModifierData>{
@override final GeneratedDatabase attachedDatabase;
final String? _alias;
$GlobalModifiersTable(this.attachedDatabase, [this._alias]);
static const VerificationMeta _idMeta = const VerificationMeta('id');
@override
late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false, hasAutoIncrement: true, type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
static const VerificationMeta _nameMeta = const VerificationMeta('name');
@override
late final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false, additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1,maxTextLength: 100), type: DriftSqlType.string, requiredDuringInsert: true, defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
@override
List<GeneratedColumn> get $columns => [id, name];
@override
String get aliasedName => _alias ?? actualTableName;
@override
 String get actualTableName => $name;
static const String $name = 'global_modifiers';
@override
VerificationContext validateIntegrity(Insertable<GlobalModifierData> instance, {bool isInserting = false}) {
final context = VerificationContext();
final data = instance.toColumns(true);
if (data.containsKey('id')) {
context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));}if (data.containsKey('name')) {
context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));} else if (isInserting) {
context.missing(_nameMeta);
}
return context;
}
@override
Set<GeneratedColumn> get $primaryKey => {id};
@override GlobalModifierData map(Map<String, dynamic> data, {String? tablePrefix})  {
final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';return GlobalModifierData(id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!, name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!, );
}
@override
$GlobalModifiersTable createAlias(String alias) {
return $GlobalModifiersTable(attachedDatabase, alias);}}class GlobalModifierData extends DataClass implements Insertable<GlobalModifierData> 
{
final int id;
final String name;
const GlobalModifierData({required this.id, required this.name});@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};map['id'] = Variable<int>(id);
map['name'] = Variable<String>(name);
return map; 
}
GlobalModifiersCompanion toCompanion(bool nullToAbsent) {
return GlobalModifiersCompanion(id: Value(id),name: Value(name),);
}
factory GlobalModifierData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return GlobalModifierData(id: serializer.fromJson<int>(json['id']),name: serializer.fromJson<String>(json['name']),);}
@override Map<String, dynamic> toJson({ValueSerializer? serializer}) {
serializer ??= driftRuntimeOptions.defaultSerializer;
return <String, dynamic>{
'id': serializer.toJson<int>(id),'name': serializer.toJson<String>(name),};}GlobalModifierData copyWith({int? id,String? name}) => GlobalModifierData(id: id ?? this.id,name: name ?? this.name,);GlobalModifierData copyWithCompanion(GlobalModifiersCompanion data) {
return GlobalModifierData(
id: data.id.present ? data.id.value : this.id,name: data.name.present ? data.name.value : this.name,);
}
@override
String toString() {return (StringBuffer('GlobalModifierData(')..write('id: $id, ')..write('name: $name')..write(')')).toString();}
@override
 int get hashCode => Object.hash(id, name);@override
bool operator ==(Object other) => identical(this, other) || (other is GlobalModifierData && other.id == this.id && other.name == this.name);
}class GlobalModifiersCompanion extends UpdateCompanion<GlobalModifierData> {
final Value<int> id;
final Value<String> name;
const GlobalModifiersCompanion({this.id = const Value.absent(),this.name = const Value.absent(),});
GlobalModifiersCompanion.insert({this.id = const Value.absent(),required String name,}): name = Value(name);
static Insertable<GlobalModifierData> custom({Expression<int>? id, 
Expression<String>? name, 
}) {
return RawValuesInsertable({if (id != null)'id': id,if (name != null)'name': name,});
}GlobalModifiersCompanion copyWith({Value<int>? id, Value<String>? name}) {
return GlobalModifiersCompanion(id: id ?? this.id,name: name ?? this.name,);
}
@override
Map<String, Expression> toColumns(bool nullToAbsent) {
final map = <String, Expression> {};if (id.present) {
map['id'] = Variable<int>(id.value);}
if (name.present) {
map['name'] = Variable<String>(name.value);}
return map; 
}
@override
String toString() {return (StringBuffer('GlobalModifiersCompanion(')..write('id: $id, ')..write('name: $name')..write(')')).toString();}
}
abstract class _$KDSDatabase extends GeneratedDatabase{
_$KDSDatabase(QueryExecutor e): super(e);
$KDSDatabaseManager get managers => $KDSDatabaseManager(this);
late final $KDSOrdersTable kDSOrders = $KDSOrdersTable(this);
late final $KDSItemsTable kDSItems = $KDSItemsTable(this);
late final $MenuItemsTable menuItems = $MenuItemsTable(this);
late final $StationsTable stations = $StationsTable(this);
late final $GlobalModifiersTable globalModifiers = $GlobalModifiersTable(this);
@override
Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
@override
List<DatabaseSchemaEntity> get allSchemaEntities => [kDSOrders, kDSItems, menuItems, stations, globalModifiers];
}
typedef $$KDSOrdersTableCreateCompanionBuilder = KDSOrdersCompanion Function({required String uuid,required String customerName,required DateTime timestamp,required OrderStatus status,Value<int> rowid,});
typedef $$KDSOrdersTableUpdateCompanionBuilder = KDSOrdersCompanion Function({Value<String> uuid,Value<String> customerName,Value<DateTime> timestamp,Value<OrderStatus> status,Value<int> rowid,});
      final class $$KDSOrdersTableReferences extends BaseReferences<
        _$KDSDatabase,
        $KDSOrdersTable,
        KDSOrderData> {
        $$KDSOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);
        
                  
                  static MultiTypedResultKey<
          $KDSItemsTable,
          List<KDSItemData>
        > _kDSItemsRefsTable(_$KDSDatabase db) =>
          MultiTypedResultKey.fromTable(
          db.kDSItems, 
          aliasName: $_aliasNameGenerator(
            db.kDSOrders.uuid,
            db.kDSItems.orderUuid)
        );

          $$KDSItemsTableProcessedTableManager get kDSItemsRefs {
        final manager = $$KDSItemsTableTableManager(
            $_db, $_db.kDSItems
            ).filter(
              (f) => f.orderUuid.uuid(
              $_item.uuid
            )
          );

          final cache = $_typedResult.readTableOrNull(_kDSItemsRefsTable($_db));
          return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));


        }
        

      }class $$KDSOrdersTableFilterComposer extends Composer<
        _$KDSDatabase,
        $KDSOrdersTable> {
        $$KDSOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp,
      builder: (column) => 
      ColumnFilters(column));
      
          ColumnWithTypeConverterFilters<OrderStatus,OrderStatus,int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
        Expression<bool> kDSItemsRefs(
          Expression<bool> Function( $$KDSItemsTableFilterComposer f) f
        ) {
                final $$KDSItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.kDSItems,
      getReferencedColumn: (t) => t.orderUuid,
      builder: (joinBuilder,{$addJoinBuilderToRootComposer,$removeJoinBuilderFromRootComposer }) => 
      $$KDSItemsTableFilterComposer(
              $db: $db,
              $table: $db.kDSItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
        ));
          return f(composer);
        }

        }
      class $$KDSOrdersTableOrderingComposer extends Composer<
        _$KDSDatabase,
        $KDSOrdersTable> {
        $$KDSOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => 
      ColumnOrderings(column));
      
        }
      class $$KDSOrdersTableAnnotationComposer extends Composer<
        _$KDSDatabase,
        $KDSOrdersTable> {
        $$KDSOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          GeneratedColumn<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => column);
      
GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => column);
      
GeneratedColumn<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<OrderStatus,int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => column);
      
        Expression<T> kDSItemsRefs<T extends Object>(
          Expression<T> Function( $$KDSItemsTableAnnotationComposer a) f
        ) {
                final $$KDSItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.kDSItems,
      getReferencedColumn: (t) => t.orderUuid,
      builder: (joinBuilder,{$addJoinBuilderToRootComposer,$removeJoinBuilderFromRootComposer }) => 
      $$KDSItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.kDSItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
        ));
          return f(composer);
        }

        }
      class $$KDSOrdersTableTableManager extends RootTableManager    <_$KDSDatabase,
    $KDSOrdersTable,
    KDSOrderData,
    $$KDSOrdersTableFilterComposer,
    $$KDSOrdersTableOrderingComposer,
    $$KDSOrdersTableAnnotationComposer,
    $$KDSOrdersTableCreateCompanionBuilder,
    $$KDSOrdersTableUpdateCompanionBuilder,
    (KDSOrderData,$$KDSOrdersTableReferences),
    KDSOrderData,
    PrefetchHooks Function({bool kDSItemsRefs})
    > {
    $$KDSOrdersTableTableManager(_$KDSDatabase db, $KDSOrdersTable table) : super(
      TableManagerState(
        db: db,
        table: table,
        createFilteringComposer: () => $$KDSOrdersTableFilterComposer($db: db,$table:table),
        createOrderingComposer: () => $$KDSOrdersTableOrderingComposer($db: db,$table:table),
        createComputedFieldComposer: () => $$KDSOrdersTableAnnotationComposer($db: db,$table:table),
        updateCompanionCallback: ({Value<String> uuid = const Value.absent(),Value<String> customerName = const Value.absent(),Value<DateTime> timestamp = const Value.absent(),Value<OrderStatus> status = const Value.absent(),Value<int> rowid = const Value.absent(),})=> KDSOrdersCompanion(uuid: uuid,customerName: customerName,timestamp: timestamp,status: status,rowid: rowid,),
        createCompanionCallback: ({required String uuid,required String customerName,required DateTime timestamp,required OrderStatus status,Value<int> rowid = const Value.absent(),})=> KDSOrdersCompanion.insert(uuid: uuid,customerName: customerName,timestamp: timestamp,status: status,rowid: rowid,),
        withReferenceMapper: (p0) => p0
              .map(
                  (e) =>
                     (e.readTable(table), $$KDSOrdersTableReferences(db, table, e))
                  )
              .toList(),
        prefetchHooksCallback:         ({kDSItemsRefs = false}){
          return PrefetchHooks(
            db: db,
            explicitlyWatchedTables: [
             if (kDSItemsRefs) db.kDSItems
            ],
            addJoins: null,
            getPrefetchedDataCallback: (items) async {
            return [
                      if (kDSItemsRefs) await $_getPrefetchedData(
                  currentTable: table,
                  referencedTable:
                      $$KDSOrdersTableReferences._kDSItemsRefsTable(db),
                  managerFromTypedResult: (p0) =>
                      $$KDSOrdersTableReferences(db, table, p0).kDSItemsRefs,
                  referencedItemsForCurrentItem: (item, referencedItems) =>
                      referencedItems.where((e) => e.orderUuid == item.uuid),
                  typedResults: items)
            
                ];
              },
          );
        }
,
        ));
        }
    typedef $$KDSOrdersTableProcessedTableManager = ProcessedTableManager    <_$KDSDatabase,
    $KDSOrdersTable,
    KDSOrderData,
    $$KDSOrdersTableFilterComposer,
    $$KDSOrdersTableOrderingComposer,
    $$KDSOrdersTableAnnotationComposer,
    $$KDSOrdersTableCreateCompanionBuilder,
    $$KDSOrdersTableUpdateCompanionBuilder,
    (KDSOrderData,$$KDSOrdersTableReferences),
    KDSOrderData,
    PrefetchHooks Function({bool kDSItemsRefs})
    >;typedef $$KDSItemsTableCreateCompanionBuilder = KDSItemsCompanion Function({Value<int> id,required String uuid,required String orderUuid,required String name,required List<String> modifiers,required String stationTag,required ItemStatus status,Value<double> price,});
typedef $$KDSItemsTableUpdateCompanionBuilder = KDSItemsCompanion Function({Value<int> id,Value<String> uuid,Value<String> orderUuid,Value<String> name,Value<List<String>> modifiers,Value<String> stationTag,Value<ItemStatus> status,Value<double> price,});
      final class $$KDSItemsTableReferences extends BaseReferences<
        _$KDSDatabase,
        $KDSItemsTable,
        KDSItemData> {
        $$KDSItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);
        
                          static $KDSOrdersTable _orderUuidTable(_$KDSDatabase db) => 
            db.kDSOrders.createAlias($_aliasNameGenerator(
            db.kDSItems.orderUuid,
            db.kDSOrders.uuid));
          

        $$KDSOrdersTableProcessedTableManager? get orderUuid {
          if ($_item.orderUuid == null) return null;
          final manager = $$KDSOrdersTableTableManager($_db, $_db.kDSOrders).filter((f) => f.uuid($_item.orderUuid!));
          final item = $_typedResult.readTableOrNull(_orderUuidTable($_db));
          if (item == null) return manager;
          return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
        }


      }class $$KDSItemsTableFilterComposer extends Composer<
        _$KDSDatabase,
        $KDSItemsTable> {
        $$KDSItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnFilters<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnFilters(column));
      
          ColumnWithTypeConverterFilters<List<String>,List<String>,String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
ColumnFilters<String> get stationTag => $composableBuilder(
      column: $table.stationTag,
      builder: (column) => 
      ColumnFilters(column));
      
          ColumnWithTypeConverterFilters<ItemStatus,ItemStatus,int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
ColumnFilters<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => 
      ColumnFilters(column));
      
        $$KDSOrdersTableFilterComposer get orderUuid {
                final $$KDSOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderUuid,
      referencedTable: $db.kDSOrders,
      getReferencedColumn: (t) => t.uuid,
      builder: (joinBuilder,{$addJoinBuilderToRootComposer,$removeJoinBuilderFromRootComposer }) => 
      $$KDSOrdersTableFilterComposer(
              $db: $db,
              $table: $db.kDSOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
        ));
          return composer;
        }
        }
      class $$KDSItemsTableOrderingComposer extends Composer<
        _$KDSDatabase,
        $KDSItemsTable> {
        $$KDSItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get stationTag => $composableBuilder(
      column: $table.stationTag,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => 
      ColumnOrderings(column));
      
        $$KDSOrdersTableOrderingComposer get orderUuid {
                final $$KDSOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderUuid,
      referencedTable: $db.kDSOrders,
      getReferencedColumn: (t) => t.uuid,
      builder: (joinBuilder,{$addJoinBuilderToRootComposer,$removeJoinBuilderFromRootComposer }) => 
      $$KDSOrdersTableOrderingComposer(
              $db: $db,
              $table: $db.kDSOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
        ));
          return composer;
        }
        }
      class $$KDSItemsTableAnnotationComposer extends Composer<
        _$KDSDatabase,
        $KDSItemsTable> {
        $$KDSItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          GeneratedColumn<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => column);
      
GeneratedColumn<String> get uuid => $composableBuilder(
      column: $table.uuid,
      builder: (column) => column);
      
GeneratedColumn<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<List<String>,String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => column);
      
GeneratedColumn<String> get stationTag => $composableBuilder(
      column: $table.stationTag,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<ItemStatus,int> get status => $composableBuilder(
      column: $table.status,
      builder: (column) => column);
      
GeneratedColumn<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => column);
      
        $$KDSOrdersTableAnnotationComposer get orderUuid {
                final $$KDSOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderUuid,
      referencedTable: $db.kDSOrders,
      getReferencedColumn: (t) => t.uuid,
      builder: (joinBuilder,{$addJoinBuilderToRootComposer,$removeJoinBuilderFromRootComposer }) => 
      $$KDSOrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.kDSOrders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
        ));
          return composer;
        }
        }
      class $$KDSItemsTableTableManager extends RootTableManager    <_$KDSDatabase,
    $KDSItemsTable,
    KDSItemData,
    $$KDSItemsTableFilterComposer,
    $$KDSItemsTableOrderingComposer,
    $$KDSItemsTableAnnotationComposer,
    $$KDSItemsTableCreateCompanionBuilder,
    $$KDSItemsTableUpdateCompanionBuilder,
    (KDSItemData,$$KDSItemsTableReferences),
    KDSItemData,
    PrefetchHooks Function({bool orderUuid})
    > {
    $$KDSItemsTableTableManager(_$KDSDatabase db, $KDSItemsTable table) : super(
      TableManagerState(
        db: db,
        table: table,
        createFilteringComposer: () => $$KDSItemsTableFilterComposer($db: db,$table:table),
        createOrderingComposer: () => $$KDSItemsTableOrderingComposer($db: db,$table:table),
        createComputedFieldComposer: () => $$KDSItemsTableAnnotationComposer($db: db,$table:table),
        updateCompanionCallback: ({Value<int> id = const Value.absent(),Value<String> uuid = const Value.absent(),Value<String> orderUuid = const Value.absent(),Value<String> name = const Value.absent(),Value<List<String>> modifiers = const Value.absent(),Value<String> stationTag = const Value.absent(),Value<ItemStatus> status = const Value.absent(),Value<double> price = const Value.absent(),})=> KDSItemsCompanion(id: id,uuid: uuid,orderUuid: orderUuid,name: name,modifiers: modifiers,stationTag: stationTag,status: status,price: price,),
        createCompanionCallback: ({Value<int> id = const Value.absent(),required String uuid,required String orderUuid,required String name,required List<String> modifiers,required String stationTag,required ItemStatus status,Value<double> price = const Value.absent(),})=> KDSItemsCompanion.insert(id: id,uuid: uuid,orderUuid: orderUuid,name: name,modifiers: modifiers,stationTag: stationTag,status: status,price: price,),
        withReferenceMapper: (p0) => p0
              .map(
                  (e) =>
                     (e.readTable(table), $$KDSItemsTableReferences(db, table, e))
                  )
              .toList(),
        prefetchHooksCallback:         ({orderUuid = false}){
          return PrefetchHooks(
            db: db,
            explicitlyWatchedTables: [
             
            ],
            addJoins: <T extends TableManagerState<dynamic,dynamic,dynamic,dynamic,dynamic,dynamic,dynamic,dynamic,dynamic,dynamic,dynamic>>(state) {

                                  if (orderUuid){
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderUuid,
                    referencedTable:
                        $$KDSItemsTableReferences._orderUuidTable(db),
                    referencedColumn:
                        $$KDSItemsTableReferences._orderUuidTable(db).uuid,
                  ) as T;
               }

                return state;
              }
,
            getPrefetchedDataCallback: (items) async {
            return [
            
                ];
              },
          );
        }
,
        ));
        }
    typedef $$KDSItemsTableProcessedTableManager = ProcessedTableManager    <_$KDSDatabase,
    $KDSItemsTable,
    KDSItemData,
    $$KDSItemsTableFilterComposer,
    $$KDSItemsTableOrderingComposer,
    $$KDSItemsTableAnnotationComposer,
    $$KDSItemsTableCreateCompanionBuilder,
    $$KDSItemsTableUpdateCompanionBuilder,
    (KDSItemData,$$KDSItemsTableReferences),
    KDSItemData,
    PrefetchHooks Function({bool orderUuid})
    >;typedef $$MenuItemsTableCreateCompanionBuilder = MenuItemsCompanion Function({Value<int> id,required String name,required String category,required String defaultStation,required List<String> modifiers,Value<double> price,Value<List<String>> requiredModifiers,Value<List<String>> tags,Value<int> stockQuantity,Value<bool> trackStock,});
typedef $$MenuItemsTableUpdateCompanionBuilder = MenuItemsCompanion Function({Value<int> id,Value<String> name,Value<String> category,Value<String> defaultStation,Value<List<String>> modifiers,Value<double> price,Value<List<String>> requiredModifiers,Value<List<String>> tags,Value<int> stockQuantity,Value<bool> trackStock,});
class $$MenuItemsTableFilterComposer extends Composer<
        _$KDSDatabase,
        $MenuItemsTable> {
        $$MenuItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnFilters<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get category => $composableBuilder(
      column: $table.category,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get defaultStation => $composableBuilder(
      column: $table.defaultStation,
      builder: (column) => 
      ColumnFilters(column));
      
          ColumnWithTypeConverterFilters<List<String>,List<String>,String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
ColumnFilters<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => 
      ColumnFilters(column));
      
          ColumnWithTypeConverterFilters<List<String>,List<String>,String> get requiredModifiers => $composableBuilder(
      column: $table.requiredModifiers,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
          ColumnWithTypeConverterFilters<List<String>,List<String>,String> get tags => $composableBuilder(
      column: $table.tags,
      builder: (column) => 
      ColumnWithTypeConverterFilters(column));
      
ColumnFilters<int> get stockQuantity => $composableBuilder(
      column: $table.stockQuantity,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<bool> get trackStock => $composableBuilder(
      column: $table.trackStock,
      builder: (column) => 
      ColumnFilters(column));
      
        }
      class $$MenuItemsTableOrderingComposer extends Composer<
        _$KDSDatabase,
        $MenuItemsTable> {
        $$MenuItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get defaultStation => $composableBuilder(
      column: $table.defaultStation,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get requiredModifiers => $composableBuilder(
      column: $table.requiredModifiers,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<int> get stockQuantity => $composableBuilder(
      column: $table.stockQuantity,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<bool> get trackStock => $composableBuilder(
      column: $table.trackStock,
      builder: (column) => 
      ColumnOrderings(column));
      
        }
      class $$MenuItemsTableAnnotationComposer extends Composer<
        _$KDSDatabase,
        $MenuItemsTable> {
        $$MenuItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          GeneratedColumn<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => column);
      
GeneratedColumn<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => column);
      
GeneratedColumn<String> get category => $composableBuilder(
      column: $table.category,
      builder: (column) => column);
      
GeneratedColumn<String> get defaultStation => $composableBuilder(
      column: $table.defaultStation,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<List<String>,String> get modifiers => $composableBuilder(
      column: $table.modifiers,
      builder: (column) => column);
      
GeneratedColumn<double> get price => $composableBuilder(
      column: $table.price,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<List<String>,String> get requiredModifiers => $composableBuilder(
      column: $table.requiredModifiers,
      builder: (column) => column);
      
          GeneratedColumnWithTypeConverter<List<String>,String> get tags => $composableBuilder(
      column: $table.tags,
      builder: (column) => column);
      
GeneratedColumn<int> get stockQuantity => $composableBuilder(
      column: $table.stockQuantity,
      builder: (column) => column);
      
GeneratedColumn<bool> get trackStock => $composableBuilder(
      column: $table.trackStock,
      builder: (column) => column);
      
        }
      class $$MenuItemsTableTableManager extends RootTableManager    <_$KDSDatabase,
    $MenuItemsTable,
    MenuItemData,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableAnnotationComposer,
    $$MenuItemsTableCreateCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder,
    (MenuItemData,BaseReferences<_$KDSDatabase,$MenuItemsTable,MenuItemData>),
    MenuItemData,
    PrefetchHooks Function()
    > {
    $$MenuItemsTableTableManager(_$KDSDatabase db, $MenuItemsTable table) : super(
      TableManagerState(
        db: db,
        table: table,
        createFilteringComposer: () => $$MenuItemsTableFilterComposer($db: db,$table:table),
        createOrderingComposer: () => $$MenuItemsTableOrderingComposer($db: db,$table:table),
        createComputedFieldComposer: () => $$MenuItemsTableAnnotationComposer($db: db,$table:table),
        updateCompanionCallback: ({Value<int> id = const Value.absent(),Value<String> name = const Value.absent(),Value<String> category = const Value.absent(),Value<String> defaultStation = const Value.absent(),Value<List<String>> modifiers = const Value.absent(),Value<double> price = const Value.absent(),Value<List<String>> requiredModifiers = const Value.absent(),Value<List<String>> tags = const Value.absent(),Value<int> stockQuantity = const Value.absent(),Value<bool> trackStock = const Value.absent(),})=> MenuItemsCompanion(id: id,name: name,category: category,defaultStation: defaultStation,modifiers: modifiers,price: price,requiredModifiers: requiredModifiers,tags: tags,stockQuantity: stockQuantity,trackStock: trackStock,),
        createCompanionCallback: ({Value<int> id = const Value.absent(),required String name,required String category,required String defaultStation,required List<String> modifiers,Value<double> price = const Value.absent(),Value<List<String>> requiredModifiers = const Value.absent(),Value<List<String>> tags = const Value.absent(),Value<int> stockQuantity = const Value.absent(),Value<bool> trackStock = const Value.absent(),})=> MenuItemsCompanion.insert(id: id,name: name,category: category,defaultStation: defaultStation,modifiers: modifiers,price: price,requiredModifiers: requiredModifiers,tags: tags,stockQuantity: stockQuantity,trackStock: trackStock,),
        withReferenceMapper: (p0) => p0
              .map(
                  (e) =>
                     (e.readTable(table), BaseReferences(db, table, e))
                  )
              .toList(),
        prefetchHooksCallback: null,
        ));
        }
    typedef $$MenuItemsTableProcessedTableManager = ProcessedTableManager    <_$KDSDatabase,
    $MenuItemsTable,
    MenuItemData,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableAnnotationComposer,
    $$MenuItemsTableCreateCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder,
    (MenuItemData,BaseReferences<_$KDSDatabase,$MenuItemsTable,MenuItemData>),
    MenuItemData,
    PrefetchHooks Function()
    >;typedef $$StationsTableCreateCompanionBuilder = StationsCompanion Function({Value<int> id,required String name,});
typedef $$StationsTableUpdateCompanionBuilder = StationsCompanion Function({Value<int> id,Value<String> name,});
class $$StationsTableFilterComposer extends Composer<
        _$KDSDatabase,
        $StationsTable> {
        $$StationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnFilters<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnFilters(column));
      
        }
      class $$StationsTableOrderingComposer extends Composer<
        _$KDSDatabase,
        $StationsTable> {
        $$StationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnOrderings(column));
      
        }
      class $$StationsTableAnnotationComposer extends Composer<
        _$KDSDatabase,
        $StationsTable> {
        $$StationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          GeneratedColumn<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => column);
      
GeneratedColumn<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => column);
      
        }
      class $$StationsTableTableManager extends RootTableManager    <_$KDSDatabase,
    $StationsTable,
    StationData,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableAnnotationComposer,
    $$StationsTableCreateCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder,
    (StationData,BaseReferences<_$KDSDatabase,$StationsTable,StationData>),
    StationData,
    PrefetchHooks Function()
    > {
    $$StationsTableTableManager(_$KDSDatabase db, $StationsTable table) : super(
      TableManagerState(
        db: db,
        table: table,
        createFilteringComposer: () => $$StationsTableFilterComposer($db: db,$table:table),
        createOrderingComposer: () => $$StationsTableOrderingComposer($db: db,$table:table),
        createComputedFieldComposer: () => $$StationsTableAnnotationComposer($db: db,$table:table),
        updateCompanionCallback: ({Value<int> id = const Value.absent(),Value<String> name = const Value.absent(),})=> StationsCompanion(id: id,name: name,),
        createCompanionCallback: ({Value<int> id = const Value.absent(),required String name,})=> StationsCompanion.insert(id: id,name: name,),
        withReferenceMapper: (p0) => p0
              .map(
                  (e) =>
                     (e.readTable(table), BaseReferences(db, table, e))
                  )
              .toList(),
        prefetchHooksCallback: null,
        ));
        }
    typedef $$StationsTableProcessedTableManager = ProcessedTableManager    <_$KDSDatabase,
    $StationsTable,
    StationData,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableAnnotationComposer,
    $$StationsTableCreateCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder,
    (StationData,BaseReferences<_$KDSDatabase,$StationsTable,StationData>),
    StationData,
    PrefetchHooks Function()
    >;typedef $$GlobalModifiersTableCreateCompanionBuilder = GlobalModifiersCompanion Function({Value<int> id,required String name,});
typedef $$GlobalModifiersTableUpdateCompanionBuilder = GlobalModifiersCompanion Function({Value<int> id,Value<String> name,});
class $$GlobalModifiersTableFilterComposer extends Composer<
        _$KDSDatabase,
        $GlobalModifiersTable> {
        $$GlobalModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnFilters<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnFilters(column));
      
ColumnFilters<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnFilters(column));
      
        }
      class $$GlobalModifiersTableOrderingComposer extends Composer<
        _$KDSDatabase,
        $GlobalModifiersTable> {
        $$GlobalModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => 
      ColumnOrderings(column));
      
ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => 
      ColumnOrderings(column));
      
        }
      class $$GlobalModifiersTableAnnotationComposer extends Composer<
        _$KDSDatabase,
        $GlobalModifiersTable> {
        $$GlobalModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
          GeneratedColumn<int> get id => $composableBuilder(
      column: $table.id,
      builder: (column) => column);
      
GeneratedColumn<String> get name => $composableBuilder(
      column: $table.name,
      builder: (column) => column);
      
        }
      class $$GlobalModifiersTableTableManager extends RootTableManager    <_$KDSDatabase,
    $GlobalModifiersTable,
    GlobalModifierData,
    $$GlobalModifiersTableFilterComposer,
    $$GlobalModifiersTableOrderingComposer,
    $$GlobalModifiersTableAnnotationComposer,
    $$GlobalModifiersTableCreateCompanionBuilder,
    $$GlobalModifiersTableUpdateCompanionBuilder,
    (GlobalModifierData,BaseReferences<_$KDSDatabase,$GlobalModifiersTable,GlobalModifierData>),
    GlobalModifierData,
    PrefetchHooks Function()
    > {
    $$GlobalModifiersTableTableManager(_$KDSDatabase db, $GlobalModifiersTable table) : super(
      TableManagerState(
        db: db,
        table: table,
        createFilteringComposer: () => $$GlobalModifiersTableFilterComposer($db: db,$table:table),
        createOrderingComposer: () => $$GlobalModifiersTableOrderingComposer($db: db,$table:table),
        createComputedFieldComposer: () => $$GlobalModifiersTableAnnotationComposer($db: db,$table:table),
        updateCompanionCallback: ({Value<int> id = const Value.absent(),Value<String> name = const Value.absent(),})=> GlobalModifiersCompanion(id: id,name: name,),
        createCompanionCallback: ({Value<int> id = const Value.absent(),required String name,})=> GlobalModifiersCompanion.insert(id: id,name: name,),
        withReferenceMapper: (p0) => p0
              .map(
                  (e) =>
                     (e.readTable(table), BaseReferences(db, table, e))
                  )
              .toList(),
        prefetchHooksCallback: null,
        ));
        }
    typedef $$GlobalModifiersTableProcessedTableManager = ProcessedTableManager    <_$KDSDatabase,
    $GlobalModifiersTable,
    GlobalModifierData,
    $$GlobalModifiersTableFilterComposer,
    $$GlobalModifiersTableOrderingComposer,
    $$GlobalModifiersTableAnnotationComposer,
    $$GlobalModifiersTableCreateCompanionBuilder,
    $$GlobalModifiersTableUpdateCompanionBuilder,
    (GlobalModifierData,BaseReferences<_$KDSDatabase,$GlobalModifiersTable,GlobalModifierData>),
    GlobalModifierData,
    PrefetchHooks Function()
    >;class $KDSDatabaseManager {
final _$KDSDatabase _db;
$KDSDatabaseManager(this._db);
$$KDSOrdersTableTableManager get kDSOrders => $$KDSOrdersTableTableManager(_db, _db.kDSOrders);
$$KDSItemsTableTableManager get kDSItems => $$KDSItemsTableTableManager(_db, _db.kDSItems);
$$MenuItemsTableTableManager get menuItems => $$MenuItemsTableTableManager(_db, _db.menuItems);
$$StationsTableTableManager get stations => $$StationsTableTableManager(_db, _db.stations);
$$GlobalModifiersTableTableManager get globalModifiers => $$GlobalModifiersTableTableManager(_db, _db.globalModifiers);
}

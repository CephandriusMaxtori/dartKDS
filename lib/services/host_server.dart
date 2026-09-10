import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import '../models/connected_client.dart';
import '../models/order_status.dart';
import '../models/item_status.dart';

class HostServer {
  final Map<String, WebSocketChannel> _clientChannels = {};
  final List<ConnectedClient> _clients = [];
  HttpServer? _server;
  KDSDatabase? _db;

  // Callback to notify UI of client changes
  Function? onClientsChanged;

  List<ConnectedClient> get connectedClients => List.unmodifiable(_clients);

  Future<void> start(KDSDatabase db, {int port = 8080}) async {
    _db = db;
    final router = Router();

    // Serve the Web KDS Client
    router.get('/', (Request request) async {
      final html = await _loadWebAsset('index.html');
      return Response.ok(html, headers: {'Content-Type': 'text/html', 'Cache-Control': 'no-store'});
    });

    // Serve the Web POS Host
    router.get('/pos', (Request request) async {
      final html = await _loadWebAsset('host.html');
      return Response.ok(html, headers: {'Content-Type': 'text/html', 'Cache-Control': 'no-store'});
    });

    // API: Get Menu Items
    router.get('/api/menu', (Request request) async {
      final items = await _db!.select(_db!.menuItems).get();
      final data = items.map((i) => {
        'id': i.id,
        'name': i.name,
        'category': i.category,
        'defaultStation': i.defaultStation,
        'modifiers': i.modifiers,
        'requiredModifiers': i.requiredModifiers,
        'tags': i.tags,
        'price': i.price,
        'stockQuantity': i.stockQuantity,
        'trackStock': i.trackStock,
      }).toList();
      return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json'});
    });

    // API: Create Menu Item
    router.post('/api/menu', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      final name = (body['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');

      final station = await _fallbackStationName((body['defaultStation'] ?? '').toString());
      final id = await db.into(db.menuItems).insert(MenuItemsCompanion.insert(
        name: name,
        category: (body['category'] ?? 'All Items').toString(),
        defaultStation: station,
        modifiers: _stringList(body['modifiers']),
        requiredModifiers: drift.Value(_stringList(body['requiredModifiers'])),
        tags: drift.Value(_stringList(body['tags'])),
        price: drift.Value((body['price'] as num?)?.toDouble() ?? 0.0),
        stockQuantity: drift.Value((body['stockQuantity'] as num?)?.toInt() ?? 0),
        trackStock: drift.Value(body['trackStock'] as bool? ?? false),
      ));
      return Response.ok(jsonEncode({'id': id}), headers: {'Content-Type': 'application/json'});
    });

    // API: Update Menu Item
    router.put('/api/menu/<id>', (Request request, String id) async {
      final db = _db!;
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      final existing = await (db.select(db.menuItems)..where((t) => t.id.equals(menuId))).getSingleOrNull();
      if (existing == null) return Response.notFound('Not found');

      final name = body['name'] != null ? (body['name'] as String).trim() : existing.name;
      if (name.isEmpty) return Response.badRequest(body: 'Name required');

      await (db.update(db.menuItems)..where((t) => t.id.equals(menuId))).write(MenuItemsCompanion(
        name: drift.Value(name),
        category: drift.Value(body['category'] != null ? (body['category'] as String) : existing.category),
        defaultStation: drift.Value(body['defaultStation'] != null ? (body['defaultStation'] as String) : existing.defaultStation),
        modifiers: drift.Value(body['modifiers'] != null ? _stringList(body['modifiers']) : existing.modifiers),
        requiredModifiers: drift.Value(body['requiredModifiers'] != null ? _stringList(body['requiredModifiers']) : existing.requiredModifiers),
        tags: drift.Value(body['tags'] != null ? _stringList(body['tags']) : existing.tags),
        price: drift.Value(body['price'] != null ? (body['price'] as num).toDouble() : existing.price),
        stockQuantity: drift.Value(body['stockQuantity'] != null ? (body['stockQuantity'] as num).toInt() : existing.stockQuantity),
        trackStock: drift.Value(body['trackStock'] != null ? (body['trackStock'] as bool) : existing.trackStock),
      ));
      return Response.ok(jsonEncode({'id': menuId}), headers: {'Content-Type': 'application/json'});
    });

    // API: Delete Menu Item
    router.delete('/api/menu/<id>', (Request request, String id) async {
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      await (_db!.delete(_db!.menuItems)..where((t) => t.id.equals(menuId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Set Stock Quantity
    router.post('/api/menu/<id>/stock', (Request request, String id) async {
      final db = _db!;
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      final existing = await (db.select(db.menuItems)..where((t) => t.id.equals(menuId))).getSingleOrNull();
      if (existing == null) return Response.notFound('Not found');

      final raw = (body?['quantity'] as num?)?.toInt();
      final newQty = (raw == null || raw < 0) ? existing.stockQuantity : raw;
      await (db.update(db.menuItems)..where((t) => t.id.equals(menuId))).write(MenuItemsCompanion(stockQuantity: drift.Value(newQty)));
      return Response.ok(jsonEncode({'id': existing.id, 'stockQuantity': newQty}), headers: {'Content-Type': 'application/json'});
    });

    // API: Get Stations
    router.get('/api/stations', (Request request) async {
      final stations = await _db!.select(_db!.stations).get();
      return Response.ok(jsonEncode(stations.map((s) => {'id': s.id, 'name': s.name}).toList()), headers: {'Content-Type': 'application/json'});
    });

    // API: Create Station
    router.post('/api/stations', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      final id = await db.into(db.stations).insert(StationsCompanion.insert(name: name));
      return Response.ok(jsonEncode({'id': id}), headers: {'Content-Type': 'application/json'});
    });

    // API: Rename Station
    router.put('/api/stations/<id>', (Request request, String id) async {
      final db = _db!;
      final stationId = int.tryParse(id);
      if (stationId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      await (db.update(db.stations)..where((t) => t.id.equals(stationId))).write(StationsCompanion(name: drift.Value(name)));
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Delete Station
    router.delete('/api/stations/<id>', (Request request, String id) async {
      final stationId = int.tryParse(id);
      if (stationId == null) return Response.notFound('Not found');
      await (_db!.delete(_db!.stations)..where((t) => t.id.equals(stationId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Get Global Modifiers
    router.get('/api/modifiers', (Request request) async {
      final modifiers = await _db!.select(_db!.globalModifiers).get();
      return Response.ok(jsonEncode(modifiers.map((m) => {'id': m.id, 'name': m.name}).toList()), headers: {'Content-Type': 'application/json'});
    });

    // API: Create Global Modifier
    router.post('/api/modifiers', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      final id = await db.into(db.globalModifiers).insert(GlobalModifiersCompanion.insert(name: name));
      return Response.ok(jsonEncode({'id': id}), headers: {'Content-Type': 'application/json'});
    });

    // API: Delete Global Modifier
    router.delete('/api/modifiers/<id>', (Request request, String id) async {
      final modifierId = int.tryParse(id);
      if (modifierId == null) return Response.notFound('Not found');
      await (_db!.delete(_db!.globalModifiers)..where((t) => t.id.equals(modifierId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Get Orders with items
    router.get('/api/orders', (Request request) async {
      final db = _db!;
      final orders = await (db.select(db.kDSOrders)..orderBy([(t) => drift.OrderingTerm.desc(t.timestamp)])).get();
      final result = <Map<String, dynamic>>[];
      for (final order in orders) {
        final items = await (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(order.uuid))).get();
        result.add({
          'uuid': order.uuid,
          'customerName': order.customerName,
          'timestamp': order.timestamp.toIso8601String(),
          'status': order.status.index,
          'items': items.map((i) => {
            'uuid': i.uuid,
            'name': i.name,
            'modifiers': i.modifiers,
            'stationTag': i.stationTag,
            'status': i.status.index,
            'price': i.price,
          }).toList(),
        });
      }
      return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
    });

    // API: Get Connected Clients
    router.get('/api/clients', (Request request) async {
      final data = _clients.map((c) => {
        'id': c.id,
        'deviceName': c.deviceName,
        'currentStation': c.currentStation,
        'connectedAt': c.connectedAt.toIso8601String(),
      }).toList();
      return Response.ok(jsonEncode(data), headers: {'Content-Type': 'application/json'});
    });

    // API: Export Library Backup
    router.get('/api/library/export', (Request request) async {
      final db = _db!;
      final items = await db.select(db.menuItems).get();
      final stations = await db.select(db.stations).get();
      final modifiers = await db.select(db.globalModifiers).get();
      final data = {
        'version': 1,
        'menuItems': items.map((i) => {
          'name': i.name,
          'category': i.category,
          'defaultStation': i.defaultStation,
          'modifiers': i.modifiers,
          'requiredModifiers': i.requiredModifiers,
          'tags': i.tags,
          'price': i.price,
          'stockQuantity': i.stockQuantity,
          'trackStock': i.trackStock,
        }).toList(),
        'stations': stations.map((s) => {'name': s.name}).toList(),
        'globalModifiers': modifiers.map((m) => {'name': m.name}).toList(),
      };
      return Response.ok(jsonEncode(data), headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': 'attachment; filename="dartkds_backup.json"',
      });
    });

    // API: Import Library Backup
    router.post('/api/library/import', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      try {
        await db.transaction(() async {
          for (final s in (body['stations'] as List? ?? [])) {
            await db.into(db.stations).insertOnConflictUpdate(StationsCompanion.insert(name: s['name'].toString()));
          }
          for (final m in (body['globalModifiers'] as List? ?? [])) {
            await db.into(db.globalModifiers).insertOnConflictUpdate(GlobalModifiersCompanion.insert(name: m['name'].toString()));
          }
          for (final i in (body['menuItems'] as List? ?? [])) {
            await db.into(db.menuItems).insert(MenuItemsCompanion.insert(
              name: i['name'].toString(),
              category: (i['category'] ?? 'All Items').toString(),
              defaultStation: await _fallbackStationName((i['defaultStation'] ?? '').toString()),
              modifiers: _stringList(i['modifiers']),
              requiredModifiers: drift.Value(_stringList(i['requiredModifiers'])),
              tags: drift.Value(_stringList(i['tags'])),
              price: drift.Value((i['price'] as num?)?.toDouble() ?? 0.0),
              stockQuantity: drift.Value((i['stockQuantity'] as num?)?.toInt() ?? 0),
              trackStock: drift.Value(i['trackStock'] as bool? ?? false),
            ));
          }
        });
        return Response.ok(jsonEncode({'success': true}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: 'Import failed: $e');
      }
    });

    router.get('/ws', webSocketHandler((WebSocketChannel webSocket) {
      String? clientId;

      webSocket.stream.listen((message) async {
        try {
          final data = jsonDecode(message.toString());
          
          if (data['type'] == 'RegisterClient') {
            clientId = data['id'];
            _clientChannels[clientId!] = webSocket;
            
            _clients.removeWhere((c) => c.id == clientId);
            _clients.add(ConnectedClient(
              id: clientId!,
              deviceName: data['deviceName'] ?? 'Unknown Device',
              currentStation: data['station'] ?? 'GENERAL',
              connectedAt: DateTime.now(),
            ));
            
            onClientsChanged?.call();
          } else if (data['type'] == 'CreateOrder') {
            // Handle order from Web POS
            final orderData = data['order'];
            final orderUuid = const Uuid().v4();
            final timestamp = DateTime.now();

            await _db!.into(_db!.kDSOrders).insert(KDSOrderData(
              uuid: orderUuid,
              customerName: orderData['customerName'] ?? 'Guest',
              timestamp: timestamp,
              status: OrderStatus.pending,
            ));

            final List<Map<String, dynamic>> jsonItems = [];
            for (final item in orderData['items']) {
              final itemUuid = const Uuid().v4();
              
              // Find menu item to handle stock
              final menuMatches = await (_db!.select(_db!.menuItems)..where((t) => t.name.equals(item['name']))).get();
              if (menuMatches.isNotEmpty && menuMatches.first.trackStock) {
                await (_db!.update(_db!.menuItems)..where((t) => t.id.equals(menuMatches.first.id))).write(
                  MenuItemsCompanion(stockQuantity: drift.Value(menuMatches.first.stockQuantity - 1)),
                );
              }

              await _db!.into(_db!.kDSItems).insert(KDSItemsCompanion.insert(
                uuid: itemUuid,
                orderUuid: orderUuid,
                name: item['name'],
                modifiers: List<String>.from(item['modifiers']),
                stationTag: item['stationTag'] ?? 'GENERAL',
                status: ItemStatus.pending,
                price: drift.Value(item['price']?.toDouble() ?? 0.0),
              ));

              jsonItems.add({
                'uuid': itemUuid,
                'name': item['name'],
                'modifiers': item['modifiers'],
                'stationTag': item['stationTag'],
                'status': ItemStatus.pending.index,
                'price': item['price'],
              });
            }

            final broadcastPayload = jsonEncode({
              'type': 'OrderCreated',
              'order': {
                'uuid': orderUuid,
                'customerName': orderData['customerName'] ?? 'Guest',
                'timestamp': timestamp.toIso8601String(),
                'status': OrderStatus.pending.index,
                'items': jsonItems,
              }
            });
            broadcast(broadcastPayload);
          } else if (data['type'] == 'StationChanged') {
             final idx = _clients.indexWhere((c) => c.id == clientId);
             if (idx != -1) {
                _clients[idx].currentStation = data['station'];
                onClientsChanged?.call();
             }
          } else if (data['type'] != 'RegisterClient') {
            broadcast(message);
          }
        } catch (e) {
          print('Error handling WS message: $e');
        }
      }, onDone: () {
        if (clientId != null) {
          _clientChannels.remove(clientId);
          _clients.removeWhere((c) => c.id == clientId);
          onClientsChanged?.call();
        }
      });
    }));

    _server = await io.serve(router, InternetAddress.anyIPv4, port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    for (var client in _clientChannels.values) {
      client.sink.close();
    }
    _clientChannels.clear();
    _clients.clear();
  }

  void broadcast(dynamic message) {
    for (final client in _clientChannels.values) {
      client.sink.add(message);
    }
  }

  void sendToClient(String clientId, Map<String, dynamic> message) {
    final channel = _clientChannels[clientId];
    if (channel != null) {
      channel.sink.add(jsonEncode(message));
    }
  }

  Future<Map<String, dynamic>?> _jsonBody(Request request) async {
    try {
      return jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Load a web asset (index.html / host.html) preferring a copy placed next
  // to the app executable, so UI updates can be shipped over an air-gapped
  // network without rebuilding the app. Falls back to the bundled asset.
  Future<String> _loadWebAsset(String name) async {
    for (final dir in [File(Platform.resolvedExecutable).parent.path, Directory.current.path]) {
      final local = File('$dir${Platform.pathSeparator}$name');
      if (await local.exists()) return local.readAsString();
    }
    return rootBundle.loadString('assets/$name');
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<String> _fallbackStationName(String name) async {
    if (name.isNotEmpty) return name;
    final stations = await _db!.select(_db!.stations).get();
    if (stations.isNotEmpty) return stations.first.name;
    return 'Main Station';
  }
}

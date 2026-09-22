import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) '../web_io_stub.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart'
    if (dart.library.js_interop) '../web_shelf_io_stub.dart'
    as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart'
    if (dart.library.js_interop) '../web_shelf_ws_stub.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import '../models/connected_client.dart';
import '../models/order_status.dart';
import '../models/item_status.dart';
import 'sync_engine.dart';

const _webUiDirOverride = String.fromEnvironment('WEB_UI_DIR');

const _webMimeTypes = <String, String>{
  '.html': 'text/html',
  '.htm': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ogg': 'audio/ogg',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.pdf': 'application/pdf',
  '.txt': 'text/plain',
  '.map': 'application/json',
  '.frag': 'text/plain',
  '.vert': 'text/plain',
  '.bin': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

const _webUiMissingHtml = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>DartKDS Web UI</title></head>
<body style="background:#0f172a;color:#e2e8f0;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<div style="text-align:center;max-width:560px">
  <h2 style="margin:0 0 12px">Web UI not found</h2>
  <p style="font-size:14px;line-height:1.5">The Flutter web build is not available on this host.\nRun <code style="background:#1e293b;padding:2px 8px;border-radius:4px">flutter build web</code> in the project directory and restart the host to serve it from <code style="background:#1e293b;padding:2px 8px;border-radius:4px">build/web</code>.</p>
</div>
</body>
</html>
''';

class HostServer {
  final Map<String, WebSocketChannel> _clientChannels = {};
  final Map<String, WebSocketChannel> _webHostChannels = {};
  final List<ConnectedClient> _clients = [];
  final List<StreamSubscription> _dbWatchers = [];
  Timer? _webHostNotifyDebounce;
  HttpServer? _server;
  KDSDatabase? _db;
  int _port = 8080;
  String hostId = '';
  String role = 'primary';
  Timer? _heartbeatTimer;

  // Provides the list of known sync peers ({hostId, role, url}) so the web
  // UI can discover failover targets. Set after SyncService starts.
  List<Map<String, String>> Function()? knownPeersProvider;

  // Directory containing the compiled Flutter web build to serve at `/`.
  // Defaults to `<project>/build/web`, overridable via the WEB_UI_DIR
  // dart-define. When null/absent, a helper page is shown instead.
  String? webUiDir;

  // Callback to notify UI of client changes
  Function? onClientsChanged;

  List<ConnectedClient> get connectedClients => List.unmodifiable(_clients);

  bool get isRunning => _server != null;

  Future<void>? _startFuture;

  // Idempotent: safe to call multiple times (e.g. on app restart where the
  // persisted host role routes straight to HostHome). Returns early if the
  // server is already running or a start is already in flight.
  Future<void> start(KDSDatabase db, {int port = 8080}) {
    final pending = _startFuture;
    if (pending != null) return pending;
    if (_server != null) return Future.value();
    final task = _start(db, port: port);
    _startFuture = task;
    task.whenComplete(() {
      if (identical(_startFuture, task)) _startFuture = null;
    });
    return task;
  }

  Future<void> _start(KDSDatabase db, {int port = 8080}) async {
    _db = db;
    _port = port;
    final router = Router();

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      broadcast(
        jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    });

    // API: Get Menu Items
    router.get('/api/menu', (Request request) async {
      final items = await _db!.select(_db!.menuItems).get();
      final data = items
          .map(
            (i) => {
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
              'oneTouch': i.oneTouch,
            },
          )
          .toList();
      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Create Menu Item
    router.post('/api/menu', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      final name = (body['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final station = await _fallbackStationName(
        (body['defaultStation'] ?? '').toString(),
      );
      final id = await db
          .into(db.menuItems)
          .insert(
            MenuItemsCompanion.insert(
              guid: drift.Value(const Uuid().v4()),
              name: name,
              category: (body['category'] ?? 'All Items').toString(),
              defaultStation: station,
              modifiers: _stringList(body['modifiers']),
              requiredModifiers: drift.Value(
                _stringList(body['requiredModifiers']),
              ),
              tags: drift.Value(_stringList(body['tags'])),
              price: drift.Value((body['price'] as num?)?.toDouble() ?? 0.0),
              stockQuantity: drift.Value(
                (body['stockQuantity'] as num?)?.toInt() ?? 0,
              ),
              trackStock: drift.Value(body['trackStock'] as bool? ?? false),
              oneTouch: drift.Value(body['oneTouch'] as bool? ?? false),
              updatedAtMs: drift.Value(nowMs),
            ),
          );
      return Response.ok(
        jsonEncode({'id': id}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Update Menu Item
    router.put('/api/menu/<id>', (Request request, String id) async {
      final db = _db!;
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      final existing = await (db.select(
        db.menuItems,
      )..where((t) => t.id.equals(menuId))).getSingleOrNull();
      if (existing == null) return Response.notFound('Not found');

      final name = body['name'] != null
          ? (body['name'] as String).trim()
          : existing.name;
      if (name.isEmpty) return Response.badRequest(body: 'Name required');

      await (db.update(db.menuItems)..where((t) => t.id.equals(menuId))).write(
        MenuItemsCompanion(
          name: drift.Value(name),
          category: drift.Value(
            body['category'] != null
                ? (body['category'] as String)
                : existing.category,
          ),
          defaultStation: drift.Value(
            body['defaultStation'] != null
                ? (body['defaultStation'] as String)
                : existing.defaultStation,
          ),
          modifiers: drift.Value(
            body['modifiers'] != null
                ? _stringList(body['modifiers'])
                : existing.modifiers,
          ),
          requiredModifiers: drift.Value(
            body['requiredModifiers'] != null
                ? _stringList(body['requiredModifiers'])
                : existing.requiredModifiers,
          ),
          tags: drift.Value(
            body['tags'] != null ? _stringList(body['tags']) : existing.tags,
          ),
          price: drift.Value(
            body['price'] != null
                ? (body['price'] as num).toDouble()
                : existing.price,
          ),
          stockQuantity: drift.Value(
            body['stockQuantity'] != null
                ? (body['stockQuantity'] as num).toInt()
                : existing.stockQuantity,
          ),
          trackStock: drift.Value(
            body['trackStock'] != null
                ? (body['trackStock'] as bool)
                : existing.trackStock,
          ),
          oneTouch: drift.Value(
            body['oneTouch'] != null
                ? (body['oneTouch'] as bool)
                : existing.oneTouch,
          ),
          updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return Response.ok(
        jsonEncode({'id': menuId}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Delete Menu Item
    router.delete('/api/menu/<id>', (Request request, String id) async {
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      await (_db!.delete(
        _db!.menuItems,
      )..where((t) => t.id.equals(menuId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Set Stock Quantity
    router.post('/api/menu/<id>/stock', (Request request, String id) async {
      final db = _db!;
      final menuId = int.tryParse(id);
      if (menuId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      final existing = await (db.select(
        db.menuItems,
      )..where((t) => t.id.equals(menuId))).getSingleOrNull();
      if (existing == null) return Response.notFound('Not found');

      final raw = (body?['quantity'] as num?)?.toInt();
      final newQty = (raw == null || raw < 0) ? existing.stockQuantity : raw;
      await (db.update(db.menuItems)..where((t) => t.id.equals(menuId))).write(
        MenuItemsCompanion(
          stockQuantity: drift.Value(newQty),
          updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return Response.ok(
        jsonEncode({'id': existing.id, 'stockQuantity': newQty}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Get Stations
    router.get('/api/stations', (Request request) async {
      final stations = await _db!.select(_db!.stations).get();
      return Response.ok(
        jsonEncode(stations.map((s) => {'id': s.id, 'name': s.name}).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Create Station
    router.post('/api/stations', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      final id = await db
          .into(db.stations)
          .insert(
            StationsCompanion.insert(
              name: name,
              updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      return Response.ok(
        jsonEncode({'id': id}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Rename Station
    router.put('/api/stations/<id>', (Request request, String id) async {
      final db = _db!;
      final stationId = int.tryParse(id);
      if (stationId == null) return Response.notFound('Not found');
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      await (db.update(
        db.stations,
      )..where((t) => t.id.equals(stationId))).write(
        StationsCompanion(
          name: drift.Value(name),
          updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Delete Station
    router.delete('/api/stations/<id>', (Request request, String id) async {
      final stationId = int.tryParse(id);
      if (stationId == null) return Response.notFound('Not found');
      await (_db!.delete(
        _db!.stations,
      )..where((t) => t.id.equals(stationId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Get Global Modifiers
    router.get('/api/modifiers', (Request request) async {
      final modifiers = await _db!.select(_db!.globalModifiers).get();
      return Response.ok(
        jsonEncode(modifiers.map((m) => {'id': m.id, 'name': m.name}).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Create Global Modifier
    router.post('/api/modifiers', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      final name = (body?['name'] ?? '').toString().trim();
      if (name.isEmpty) return Response.badRequest(body: 'Name required');
      final id = await db
          .into(db.globalModifiers)
          .insert(
            GlobalModifiersCompanion.insert(
              name: name,
              updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
      return Response.ok(
        jsonEncode({'id': id}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Delete Global Modifier
    router.delete('/api/modifiers/<id>', (Request request, String id) async {
      final modifierId = int.tryParse(id);
      if (modifierId == null) return Response.notFound('Not found');
      await (_db!.delete(
        _db!.globalModifiers,
      )..where((t) => t.id.equals(modifierId))).go();
      return Response.ok('{}', headers: {'Content-Type': 'application/json'});
    });

    // API: Get Orders with items
    router.get('/api/orders', (Request request) async {
      final db = _db!;
      final orders =
          await (db.select(db.kDSOrders)
                ..orderBy([(t) => drift.OrderingTerm.desc(t.timestamp)])
                ..limit(100))
              .get(); // Limit to recent 100 for web UI performance

      if (orders.isEmpty) {
        return Response.ok('[]', headers: {'Content-Type': 'application/json'});
      }

      final orderUuids = orders.map((o) => o.uuid).toList();
      final allItems = await (db.select(
        db.kDSItems,
      )..where((t) => t.orderUuid.isIn(orderUuids))).get();

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final i in allItems) {
        itemsByOrder.putIfAbsent(i.orderUuid, () => []).add({
          'uuid': i.uuid,
          'name': i.name,
          'modifiers': i.modifiers,
          'stationTag': i.stationTag,
          'status': i.status.index,
          'price': i.price,
        });
      }

      final result = orders
          .map(
            (order) => {
              'uuid': order.uuid,
              'customerName': order.customerName,
              'timestamp': order.timestamp.toIso8601String(),
              'status': order.status.index,
              'items': itemsByOrder[order.uuid] ?? [],
            },
          )
          .toList();

      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Get Connected Clients
    router.get('/api/clients', (Request request) async {
      final data = _clients
          .map(
            (c) => {
              'id': c.id,
              'deviceName': c.deviceName,
              'currentStation': c.currentStation,
              'connectedAt': c.connectedAt.toIso8601String(),
            },
          )
          .toList();
      return Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // API: Known hosts (self + discovered sync peers) for web failover
    router.get('/api/hosts', (Request request) async {
      final selfUrl = await _selfHostUrl();
      final peers = knownPeersProvider?.call() ?? const <Map<String, String>>[];
      final hosts = <Map<String, String>>[
        {'hostId': hostId, 'role': role, 'url': selfUrl},
        ...peers,
      ];
      return Response.ok(
        jsonEncode({
          'self': {'hostId': hostId, 'role': role, 'url': selfUrl},
          'hosts': hosts,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });
    router.get('/api/library/export', (Request request) async {
      final db = _db!;
      final items = await db.select(db.menuItems).get();
      final stations = await db.select(db.stations).get();
      final modifiers = await db.select(db.globalModifiers).get();
      final data = {
        'version': 1,
        'menuItems': items
            .map(
              (i) => {
                'name': i.name,
                'category': i.category,
                'defaultStation': i.defaultStation,
                'modifiers': i.modifiers,
                'requiredModifiers': i.requiredModifiers,
                'tags': i.tags,
                'price': i.price,
                'stockQuantity': i.stockQuantity,
                'trackStock': i.trackStock,
                'oneTouch': i.oneTouch,
              },
            )
            .toList(),
        'stations': stations.map((s) => {'name': s.name}).toList(),
        'globalModifiers': modifiers.map((m) => {'name': m.name}).toList(),
      };
      return Response.ok(
        jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'Content-Disposition': 'attachment; filename="dartkds_backup.json"',
        },
      );
    });

    // API: Import Library Backup
    router.post('/api/library/import', (Request request) async {
      final db = _db!;
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');
      try {
        await db.transaction(() async {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          for (final s in (body['stations'] as List? ?? [])) {
            await db
                .into(db.stations)
                .insertOnConflictUpdate(
                  StationsCompanion.insert(
                    name: s['name'].toString(),
                    updatedAtMs: drift.Value(nowMs),
                  ),
                );
          }
          for (final m in (body['globalModifiers'] as List? ?? [])) {
            await db
                .into(db.globalModifiers)
                .insertOnConflictUpdate(
                  GlobalModifiersCompanion.insert(
                    name: m['name'].toString(),
                    updatedAtMs: drift.Value(nowMs),
                  ),
                );
          }
          for (final i in (body['menuItems'] as List? ?? [])) {
            await db
                .into(db.menuItems)
                .insert(
                  MenuItemsCompanion.insert(
                    guid: drift.Value(const Uuid().v4()),
                    name: i['name'].toString(),
                    category: (i['category'] ?? 'All Items').toString(),
                    defaultStation: await _fallbackStationName(
                      (i['defaultStation'] ?? '').toString(),
                    ),
                    modifiers: _stringList(i['modifiers']),
                    requiredModifiers: drift.Value(
                      _stringList(i['requiredModifiers']),
                    ),
                    tags: drift.Value(_stringList(i['tags'])),
                    price: drift.Value((i['price'] as num?)?.toDouble() ?? 0.0),
                    stockQuantity: drift.Value(
                      (i['stockQuantity'] as num?)?.toInt() ?? 0,
                    ),
                    trackStock: drift.Value(i['trackStock'] as bool? ?? false),
                    oneTouch: drift.Value(i['oneTouch'] as bool? ?? false),
                    updatedAtMs: drift.Value(nowMs),
                  ),
                );
          }
        });
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: 'Import failed: $e');
      }
    });

    // ── Sync Endpoints ────────────────────────────────────────

    router.get('/api/sync/changes', (Request request) async {
      final sinceStr = request.url.queryParameters['since'];
      final sinceMs = int.tryParse(sinceStr ?? '') ?? 0;
      final engine = SyncEngine(_db!);
      final payload = await engine.getChanges(sinceMs);
      return Response.ok(
        payload,
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/sync/apply', (Request request) async {
      final body = await request.readAsString();
      if (body.isEmpty) return Response.badRequest(body: 'Empty body');
      final engine = SyncEngine(_db!);
      await engine.applyChanges(body);
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/sync/reset', (Request request) async {
      final engine = SyncEngine(_db!);
      final snapshot = await engine.getSnapshot();
      return Response.ok(
        snapshot,
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/webhooks/square', _handleSquareWebhook);

    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel webSocket) {
        String? clientId;
        bool isWebHost = false;

        webSocket.stream.listen(
          (message) async {
            try {
              final data = jsonDecode(message.toString());

              if (data['type'] == 'RegisterClient') {
                clientId = data['id'];
                _clientChannels[clientId!] = webSocket;

                _clients.removeWhere((c) => c.id == clientId);
                _clients.add(
                  ConnectedClient(
                    id: clientId!,
                    deviceName: data['deviceName'] ?? 'Unknown Device',
                    currentStation: data['station'] ?? 'GENERAL',
                    connectedAt: DateTime.now(),
                  ),
                );

                onClientsChanged?.call();
                _notifyWebHostDebounced();

                // Send active (non-complete) orders to the new client
                final allOrders = await (_db!.select(_db!.kDSOrders).get());
                final orders = allOrders
                    .where((o) => o.status != OrderStatus.complete)
                    .toList();
                for (final order in orders) {
                  final items = await (_db!.select(
                    _db!.kDSItems,
                  )..where((t) => t.orderUuid.equals(order.uuid))).get();
                  final payload = jsonEncode({
                    'type': 'OrderCreated',
                    'order': {
                      'uuid': order.uuid,
                      'customerName': order.customerName,
                      'timestamp': order.timestamp.toIso8601String(),
                      'status': order.status.index,
                      'items': items
                          .map(
                            (i) => {
                              'uuid': i.uuid,
                              'name': i.name,
                              'modifiers': i.modifiers,
                              'stationTag': i.stationTag,
                              'status': i.status.index,
                              'price': i.price,
                            },
                          )
                          .toList(),
                    },
                  });
                  webSocket.sink.add(payload);
                }

                // Replay recent finished orders into the client's bumps list
                final finishedOrders =
                    allOrders
                        .where((o) => o.status == OrderStatus.complete)
                        .toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                if (finishedOrders.length > 20) {
                  finishedOrders.removeRange(20, finishedOrders.length);
                }
                if (finishedOrders.isNotEmpty) {
                  final allFinishedItems =
                      await (_db!.select(_db!.kDSItems)..where(
                            (t) => t.orderUuid.isIn(
                              finishedOrders.map((o) => o.uuid).toList(),
                            ),
                          ))
                          .get();
                  _broadcastFinishedOrders(finishedOrders, allFinishedItems);
                }
              } else if (data['type'] == 'RegisterWebHost') {
                isWebHost = true;
                clientId = data['id'];
                _webHostChannels[clientId!] = webSocket;
                webSocket.sink.add(
                  jsonEncode({
                    'type': 'WebHostReady',
                    'hostId': hostId,
                    'role': role,
                  }),
                );
                _sendSnapshot(webSocket);
              } else if (data['type'] == 'CreateOrder') {
                final orderData = data['order'];
                final orderUuid = const Uuid().v4();
                final timestamp = DateTime.now();

                await _db!
                    .into(_db!.kDSOrders)
                    .insert(
                      KDSOrderData(
                        uuid: orderUuid,
                        customerName: orderData['customerName'] ?? 'Guest',
                        timestamp: timestamp,
                        status: OrderStatus.pending,
                        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    );

                final List<Map<String, dynamic>> jsonItems = [];
                for (final item in orderData['items']) {
                  final itemUuid = const Uuid().v4();

                  // Find menu item to handle stock
                  final menuMatches = await (_db!.select(
                    _db!.menuItems,
                  )..where((t) => t.name.equals(item['name']))).get();
                  if (menuMatches.isNotEmpty && menuMatches.first.trackStock) {
                    await (_db!.update(
                      _db!.menuItems,
                    )..where((t) => t.id.equals(menuMatches.first.id))).write(
                      MenuItemsCompanion(
                        stockQuantity: drift.Value(
                          menuMatches.first.stockQuantity - 1,
                        ),
                        updatedAtMs: drift.Value(
                          DateTime.now().millisecondsSinceEpoch,
                        ),
                      ),
                    );
                  }

                  await _db!
                      .into(_db!.kDSItems)
                      .insert(
                        KDSItemsCompanion.insert(
                          uuid: itemUuid,
                          orderUuid: orderUuid,
                          name: item['name'],
                          modifiers: List<String>.from(item['modifiers']),
                          stationTag: item['stationTag'] ?? 'GENERAL',
                          status: ItemStatus.pending,
                          price: drift.Value(item['price']?.toDouble() ?? 0.0),
                          updatedAtMs: drift.Value(
                            DateTime.now().millisecondsSinceEpoch,
                          ),
                        ),
                      );

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
                  },
                });
                broadcast(broadcastPayload);
              } else if (data['type'] == 'ItemBumped') {
                final itemUuid = data['itemUuid'] as String?;
                final isBumped = data['isBumped'] == true;
                if (itemUuid != null) {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await (_db!.update(
                    _db!.kDSItems,
                  )..where((t) => t.uuid.equals(itemUuid))).write(
                    KDSItemsCompanion(
                      status: drift.Value(
                        isBumped ? ItemStatus.bumped : ItemStatus.pending,
                      ),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                }
                broadcast(message);
              } else if (data['type'] == 'TicketFinished') {
                final orderUuid = data['orderUuid'] as String?;
                if (orderUuid != null) {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  // Mark all items as bumped
                  await (_db!.update(
                    _db!.kDSItems,
                  )..where((t) => t.orderUuid.equals(orderUuid))).write(
                    KDSItemsCompanion(
                      status: drift.Value(ItemStatus.bumped),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                  // Mark order as complete
                  await (_db!.update(
                    _db!.kDSOrders,
                  )..where((t) => t.uuid.equals(orderUuid))).write(
                    KDSOrdersCompanion(
                      status: drift.Value(OrderStatus.complete),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                }
                broadcast(message);
              } else if (data['type'] == 'UpdateOrder') {
                final orderData = data['order'] as Map<String, dynamic>;
                final orderUuid = orderData['uuid'] as String;
                final now = DateTime.now().millisecondsSinceEpoch;

                await (_db!.update(
                  _db!.kDSOrders,
                )..where((t) => t.uuid.equals(orderUuid))).write(
                  KDSOrdersCompanion(
                    customerName: drift.Value(
                      (orderData['customerName'] ?? 'Guest').toString(),
                    ),
                    updatedAtMs: drift.Value(now),
                  ),
                );
                // Replace items
                await (_db!.delete(
                  _db!.kDSItems,
                )..where((t) => t.orderUuid.equals(orderUuid))).go();
                for (final item in orderData['items'] as List) {
                  final itemUuid = (item['uuid'] as String?)?.isNotEmpty == true
                      ? item['uuid'] as String
                      : const Uuid().v4();
                  await _db!
                      .into(_db!.kDSItems)
                      .insert(
                        KDSItemsCompanion.insert(
                          uuid: itemUuid,
                          orderUuid: orderUuid,
                          name: item['name'] as String,
                          modifiers: List<String>.from(item['modifiers'] ?? []),
                          stationTag: (item['stationTag'] ?? 'GENERAL')
                              .toString(),
                          status: ItemStatus.pending,
                          price: drift.Value(
                            (item['price'] as num?)?.toDouble() ?? 0.0,
                          ),
                          updatedAtMs: drift.Value(now),
                        ),
                      );
                }
                broadcast(
                  jsonEncode({
                    'type': 'OrderUpdated',
                    'order': {
                      'uuid': orderUuid,
                      'customerName': orderData['customerName'] ?? 'Guest',
                      'timestamp': DateTime.now().toIso8601String(),
                      'status': OrderStatus.pending.index,
                      'items': (orderData['items'] as List)
                          .map(
                            (i) => {
                              'uuid': i['uuid'],
                              'name': i['name'],
                              'modifiers': List<String>.from(
                                i['modifiers'] ?? [],
                              ),
                              'stationTag': i['stationTag'] ?? 'GENERAL',
                              'status': ItemStatus.pending.index,
                              'price': i['price'] ?? 0,
                            },
                          )
                          .toList(),
                    },
                  }),
                );
              } else if (data['type'] == 'DeleteOrder') {
                final orderUuid = data['orderUuid'] as String?;
                if (orderUuid != null) {
                  await (_db!.delete(
                    _db!.kDSItems,
                  )..where((t) => t.orderUuid.equals(orderUuid))).go();
                  await (_db!.delete(
                    _db!.kDSOrders,
                  )..where((t) => t.uuid.equals(orderUuid))).go();
                }
                broadcast(
                  jsonEncode({'type': 'OrderDeleted', 'orderUuid': orderUuid}),
                );
              } else if (data['type'] == 'RecallOrder') {
                final orderUuid = data['orderUuid'] as String?;
                if (orderUuid != null) {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await (_db!.update(
                    _db!.kDSOrders,
                  )..where((t) => t.uuid.equals(orderUuid))).write(
                    KDSOrdersCompanion(
                      status: drift.Value(OrderStatus.pending),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                  await (_db!.update(
                    _db!.kDSItems,
                  )..where((t) => t.orderUuid.equals(orderUuid))).write(
                    KDSItemsCompanion(
                      status: drift.Value(ItemStatus.pending),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                  // Broadcast the order back as fresh for clients
                  final order = await (_db!.select(
                    _db!.kDSOrders,
                  )..where((t) => t.uuid.equals(orderUuid))).getSingleOrNull();
                  if (order != null) {
                    final items = await (_db!.select(
                      _db!.kDSItems,
                    )..where((t) => t.orderUuid.equals(orderUuid))).get();
                    broadcast(
                      jsonEncode({
                        'type': 'OrderCreated',
                        'order': {
                          'uuid': order.uuid,
                          'customerName': order.customerName,
                          'timestamp': order.timestamp.toIso8601String(),
                          'status': OrderStatus.pending.index,
                          'items': items
                              .map(
                                (i) => {
                                  'uuid': i.uuid,
                                  'name': i.name,
                                  'modifiers': i.modifiers,
                                  'stationTag': i.stationTag,
                                  'status': ItemStatus.pending.index,
                                  'price': i.price,
                                },
                              )
                              .toList(),
                        },
                      }),
                    );
                  }
                }
              } else if (data['type'] == 'SetStock') {
                final menuId = (data['id'] as num?)?.toInt();
                final quantity = (data['quantity'] as num?)?.toInt();
                if (menuId != null && quantity != null) {
                  await (_db!.update(
                    _db!.menuItems,
                  )..where((t) => t.id.equals(menuId))).write(
                    MenuItemsCompanion(
                      stockQuantity: drift.Value(quantity),
                      updatedAtMs: drift.Value(
                        DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
                  );
                }
              } else if (data['type'] == 'SaveMenu') {
                final menu = data['menu'] as Map<String, dynamic>;
                final menuId = (menu['id'] as num?)?.toInt();
                final now = DateTime.now().millisecondsSinceEpoch;
                if (menuId != null) {
                  await (_db!.update(
                    _db!.menuItems,
                  )..where((t) => t.id.equals(menuId))).write(
                    MenuItemsCompanion(
                      name: drift.Value(menu['name'] as String),
                      category: drift.Value(
                        (menu['category'] ?? 'All Items').toString(),
                      ),
                      defaultStation: drift.Value(
                        (menu['defaultStation'] ?? 'Main Station').toString(),
                      ),
                      modifiers: drift.Value(_stringList(menu['modifiers'])),
                      requiredModifiers: drift.Value(
                        _stringList(menu['requiredModifiers']),
                      ),
                      tags: drift.Value(_stringList(menu['tags'])),
                      price: drift.Value(
                        (menu['price'] as num?)?.toDouble() ?? 0.0,
                      ),
                      stockQuantity: drift.Value(
                        (menu['stockQuantity'] as num?)?.toInt() ?? 0,
                      ),
                      trackStock: drift.Value(
                        menu['trackStock'] as bool? ?? false,
                      ),
                      oneTouch: drift.Value(menu['oneTouch'] as bool? ?? false),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                } else {
                  await _db!
                      .into(_db!.menuItems)
                      .insert(
                        MenuItemsCompanion.insert(
                          guid: drift.Value(const Uuid().v4()),
                          name: menu['name'] as String,
                          category: (menu['category'] ?? 'All Items')
                              .toString(),
                          defaultStation:
                              (menu['defaultStation'] ?? 'Main Station')
                                  .toString(),
                          modifiers: _stringList(menu['modifiers']),
                          requiredModifiers: drift.Value(
                            _stringList(menu['requiredModifiers']),
                          ),
                          tags: drift.Value(_stringList(menu['tags'])),
                          price: drift.Value(
                            (menu['price'] as num?)?.toDouble() ?? 0.0,
                          ),
                          stockQuantity: drift.Value(
                            (menu['stockQuantity'] as num?)?.toInt() ?? 0,
                          ),
                          trackStock: drift.Value(
                            menu['trackStock'] as bool? ?? false,
                          ),
                          oneTouch: drift.Value(
                            menu['oneTouch'] as bool? ?? false,
                          ),
                          updatedAtMs: drift.Value(now),
                        ),
                      );
                }
              } else if (data['type'] == 'DeleteMenu') {
                final menuId = (data['id'] as num?)?.toInt();
                if (menuId != null) {
                  await (_db!.delete(
                    _db!.menuItems,
                  )..where((t) => t.id.equals(menuId))).go();
                }
              } else if (data['type'] == 'SaveStation') {
                final station = data['station'] as Map<String, dynamic>;
                final stationId = (station['id'] as num?)?.toInt();
                final name = (station['name'] ?? '').toString().trim();
                if (name.isEmpty) return;
                final now = DateTime.now().millisecondsSinceEpoch;
                if (stationId != null) {
                  await (_db!.update(
                    _db!.stations,
                  )..where((t) => t.id.equals(stationId))).write(
                    StationsCompanion(
                      name: drift.Value(name),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                } else {
                  await _db!
                      .into(_db!.stations)
                      .insert(
                        StationsCompanion.insert(
                          name: name,
                          updatedAtMs: drift.Value(now),
                        ),
                      );
                }
              } else if (data['type'] == 'DeleteStation') {
                final stationId = (data['id'] as num?)?.toInt();
                if (stationId != null) {
                  await (_db!.delete(
                    _db!.stations,
                  )..where((t) => t.id.equals(stationId))).go();
                }
              } else if (data['type'] == 'SaveModifier') {
                final mod = data['modifier'] as Map<String, dynamic>;
                final modId = (mod['id'] as num?)?.toInt();
                final name = (mod['name'] ?? '').toString().trim();
                if (name.isEmpty) return;
                final now = DateTime.now().millisecondsSinceEpoch;
                if (modId != null) {
                  await (_db!.update(
                    _db!.globalModifiers,
                  )..where((t) => t.id.equals(modId))).write(
                    GlobalModifiersCompanion(
                      name: drift.Value(name),
                      updatedAtMs: drift.Value(now),
                    ),
                  );
                } else {
                  await _db!
                      .into(_db!.globalModifiers)
                      .insert(
                        GlobalModifiersCompanion.insert(
                          name: name,
                          updatedAtMs: drift.Value(now),
                        ),
                      );
                }
              } else if (data['type'] == 'DeleteModifier') {
                final modId = (data['id'] as num?)?.toInt();
                if (modId != null) {
                  await (_db!.delete(
                    _db!.globalModifiers,
                  )..where((t) => t.id.equals(modId))).go();
                }
              } else if (data['type'] == 'BroadcastMessage') {
                final message = data['message'] ?? '';
                final station = (data['station'] as String? ?? '')
                    .trim()
                    .toUpperCase();
                final payload = jsonEncode({
                  'type': 'KitchenBroadcast',
                  'message': message,
                  if (station.isNotEmpty) 'station': station,
                });
                if (station.isNotEmpty) {
                  broadcastToStation(station, payload);
                } else {
                  broadcast(payload);
                }
              } else if (data['type'] == 'SetRushMode') {
                broadcast(
                  jsonEncode({
                    'type': 'RushModeChanged',
                    'enabled': data['enabled'] == true,
                  }),
                );
              } else if (data['type'] == 'RequestSnapshot') {
                if (isWebHost) _sendSnapshot(webSocket);
              } else if (data['type'] == 'StationChanged') {
                final idx = _clients.indexWhere((c) => c.id == clientId);
                if (idx != -1) {
                  _clients[idx].currentStation = data['station'];
                  onClientsChanged?.call();
                  _notifyWebHostDebounced();
                }
              } else if (data['type'] != 'RegisterClient' &&
                  data['type'] != 'RegisterWebHost') {
                broadcast(message);
              }
            } catch (e) {
              print('Error handling WS message: $e');
            }
          },
          onDone: () {
            if (isWebHost && clientId != null) {
              _webHostChannels.remove(clientId);
            } else if (clientId != null) {
              _clientChannels.remove(clientId);
              _clients.removeWhere((c) => c.id == clientId);
              onClientsChanged?.call();
              _notifyWebHostDebounced();
            }
          },
        );
      }),
    );

    // ── Web UI (compiled Flutter web build) ───────────────────
    router.get('/', (Request request) => _serveIndex());
    router.get(
      '/<path|.*>',
      (Request request, String path) => _serveWebFile(path),
    );

    _startDbWatchers();

    _server = await io.serve(router.call, InternetAddress.anyIPv4, port);
  }

  void setIdentity(String hostId, String role) {
    this.hostId = hostId;
    this.role = role;
  }

  Future<String> _selfHostUrl() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return 'http://${addr.address}:$_port';
        }
      }
    } catch (_) {}
    return 'http://localhost:$_port';
  }

  String? _findWebUiDir() {
    final candidates = <String>[
      ?webUiDir,
      if (_webUiDirOverride.isNotEmpty) _webUiDirOverride,
      if (Directory.current.path.isNotEmpty)
        '${Directory.current.path}${p.separator}build${p.separator}web',
      if (Platform.resolvedExecutable.isNotEmpty)
        '${p.dirname(Platform.resolvedExecutable)}${p.separator}build${p.separator}web',
    ];
    for (final candidate in candidates) {
      try {
        if (Directory(candidate).existsSync()) return candidate;
      } catch (_) {}
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<Response> _serveIndex() async {
    final dir = _findWebUiDir();
    if (dir != null) {
      final file = File(p.join(dir, 'index.html'));
      if (file.existsSync()) {
        return Response.ok(
          file.readAsBytesSync(),
          headers: {'Content-Type': 'text/html', 'Cache-Control': 'no-cache'},
        );
      }
    }
    final bundled = await _bundleAsset('index.html');
    if (bundled != null) {
      return Response.ok(
        bundled,
        headers: {'Content-Type': 'text/html', 'Cache-Control': 'no-cache'},
      );
    }
    return Response.ok(
      _webUiMissingHtml,
      headers: {'Content-Type': 'text/html'},
    );
  }

  Future<Response> _serveWebFile(String path) async {
    if (path.contains('..') || path.startsWith('/') || path.isEmpty) {
      return Response.notFound('Not found');
    }
    final dir = _findWebUiDir();
    if (dir != null) {
      final fullPath = p.normalize(p.join(dir, path));
      if (fullPath.startsWith(p.normalize(dir))) {
        final file = File(fullPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          return _webResponse(path, bytes, cacheable: true);
        }
      }
    }
    final bundled = await _bundleAsset(path);
    if (bundled != null) return _webResponse(path, bundled);
    if (path == 'index.html') return _serveIndex();
    return Response.notFound('Not found');
  }

  Map<String, List<int>>? _webBundleCache;

  Future<List<int>?> _bundleAsset(String relativePath) async {
    final bundle = await _loadWebBundle();
    if (bundle == null) return null;
    return bundle[relativePath];
  }

  // Loads the single-file web bundle (assets/webui.bin) written by
  // scripts/bundle_webui.dart and decodes it into a path -> bytes map.
  Future<Map<String, List<int>>?> _loadWebBundle() async {
    final cached = _webBundleCache;
    if (cached != null) return cached;
    final ByteData data;
    try {
      data = await rootBundle.load('assets/webui.bin');
    } catch (_) {
      return null;
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final view = ByteData.sublistView(bytes);
    var offset = 0;
    final count = view.getUint32(offset);
    offset += 4;
    final map = <String, List<int>>{};
    for (var i = 0; i < count; i++) {
      final nameLen = view.getUint16(offset);
      offset += 2;
      final name = utf8.decode(bytes.sublist(offset, offset + nameLen));
      offset += nameLen;
      final dataLen = view.getUint32(offset);
      offset += 4;
      map[name] = bytes.sublist(offset, offset + dataLen);
      offset += dataLen;
    }
    return _webBundleCache = map;
  }

  Response _webResponse(
    String path,
    List<int> bytes, {
    bool cacheable = false,
  }) {
    final ext = p.extension(path).toLowerCase();
    final mime = _webMimeTypes[ext] ?? 'application/octet-stream';
    final immutable =
        cacheable &&
        (path.startsWith('assets/') || path.startsWith('canvaskit/'));
    return Response.ok(
      bytes,
      headers: {
        'Content-Type': mime,
        'Cache-Control': immutable
            ? 'public, max-age=31536000, immutable'
            : 'no-cache',
      },
    );
  }

  Future<void> stop() async {
    _startFuture = null;
    _heartbeatTimer?.cancel();
    _webHostNotifyDebounce?.cancel();
    for (final sub in _dbWatchers) {
      sub.cancel();
    }
    _dbWatchers.clear();
    await _server?.close(force: true);
    for (var client in _clientChannels.values) {
      client.sink.close();
    }
    for (final ws in _webHostChannels.values) {
      ws.sink.close();
    }
    _clientChannels.clear();
    _webHostChannels.clear();
    _clients.clear();
  }

  void broadcast(dynamic message) {
    for (final client in _clientChannels.values) {
      client.sink.add(message);
    }
  }

  void broadcastToStation(String station, dynamic message) {
    final target = station.toUpperCase();
    for (var i = 0; i < _clients.length; i++) {
      if (_clients[i].currentStation.toUpperCase() == target) {
        _clientChannels[_clients[i].id]?.sink.add(message);
      }
    }
  }

  List<Map<String, dynamic>> get connectedClientsList => _clients
      .map(
        (c) => {
          'id': c.id,
          'deviceName': c.deviceName,
          'currentStation': c.currentStation,
        },
      )
      .toList();

  List<String> get connectedStations {
    final stations = <String>{};
    for (final c in _clients) {
      stations.add(c.currentStation.toUpperCase());
    }
    return stations.toList()..sort();
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

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<String> _fallbackStationName(String name) async {
    if (name.isNotEmpty) return name;
    final stations = await _db!.select(_db!.stations).get();
    if (stations.isNotEmpty) return stations.first.name;
    return 'Main Station';
  }

  // ── DB Watchers ─────────────────────────────────────────────

  void _startDbWatchers() {
    final db = _db!;
    void watch<T>(drift.Selectable<T> query) {
      _dbWatchers.add(query.watch().listen((_) => _notifyWebHostDebounced()));
    }

    watch(db.select(db.kDSOrders));
    watch(db.select(db.kDSItems));
    watch(db.select(db.menuItems));
    watch(db.select(db.stations));
    watch(db.select(db.globalModifiers));
  }

  void _notifyWebHostDebounced() {
    if (_webHostChannels.isEmpty) return;
    _webHostNotifyDebounce?.cancel();
    _webHostNotifyDebounce = Timer(
      const Duration(milliseconds: 150),
      () => _notifyWebHosts({'type': 'DataChanged'}),
    );
  }

  void _notifyWebHosts(Map<String, dynamic> message) {
    final text = jsonEncode(message);
    for (final ws in _webHostChannels.values) {
      try {
        ws.sink.add(text);
      } catch (_) {}
    }
  }

  // ── Host Snapshot ───────────────────────────────────────────

  Future<String> _buildHostSnapshotJson() async {
    final db = _db!;
    final orders =
        await (db.select(db.kDSOrders)
              ..orderBy([(t) => drift.OrderingTerm.desc(t.timestamp)])
              ..limit(200))
            .get();
    final allItems = await (db.select(db.kDSItems)).get();
    final itemsByOrder = <String, List<Map<String, dynamic>>>{};
    for (final i in allItems) {
      itemsByOrder.putIfAbsent(i.orderUuid, () => []).add({
        'uuid': i.uuid,
        'name': i.name,
        'modifiers': i.modifiers,
        'stationTag': i.stationTag,
        'status': i.status.index,
        'price': i.price,
      });
    }
    final menu = await db.select(db.menuItems).get();
    final stations = await db.select(db.stations).get();
    final modifiers = await db.select(db.globalModifiers).get();
    final hosts = <Map<String, String>>[
      {'hostId': hostId, 'role': role, 'url': ''},
      ...?knownPeersProvider?.call(),
    ];
    return jsonEncode({
      'type': 'HostSnapshot',
      'host': {'hostId': hostId, 'role': role},
      'orders': orders
          .map(
            (o) => {
              'uuid': o.uuid,
              'customerName': o.customerName,
              'timestamp': o.timestamp.toIso8601String(),
              'status': o.status.index,
              'items': itemsByOrder[o.uuid] ?? [],
            },
          )
          .toList(),
      'menu': menu
          .map(
            (i) => {
              'id': i.id,
              'guid': i.guid,
              'name': i.name,
              'category': i.category,
              'defaultStation': i.defaultStation,
              'modifiers': i.modifiers,
              'requiredModifiers': i.requiredModifiers,
              'tags': i.tags,
              'price': i.price,
              'stockQuantity': i.stockQuantity,
              'trackStock': i.trackStock,
              'oneTouch': i.oneTouch,
            },
          )
          .toList(),
      'stations': stations.map((s) => {'id': s.id, 'name': s.name}).toList(),
      'modifiers': modifiers.map((m) => {'id': m.id, 'name': m.name}).toList(),
      'clients': _clients
          .map(
            (c) => {
              'id': c.id,
              'deviceName': c.deviceName,
              'currentStation': c.currentStation,
              'connectedAt': c.connectedAt.toIso8601String(),
            },
          )
          .toList(),
      'hosts': hosts,
    });
  }

  void _sendSnapshot(WebSocketChannel ws) async {
    try {
      ws.sink.add(await _buildHostSnapshotJson());
    } catch (_) {}
  }

  void _broadcastFinishedOrders(
    List<KDSOrderData> orders,
    List<KDSItemData> allItems,
  ) async {
    for (final order in orders) {
      final items = allItems
          .where((i) => i.orderUuid == order.uuid)
          .map(
            (i) => {
              'uuid': i.uuid,
              'name': i.name,
              'modifiers': i.modifiers,
              'stationTag': i.stationTag,
              'status': i.status.index,
              'price': i.price,
            },
          )
          .toList();
      broadcast(
        jsonEncode({
          'type': 'ReplayFinished',
          'order': {
            'uuid': order.uuid,
            'customerName': order.customerName,
            'timestamp': order.timestamp.toIso8601String(),
            'status': order.status.index,
            'items': items,
          },
        }),
      );
    }
  }

  Future<Response> _handleSquareWebhook(Request request) async {
    try {
      final body = await _jsonBody(request);
      if (body == null) return Response.badRequest(body: 'Invalid JSON');

      // Square webhooks can be wrapped in a 'data' object
      final orderData = body['data']?['object']?['order'] ?? body['order'];
      if (orderData == null) {
        return Response.badRequest(body: 'Square Order data not found');
      }

      await _processSquareOrder(orderData);
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      print('Square Webhook Error: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<void> _processSquareOrder(Map<String, dynamic> orderData) async {
    final db = _db!;
    final orderUuid = const Uuid().v4();
    final timestamp = DateTime.now();

    // Extract customer name or use "Square Order"
    String customerName = 'Square Order';
    if (orderData['customer_id'] != null) {
      customerName =
          'SQ: ${orderData['customer_id'].toString().substring(0, 5)}';
    } else if (orderData['reference_id'] != null) {
      customerName = 'SQ: ${orderData['reference_id']}';
    }

    await db
        .into(db.kDSOrders)
        .insert(
          KDSOrderData(
            uuid: orderUuid,
            customerName: customerName,
            timestamp: timestamp,
            status: OrderStatus.pending,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    final List<Map<String, dynamic>> jsonItems = [];
    final lineItems = orderData['line_items'] as List? ?? [];

    for (final li in lineItems) {
      final itemName = li['name'] ?? 'Unknown Item';
      final itemUuid = const Uuid().v4();
      final price =
          ((li['base_price_money']?['amount'] as num?)?.toDouble() ?? 0.0) /
          100.0; // Square cents to dollars

      // Extract modifiers
      final List<String> mods = [];
      final modifiers = li['modifiers'] as List? ?? [];
      for (final m in modifiers) {
        mods.add(m['name'] ?? '');
      }

      // Smart Routing: Match with local menu to get station
      final menuMatches = await (db.select(
        db.menuItems,
      )..where((t) => t.name.equals(itemName))).get();
      String stationTag = 'GENERAL';
      if (menuMatches.isNotEmpty) {
        stationTag = menuMatches.first.defaultStation;

        // Handle stock if tracked
        if (menuMatches.first.trackStock) {
          final qty = int.tryParse(li['quantity'] ?? '1') ?? 1;
          await (db.update(
            db.menuItems,
          )..where((t) => t.id.equals(menuMatches.first.id))).write(
            MenuItemsCompanion(
              stockQuantity: drift.Value(menuMatches.first.stockQuantity - qty),
              updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
      }

      await db
          .into(db.kDSItems)
          .insert(
            KDSItemsCompanion.insert(
              uuid: itemUuid,
              orderUuid: orderUuid,
              name: itemName,
              modifiers: mods,
              stationTag: stationTag,
              status: ItemStatus.pending,
              price: drift.Value(price),
              updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );

      jsonItems.add({
        'uuid': itemUuid,
        'name': itemName,
        'modifiers': mods,
        'stationTag': stationTag,
        'status': ItemStatus.pending.index,
        'price': price,
      });
    }

    // Broadcast to all KDS clients
    broadcast(
      jsonEncode({
        'type': 'OrderCreated',
        'order': {
          'uuid': orderUuid,
          'customerName': customerName,
          'timestamp': timestamp.toIso8601String(),
          'status': OrderStatus.pending.index,
          'items': jsonItems,
        },
      }),
    );
  }
}

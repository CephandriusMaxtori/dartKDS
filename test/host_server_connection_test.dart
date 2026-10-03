import 'dart:convert';

import 'package:dartkds/models/database.dart';
import 'package:dartkds/models/order_status.dart';
import 'package:dartkds/services/host_server.dart';
import 'package:async/async.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Runs [HostServer] on an ephemeral port against an in-memory database, so the
/// registration and broadcast paths are exercised over a real socket. Port 0
/// avoids the fixed 8080 that the rest of the app assumes, which would collide
/// with a host already running on the machine.
void main() {
  late KDSDatabase db;
  late HostServer server;
  late Uri base;

  setUp(() async {
    db = KDSDatabase.forTesting(NativeDatabase.memory());
    server = HostServer();
    await server.start(db, port: 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.stop();
    await db.close();
  });

  /// Connects a socket, registers it, and hands back the inbox so a test can
  /// assert on what the client would actually receive.
  Future<({WebSocketChannel channel, StreamQueue<Map<String, dynamic>> inbox})>
  registerClient(
    String id, {
    String station = 'GENERAL',
  }) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
    );
    addTearDown(() async {
      try {
        await channel.sink.close();
      } catch (_) {
        // Already gone.
      }
    });
    await channel.ready;
    channel.sink.add(
      jsonEncode({
        'type': 'RegisterClient',
        'id': id,
        'deviceName': 'Test $id',
        'station': station,
      }),
    );
    // Decoded here rather than in the assertions so tests read against the same
    // shape the app does, and a malformed frame fails one test rather than every
    // one that happens to be running.
    final inbox = StreamQueue<Map<String, dynamic>>(
      channel.stream.map((raw) {
        final decoded = jsonDecode(raw as String);
        expect(decoded, isA<Map<String, dynamic>>());
        return decoded as Map<String, dynamic>;
      }),
    );
    await waitFor(
      () => server.connectedClients.any((c) => c.id == id),
      reason: '$id to be registered',
    );
    return (channel: channel, inbox: inbox);
  }

  /// Reads frames until [predicate] matches, so a test is not coupled to how
  /// many incidental frames the host sends first (order replay, heartbeats).
  Future<Map<String, dynamic>> nextWhere(
    StreamQueue<Map<String, dynamic>> inbox,
    bool Function(Map<String, dynamic> frame) predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final frame = await inbox.next.timeout(
        deadline.difference(DateTime.now()),
        onTimeout: () => fail('Timed out waiting for a matching frame'),
      );
      if (predicate(frame)) return frame;
    }
    fail('Timed out waiting for a matching frame');
  }

  /// Asserts nothing arrives within [window]. Used to prove a message was not
  /// delivered, where the absence is the whole point.
  Future<void> expectQuiet(
    StreamQueue<Map<String, dynamic>> inbox, {
    Duration window = const Duration(milliseconds: 300),
    String reason = 'no further frames',
  }) async {
    final remaining = await inbox.hasNext.timeout(
      window,
      onTimeout: () => false,
    );
    expect(remaining, isFalse, reason: reason);
  }

  test('reports the port it actually bound', () {
    // Everything else in this file derives its URL from this, so a server that
    // reported the requested port rather than the bound one would silently send
    // the tests at a dead address.
    expect(server.port, greaterThan(0));
    expect(server.isRunning, isTrue);
  });

  test('a registered client appears in the roster', () async {
    await registerClient('client-a', station: 'GRILL');

    final client = server.connectedClients.firstWhere((c) => c.id == 'client-a');
    expect(client.currentStation, 'GRILL');
    expect(client.deviceName, 'Test client-a');
  });

  test('broadcast reaches every registered client', () async {
    final a = (await registerClient('client-a')).inbox;
    final b = (await registerClient('client-b')).inbox;

    server.broadcast(jsonEncode({'type': 'KitchenBroadcast', 'message': 'hi'}));

    expect(
      (await nextWhere(a, (f) => f['message'] == 'hi'))['message'],
      'hi',
      reason: 'first client received the broadcast',
    );
    expect(
      (await nextWhere(b, (f) => f['message'] == 'hi'))['message'],
      'hi',
      reason: 'second client received the broadcast',
    );
  });

  test('a closed client does not stop the broadcast reaching the others', () async {
    final a = (await registerClient('client-a')).inbox;
    await registerClient('client-b');
    final c = (await registerClient('client-c')).inbox;

    // Kill one socket server-side, leaving the roster entry in place. Writing to
    // it then throws, and that throw used to escape the loop and cut delivery to
    // every client after it in the map.
    server.debugCloseClientSocket('client-b');

    server.broadcast(jsonEncode({'type': 'KitchenBroadcast', 'message': 'ping'}));

    expect(
      await nextWhere(a, (f) => f['message'] == 'ping'),
      isNotEmpty,
      reason: 'the client before the dead one still received the broadcast',
    );
    expect(
      await nextWhere(c, (f) => f['message'] == 'ping'),
      isNotEmpty,
      reason: 'the client after the dead one still received the broadcast',
    );
  });

  test('a dead client is dropped from the roster after a failed write', () async {
    await registerClient('client-a');
    await registerClient('client-dead');

    server.debugCloseClientSocket('client-dead');
    server.broadcast(jsonEncode({'type': 'KitchenBroadcast', 'message': 'ping'}));

    // Evicted rather than retried on every future order, which would keep
    // throwing once per ticket for the life of the host.
    await waitFor(
      () => !server.connectedClients.any((c) => c.id == 'client-dead'),
      reason: 'the dead client to be evicted',
    );
    expect(server.connectedClients.map((c) => c.id), contains('client-a'));
  });

  test('station routing only reaches that station', () async {
    final grill = (await registerClient('client-grill', station: 'GRILL')).inbox;
    final expo = (await registerClient('client-expo', station: 'EXPO')).inbox;

    server.broadcastToStation('GRILL', jsonEncode({'type': 'RushModeChanged'}));

    expect(
      await nextWhere(grill, (f) => f['type'] == 'RushModeChanged'),
      isNotEmpty,
      reason: 'the addressed station got the message',
    );
    await expectQuiet(
      expo,
      reason: 'a station addressed message must not leak to other stations',
    );
  });

  test('a registered client answers the liveness probe', () async {
    // Reusing `registerClient`'s socket matters: registering the same id from a
    // second socket replaces the first, so a probe sent from a different
    // connection would be testing the wrong link.
    final link = await registerClient('client-probe');

    // The probe has to go out over the same socket: registering the same id from
    // a second connection replaces the first, so a probe from elsewhere would be
    // testing the wrong link.
    link.channel.sink.add(jsonEncode({'type': 'ping'}));

    // Without this reply the display is eventually swept off the roster even
    // though it is connected and listening.
    expect(await nextWhere(link.inbox, (f) => f['type'] == 'pong'), isNotEmpty);
  });

  test('a silent client is evicted from the roster', () async {
    await registerClient('client-silent');
    expect(server.connectedClients.map((c) => c.id), contains('client-silent'));

    // A tablet that died without sending a close frame — the common case on
    // Wi-Fi — used to stay on the roster for the life of the host, so station
    // routing kept aiming at a socket nobody was reading and the settings screen
    // claimed a display was connected when it was not.
    server.debugMarkClientStale('client-silent');
    server.debugForceEvictSilentClients();

    expect(
      server.connectedClients.map((c) => c.id),
      isNot(contains('client-silent')),
      reason: 'a client that stopped answering is dropped',
    );
  });

  test('a client that keeps answering is left alone by the sweep', () async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
    );
    addTearDown(() async {
      try {
        await channel.sink.close();
      } catch (_) {
        // Already closed by the test.
      }
    });
    await channel.ready;
    channel.sink.add(
      jsonEncode({
        'type': 'RegisterClient',
        'id': 'client-chatty',
        'deviceName': 'Test client-chatty',
        'station': 'GENERAL',
      }),
    );
    await waitFor(
      () => server.connectedClients.any((c) => c.id == 'client-chatty'),
      reason: 'client-chatty to register',
    );

    server.debugMarkClientStale('client-chatty');
    // Fresh traffic puts it back in the good graces before the sweep runs.
    channel.sink.add(jsonEncode({'type': 'pong'}));
    await pumpEventQueue();
    server.debugForceEvictSilentClients();

    expect(
      server.connectedClients.map((c) => c.id),
      contains('client-chatty'),
      reason: 'the sweep must not evict a client that is actually talking',
    );
  });

  test('orders submitted over HTTP reach the kitchen', () async {
    await registerClient('client-a');

    await db.into(db.menuItems).insert(
          MenuItemsCompanion.insert(
            guid: const Value('guid-burger'),
            name: 'Burger',
            category: 'Mains',
            defaultStation: 'GRILL',
            modifiers: const [],
            updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await db.into(db.stations).insert(
          StationsCompanion.insert(name: 'GRILL'),
        );

    final response = await http.post(
      base.replace(path: '/api/menu'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': 'Fries',
        'defaultStation': 'GRILL',
        'trackStock': true,
        'stockQuantity': 3,
      }),
    );
    expect(response.statusCode, 200);

    // The roster endpoint is a cheap end-to-end check that the write landed.
    final menu = await http.get(base.replace(path: '/api/menu'));
    expect(menu.statusCode, 200);
    final decoded = jsonDecode(menu.body) as List<dynamic>;
    expect(
      decoded.map((e) => (e as Map)['name']),
      containsAll(['Burger', 'Fries']),
    );
  });

  test('a completed order is not replayed to a newly connected client', () async {
    // A real v4 uuid: drift validates the column, and the replay assertions care
    // about which order came back rather than about the id being a stand-in.
    const doneUuid = '11111111-2222-4333-8444-555555555555';
    await db.into(db.kDSOrders).insert(
          KDSOrderData(
            uuid: doneUuid,
            customerName: 'Guest',
            timestamp: DateTime.now(),
            status: OrderStatus.complete,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    final inbox = (await registerClient('client-late')).inbox;

    // Registration replays active orders and recent finishes. The finished order
    // comes back as ReplayFinished, never as a fresh open ticket that would put
    // already-served food back on the pass.
    final frame = await nextWhere(inbox, (f) => f['type'] == 'ReplayFinished');
    final order = frame['order'] as Map<String, dynamic>;
    expect(order['uuid'], doneUuid);
    await expectQuiet(
      inbox,
      reason: 'a finished order must not also arrive as an open ticket',
    );
  });

  group('Square webhook ingestion', () {
    /// Posts a Square-shaped payload and returns the response.
    Future<http.Response> postSquare(Map<String, dynamic> order) async {
      return http.post(
        base.replace(path: '/api/webhooks/square'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'sq-1', 'order': order}),
      );
    }

    Map<String, dynamic> squareOrder({
      String customerId = 'cust-1234567890',
      String referenceId = 'TILL-1',
      List<Map<String, dynamic>> lineItems = const [
        {'name': 'Burger', 'quantity': '1', 'base_price_money': {'amount': 950}},
      ],
    }) =>
        {
          'id': 'sq-1',
          'customer_id': customerId,
          'reference_id': referenceId,
          'line_items': lineItems,
        };

    test('a webhook creates an order the kitchen can see', () async {
      final response = await postSquare(squareOrder());
      expect(response.statusCode, 200);

      final orders = await db.select(db.kDSOrders).get();
      expect(orders, hasLength(1));
      expect(orders.single.customerName, 'SQ: TILL-1');
      final items = await db.select(db.kDSItems).get();
      expect(items, hasLength(1));
      expect(items.single.name, 'Burger');
      expect(items.single.price, 9.5);
    });

    test('a short customer id is accepted rather than throwing', () async {
      // `substring(0, 5)` used to throw a RangeError here, which became a 500
      // and made Square retry the same payload forever. No reference id, so the
      // customer id is what the label is built from.
      final response = await postSquare(
        squareOrder(customerId: 'abc', referenceId: ''),
      );
      expect(response.statusCode, 200);
      expect(
        (await db.select(db.kDSOrders).get()).single.customerName,
        'SQ: abc',
      );
    });

    test('a long customer id is truncated for the label', () async {
      final response = await postSquare(
        squareOrder(customerId: 'cust-1234567890', referenceId: ''),
      );
      expect(response.statusCode, 200);
      expect(
        (await db.select(db.kDSOrders).get()).single.customerName,
        'SQ: cust-',
      );
    });

    test('a numeric quantity is accepted', () async {
      final response = await postSquare(
        squareOrder(
          lineItems: [
            {
              'name': 'Burger',
              'quantity': 3,
              'base_price_money': {'amount': 950},
            },
          ],
        ),
      );
      expect(response.statusCode, 200);
      // One kitchen line per unit, matching the native intake path.
      expect(await db.select(db.kDSItems).get(), hasLength(3));
    });

    test('overselling clamps tracked stock at zero', () async {
      await db.into(db.menuItems).insert(
            MenuItemsCompanion.insert(
              guid: const Value('guid-burger'),
              name: 'Burger',
              category: 'Mains',
              defaultStation: 'GRILL',
              modifiers: const [],
              trackStock: const Value(true),
              stockQuantity: const Value(1),
              updatedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );

      final response = await postSquare(
        squareOrder(
          lineItems: [
            {
              'name': 'Burger',
              'quantity': '5',
              'base_price_money': {'amount': 950},
            },
          ],
        ),
      );
      expect(response.statusCode, 200);

      final item = await db.select(db.menuItems).getSingle();
      expect(
        item.stockQuantity,
        0,
        reason: 'stock must not go negative and corrupt the low-stock view',
      );
    });

    test('a redelivered webhook does not duplicate the ticket', () async {
      expect((await postSquare(squareOrder())).statusCode, 200);
      // Square retries on any non-2xx, so the same payload can arrive twice.
      expect((await postSquare(squareOrder())).statusCode, 200);

      expect(
        await db.select(db.kDSOrders).get(),
        hasLength(1),
        reason: 'a retry must not fire a second copy at the kitchen',
      );
      expect(await db.select(db.kDSItems).get(), hasLength(1));
    });
  });
}

/// Waits until [predicate] holds or the test times out. Server activity is
/// driven by sockets and timers, so nothing is observable on the same turn it
/// was triggered.
Future<void> waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $reason');
}

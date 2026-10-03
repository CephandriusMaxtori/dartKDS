import 'dart:async';
import 'dart:convert';

import 'package:dartkds/models/database.dart';
import 'package:dartkds/models/order_status.dart';
import 'package:dartkds/services/host_server.dart';
import 'package:async/async.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Focuses on the LAN address ranking the host advertises.
///
/// This decides the URL a display is told to connect to and the address in the
/// pairing QR code, so a bad ordering sends every kitchen tablet at an interface
/// they cannot reach.
void main() {
  group('LAN address ranking', () {
    /// The ranks for [ips], in the order `sort` would put them. Comparing the
    /// ranks rather than the addresses keeps the assertions about ordering.
    List<int> rank(List<String> ips) =>
        ips.map(HostServer.rankLanAddress).toList()..sort();

    test('prefers 192.168.x over other ranges', () {
      expect(
        rank(['10.0.0.5', '192.168.1.50']),
        [0, 1],
        reason: '192.168 is the most common kitchen router range',
      );
    });

    test('orders the private ranges deterministically', () {
      expect(rank(['192.168.1.1', '10.0.0.1', '172.16.0.1']), [0, 1, 2]);
    });

    test('only treats 172.16-172.31 as private', () {
      // The old code matched any `172.` prefix, so a CGNAT or public address in
      // that space outranked the actual kitchen subnet.
      expect(
        rank(['172.32.0.1', '10.0.0.1']),
        [1, 6],
        reason: '172.32 is outside RFC 1918 and should rank last',
      );
      expect(
        rank(['172.15.0.1', '172.16.0.1']),
        [2, 6],
        reason: '172.16 is the start of the private block, 172.15 is not',
      );
    });

    test('a self-assigned address ranks last', () {
      // 169.254.x.x means DHCP failed; it is not a usable LAN address.
      expect(
        rank(['169.254.10.1', '192.168.1.1']),
        [0, 5],
      );
    });

    test('a virtual adapter range does not outrank a private subnet', () {
      expect(
        rank(['169.254.44.1', '192.168.44.10']),
        [0, 5],
        reason: 'the reachable address wins over the virtual adapter',
      );
    });

    test('ranking is a total order over mixed input', () {
      final input = [
        '169.254.1.1',
        '192.168.0.2',
        '10.1.1.1',
        '172.20.0.1',
        '8.8.8.8',
      ];
      final shuffled = [...input]..shuffle();
      final viaRank = [...shuffled]..sort(
        (a, b) => HostServer.rankLanAddress(a).compareTo(
          HostServer.rankLanAddress(b),
        ),
      );
      final first = viaRank.first;
      expect(HostServer.rankLanAddress(first), HostServer.rankLanAddress('192.168.0.2'));
    });
  });

  group('self URL', () {
    late KDSDatabase db;
    late HostServer server;

    setUp(() async {
      db = KDSDatabase.forTesting(NativeDatabase.memory());
      server = HostServer();
    });

    tearDown(() async {
      await server.stop();
      await db.close();
    });

    test('reports the bound port, not the requested one', () async {
      // Port 0 asks the OS for a free port. Echoing back the request made the
      // host advertise `http://<ip>:0`, which no display could connect to.
      await server.start(db, port: 0);

      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/hosts'),
      );
      expect(response.statusCode, 200, reason: 'the bound port must be usable');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final self = body['self'] as Map<String, dynamic>;
      expect(
        self['url'],
        contains(':${server.port}'),
        reason: 'the advertised URL must carry the real port',
      );
    });

    test('stop clears the running state so a restart is possible', () async {
      await server.start(db, port: 0);
      expect(server.isRunning, isTrue);

      await server.stop();
      expect(server.isRunning, isFalse, reason: 'stopped is not running');
      expect(server.port, 0);

      // The app restarts host services when the role is restored, so a stopped
      // server that still looked running was never rebound.
      await server.start(db, port: 0);
      expect(server.isRunning, isTrue);
      expect(server.port, greaterThan(0));
    });

    test('a client that drops is removed from the roster', () async {
      await server.start(db, port: 0);
      final channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );
      addTearDown(() async {
        try {
          await channel.sink.close();
        } catch (_) {
          // Already closed.
        }
      });
      await channel.ready;
      channel.sink.add(
        jsonEncode({
          'type': 'RegisterClient',
          'id': 'client-1',
          'deviceName': 'Test',
          'station': 'GENERAL',
        }),
      );
      // Listened so the socket's frames are consumed rather than buffering. Left
      // to the socket close at the end of the test; a StreamQueue.cancel on an
      // unlistened single-subscription stream tries to subscribe again and throws.
      channel.stream.listen((_) {});

      await _waitFor(
        () => server.connectedClients.any((c) => c.id == 'client-1'),
        reason: 'registration',
      );

      // A clean close has to clear the roster. Previously an unregistered or
      // already-replaced socket could be left behind.
      await channel.sink.close();

      await _waitFor(
        () => server.connectedClients.isEmpty,
        reason: 'the dropped client to leave the roster',
      );
    });

    test('reconnecting under the same id replaces the old socket', () async {
      await server.start(db, port: 0);

      final first = await _connectClient(server, 'client-dup');
      expect(server.connectedClients, hasLength(1));

      // A display that reconnects after a network blip reuses its stored id.
      final second = await _connectClient(server, 'client-dup');
      await _waitFor(
        () => server.connectedClients.length == 1,
        reason: 'exactly one roster entry per id',
      );

      // The first socket's close now arrives, after the second has taken the id
      // over. Evicting on id alone would drop the live connection and leave the
      // display unregistered, silently off the pass.
      await first.channel.sink.close();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        server.connectedClients.map((c) => c.id),
        ['client-dup'],
        reason: "a stale close must not evict the display's new socket",
      );

      server.broadcast(jsonEncode({'type': 'KitchenBroadcast', 'message': 'ping'}));
      final frame = await second.inbox.next.timeout(const Duration(seconds: 5));
      expect(frame['message'], 'ping', reason: 'the live socket still receives');
    });

    test('an order submitted over the socket reaches the database', () async {
      await server.start(db, port: 0);
      final link = await _connectClient(server, 'client-order');
      addTearDown(link.inbox.cancel);

      link.channel.sink.add(
        jsonEncode({
          'type': 'CreateOrder',
          'order': {
            'customerName': 'Table 4',
            'items': [
              {
                'name': 'Burger',
                'modifiers': ['No Onion'],
                'stationTag': 'GRILL',
                'price': 9.5,
              },
            ],
          },
        }),
      );

      await _waitFor(
        () async => (await db.select(db.kDSOrders).get()).isNotEmpty,
        reason: 'the order to be written',
      );

      final orders = await db.select(db.kDSOrders).get();
      expect(orders.single.customerName, 'Table 4');
      expect(orders.single.status, OrderStatus.pending);
      final items = await db.select(db.kDSItems).get();
      expect(items.single.name, 'Burger');
      expect(items.single.modifiers, ['No Onion']);
    });
  });
}

Future<({WebSocketChannel channel, StreamQueue<Map<String, dynamic>> inbox})>
_connectClient(HostServer server, String id) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:${server.port}/ws'),
  );
  await channel.ready;
  channel.sink.add(
    jsonEncode({
      'type': 'RegisterClient',
      'id': id,
      'deviceName': 'Test $id',
      'station': 'GENERAL',
    }),
  );
  final inbox = StreamQueue<Map<String, dynamic>>(
    channel.stream.map((raw) => jsonDecode(raw as String) as Map<String, dynamic>),
  );
  await _waitFor(
    () => server.connectedClients.any((c) => c.id == id),
    reason: '$id to register',
  );
  return (channel: channel, inbox: inbox);
}

/// Waits for a synchronous or asynchronous [predicate] to hold.
Future<void> _waitFor(
  FutureOr<bool> Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $reason');
}

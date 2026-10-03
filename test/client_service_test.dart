import 'dart:async';
import 'dart:io';

import 'package:dartkds/services/client_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [ClientService] against a real local WebSocket echo server, so the
/// reconnect and liveness logic is exercised over an actual socket rather than a
/// stand-in.
void main() {
  late _EchoServer server;
  late ClientService client;

  setUp(() async {
    server = await _EchoServer.start();
    client = ClientService();
  });

  tearDown(() async {
    client.dispose();
    await server.stop();
  });

  test('connects and reports connected only once the socket is open', () async {
    expect(client.isConnected, isFalse);
    expect(client.status, ClientConnectionStatus.disconnected);

    await client.connect(server.host, server.port);

    expect(client.isConnected, isTrue);
    expect(client.status, ClientConnectionStatus.connected);
  });

  test('frames from the host reach the stream', () async {
    final frames = <dynamic>[];
    client.stream.listen(frames.add);

    await client.connect(server.host, server.port);
    client.send({'type': 'RegisterClient', 'id': 'a'});

    // The server echoes back, proving a round trip in both directions.
    await _waitFor(() => frames.isNotEmpty, reason: 'a frame to arrive');
    expect(frames.first, isA<String>());
  });

  test('the stream survives a reconnect without resubscribing', () async {
    final frames = <dynamic>[];
    client.stream.listen(frames.add);

    await client.connect(server.host, server.port);
    client.send({'type': 'first'});
    await _waitFor(() => frames.isNotEmpty, reason: 'a frame before the drop');

    // The subscription installed above must survive the drop. Previously the
    // stream came straight off `_channel`, so every reconnect handed out a
    // different stream and anything holding the old one went deaf.
    await server.dropConnections();
    // Both transitions are awaited in order. Checking only for `isConnected`
    // would pass instantly, while the client still believed it was up and the
    // close had not been processed, and the frame sent next would go into a
    // dying socket and be dropped.
    await _waitFor(
      () => !client.isConnected,
      reason: 'the drop to be noticed',
    );
    await _waitFor(
      () => client.isConnected,
      timeout: const Duration(seconds: 20),
      reason: 'the client to reconnect on its own',
    );

    client.send({'type': 'after-reconnect'});
    await _waitFor(
      () => frames.length >= 2,
      timeout: const Duration(seconds: 10),
      reason: 'a frame after the reconnect',
    );
    expect(frames.length, greaterThanOrEqualTo(2));
  });

  test('reconnect backs off rather than hammering an unreachable host', () async {
    // Port 1 on loopback refuses immediately, so the first attempt fails and the
    // service has to take over from there. The initial attempt throws so a
    // caller that has never reached a host can fall back to discovery.
    var threw = false;
    try {
      await client.connect(server.host, 1);
    } catch (_) {
      threw = true;
    }
    expect(threw, isTrue, reason: 'the first attempt reports failure to its caller');

    expect(client.isConnected, isFalse);
    // In `connecting`, not `disconnected`: a retry is already scheduled. The
    // display pointed at a host that is merely down has to keep trying on its
    // own, or it only reconnects if something else happens to poke it.
    expect(client.status, ClientConnectionStatus.connecting);
  });

  test('a host that comes back is picked up without the caller retrying', () async {
    // Nothing re-issues `connect` after this point; the internal backoff has to
    // find the host on its own.
    final port = server.port;
    await server.stop();

    var threw = false;
    try {
      await client.connect(server.host, port);
    } catch (_) {
      threw = true;
    }
    expect(threw, isTrue);

    final restarted = await _EchoServer.start(port: port);
    addTearDown(restarted.stop);

    await _waitFor(
      () => client.isConnected,
      timeout: const Duration(seconds: 30),
      reason: 'the client to find the host again',
    );
  });

  test('a link that goes quiet is torn down and redialled', () async {
    // Production waits 75s for two missed host pings; shortened so the watchdog
    // is reachable inside a test.
    client.staleAfter = const Duration(milliseconds: 200);

    await client.connect(server.host, server.port);
    expect(client.isConnected, isTrue);

    // Stop answering without closing, which is what a Wi-Fi drop looks like: the
    // socket stays open and nothing arrives. Without a liveness check the display
    // shows "connected" while receiving nothing, and a chef sees a stale board.
    await server.goSilent();

    await _waitFor(
      () => !client.isConnected,
      timeout: const Duration(seconds: 15),
      reason: 'the silent link to be torn down',
    );
    // And it comes back on its own.
    await _waitFor(
      () => client.isConnected,
      timeout: const Duration(seconds: 20),
      reason: 'the link to be re-established',
    );
  });

  test('a busy link is left alone by the watchdog', () async {
    client.staleAfter = const Duration(milliseconds: 300);

    await client.connect(server.host, server.port);
    // Keep traffic flowing for longer than the threshold. A socket that is busy
    // must not be mistaken for a dead one.
    final keepalive = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => client.send({'type': 'keepalive'}),
    );
    addTearDown(keepalive.cancel);

    // Several watchdog intervals, so the check runs repeatedly rather than once.
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(client.isConnected, isTrue);
  });

  test('disconnect stops the service from reconnecting', () async {
    await client.connect(server.host, server.port);
    await client.disconnect();

    expect(client.isConnected, isFalse);
    expect(client.status, ClientConnectionStatus.disconnected);

    // No reconnect is pending, so this stays disconnected.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(client.isConnected, isFalse);
  });

  test('send is a no-op while disconnected rather than throwing', () async {
    // The kitchen taps bump on a display whose link just dropped; that has to be
    // survivable.
    expect(() => client.send({'type': 'ItemBumped'}), returnsNormally);
  });

  test('connect rejects an empty host', () async {
    await expectLater(
      client.connect('   ', 8080),
      throwsArgumentError,
    );
  });

  test('statusStream replays the current status to a late subscriber', () async {
    await client.connect(server.host, server.port);

    // A screen that mounts after the socket came up must not be left showing the
    // initial state.
    final seen = await client.statusStream.first;
    expect(seen, ClientConnectionStatus.connected);
  });

  test('dispose stops a pending reconnect', () async {
    await client.connect(server.host, server.port);
    await server.dropConnections();
    client.dispose();

    // Give the scheduled retry time to fire; it must not resurrect the service.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(client.isConnected, isFalse);
  });
}

/// A WebSocket server that echoes whatever it receives, with switches to drop
/// connections or go silent for the liveness tests.
class _EchoServer {
  _EchoServer._(this._server);

  /// Binds an ephemeral port unless [port] is given, which lets a test restart
  /// on the same port the client is already dialling.
  static Future<_EchoServer> start({int port = 0}) async {
    final server = _EchoServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, port),
    );
    unawaited(server._serve());
    return server;
  }

  final HttpServer _server;
  final Set<WebSocket> _sockets = {};
  bool silent = false;

  String get host => '127.0.0.1';
  int get port => _server.port;

  Future<void> _serve() async {
    await for (final request in _server) {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.listen(
        (data) {
          if (silent) return; // Goes quiet without closing the socket.
          // The client may have gone between the frame arriving and this write;
          // a test server failing there would mask whatever it was meant to show.
          try {
            socket.add('echo:$data');
          } catch (_) {
            _sockets.remove(socket);
          }
        },
        onDone: () => _sockets.remove(socket),
        onError: (_) => _sockets.remove(socket),
        cancelOnError: true,
      );
    }
  }

  /// Closes every live socket without the client having asked, reproducing a
  /// host restart or an AP reboot.
  Future<void> dropConnections() async {
    silent = false;
    for (final socket in _sockets.toList()) {
      _sockets.remove(socket);
      await socket.close();
    }
  }

  /// Stops replying but leaves the sockets open.
  Future<void> goSilent() async {
    silent = true;
  }

  Future<void> stop() async {
    await dropConnections();
    await _server.close(force: true);
  }
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('Timed out waiting for $reason');
}

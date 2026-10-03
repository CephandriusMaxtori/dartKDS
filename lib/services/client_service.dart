import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Lifecycle of a kitchen display's link to its host.
enum ClientConnectionStatus {
  /// No socket, and none being dialled.
  disconnected,

  /// A socket is being dialled, or a reconnect is already scheduled.
  connecting,

  /// The socket is open. Note this is not the same as "the host is
  /// reachable" — see [ClientService.isStale].
  connected,
}

/// Owns the kitchen display's WebSocket link to the host.
///
/// The link drops for reasons the display cannot control: the host app is
/// restarted, the AP reboots, the tablet sleeps, the access point roams the
/// client off and forgets it. A KDS that silently stops receiving tickets is
/// worse than one that admits it is reconnecting, so reconnection lives here
/// rather than in the widget tree:
///
///  * The first [connect] throws on failure so a caller that has never reached
///    the host can fall back to discovery. Every failure after that is retried
///    internally with capped exponential backoff.
///  * [isConnected] reflects the socket, not the last thing that happened to
///    work. The previous `_channel != null` stayed `true` after the host went
///    away, so the UI happily showed "connected" while receiving nothing.
///  * [stream] is stable across reconnects. Subscribers install it once and keep
///    receiving without re-subscribing per connection, which is what previously
///    leaked a subscription per reconnect attempt.
///  * A liveness watchdog tears down a socket that stopped delivering frames.
///    A dropped Wi-Fi link can leave the TCP connection open with nothing
///    flowing on it; `close` never arrives, so without this the display would
///    stay "connected" until the OS gave up hours later.
class ClientService {
  /// How often the liveness watchdog checks the last frame.
  static const Duration _watchdogInterval = Duration(seconds: 5);

  /// Silence past this means the link is gone. The host pings every 30s, so
  /// this tolerates two missed pings before giving up on a busy socket.
  ///
  /// Settable so a test can reach the watchdog without waiting 75 seconds.
  @visibleForTesting
  Duration staleAfter = const Duration(seconds: 75);

  /// Ceiling for the reconnect backoff.
  static const Duration _maxRetryDelay = Duration(seconds: 15);

  /// How long to wait for the socket handshake before treating the host as
  /// unreachable.
  static const Duration _connectTimeout = Duration(seconds: 8);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retryTimer;
  Timer? _watchdog;

  String _host = '';
  int _port = 0;
  bool _intentionalDisconnect = false;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  final _frames = StreamController<dynamic>.broadcast();
  final _statusController = StreamController<ClientConnectionStatus>.broadcast();

  ClientConnectionStatus _status = ClientConnectionStatus.disconnected;

  ClientConnectionStatus get status => _status;

  /// Live connection state. Unlike a broadcast stream this replays the current
  /// value to each new subscriber, so a widget that mounts late cannot be left
  /// showing the wrong thing.
  late final Stream<ClientConnectionStatus> statusStream =
      Stream<ClientConnectionStatus>.multi((controller) {
        controller.add(_status);
        final sub = _statusController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  /// Inbound frames from the host. Stable across reconnects — subscribe once.
  Stream<dynamic> get stream => _frames.stream;

  /// The host this display was last told about, for diagnostics and reconnect.
  String? get host => _host.isEmpty ? null : _host;
  int? get port => _port == 0 ? null : _port;

  /// True only while a socket is open. A link that has gone quiet but is not yet
  /// torn down reports `false` here as well, so callers never treat it as live.
  bool get isConnected => _status == ClientConnectionStatus.connected;

  /// Last frame received from the host, or the epoch if none ever arrived.
  DateTime get lastFrameAt => _lastFrameAt;

  void _setStatus(ClientConnectionStatus value) {
    if (_status == value || _disposed) return;
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  /// Dialls [host] and keeps the link up. Throws only if the very first attempt
  /// fails; see the class docs.
  Future<void> connect(String host, int port) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(host, 'host', 'Host must not be empty');
    }
    _intentionalDisconnect = false;
    _host = trimmed;
    _port = port;
    // A manual connect is a fresh start: drop the backoff so it is not made to
    // wait behind attempts aimed at a host the user just replaced.
    _attempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      await _open();
    } catch (_) {
      // The host is now known, so keep trying with backoff even though this
      // attempt failed. The throw is still propagated so a caller that has never
      // reached a host can fall back to discovery, but leaving the service idle
      // meant a display pointed at a host that was merely down never retried
      // unless something else poked it.
      _scheduleReconnect();
      rethrow;
    }
  }

  /// Dials again now, skipping whatever backoff was pending. Callers use this
  /// when they know the failure cause has gone away — the network came back, or
  /// the user asked to reconnect — so waiting out the remaining delay would
  /// leave the display dark for no reason.
  Future<void> reconnectNow() async {
    if (_disposed || _intentionalDisconnect || isConnected) return;
    if (_host.isEmpty || _port == 0) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempt = 0;
    try {
      await _open();
    } catch (_) {
      // Hand back to the regular backoff rather than letting the caller's
      // error handling decide, which would mean no further attempts at all.
      _scheduleReconnect();
    }
  }

  Future<void> _open() async {
    if (_disposed || _intentionalDisconnect) return;
    if (_connecting || isConnected) return;
    if (_host.isEmpty || _port == 0) return;

    _connecting = true;
    _setStatus(ClientConnectionStatus.connecting);

    // Retire the previous socket before dialling again. Its frames are stale and
    // its `onDone` must not be able to tear down the link this call is about to
    // establish.
    await _retireSocket();

    final channel = WebSocketChannel.connect(_wsUri());
    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (_) {
      _connecting = false;
      _setStatus(ClientConnectionStatus.disconnected);
      // `ready` failing does not always close the socket, and an abandoned one
      // keeps a file descriptor open on a device that may only have a handful.
      unawaited(channel.sink.close().catchError((_) {}));
      rethrow;
    }

    _connecting = false;
    _channel = channel;
    _attempt = 0;
    _lastFrameAt = DateTime.now();
    _setStatus(ClientConnectionStatus.connected);
    _startWatchdog();

    _socketSub = channel.stream.listen(
      (message) => _onFrame(channel, message),
      onError: (Object error) => _onSocketLost(channel, 'socket error: $error'),
      // `cancelOnError` guarantees `onDone` runs afterwards, so a teardown path
      // never gets skipped.
      onDone: () => _onSocketLost(channel, 'socket closed'),
      cancelOnError: true,
    );
  }

  Uri _wsUri() {
    // A page served over HTTPS is not allowed to open a plaintext socket, so
    // the web display has to upgrade to wss or the browser drops the handshake.
    final secure = Uri.base.scheme == 'https';
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: _host,
      port: _port,
      path: '/ws',
    );
  }

  void _onFrame(WebSocketChannel channel, dynamic message) {
    if (!identical(_channel, channel)) return; // Frame from a retired socket.
    _lastFrameAt = DateTime.now();
    if (!_frames.isClosed) _frames.add(message);
  }

  void _onSocketLost(WebSocketChannel channel, String reason) {
    // Identity check, not a null check: a retired socket finishing its teardown
    // must not kill the healthy link that replaced it.
    if (!identical(_channel, channel)) return;
    _channel = null;
    _watchdog?.cancel();
    _watchdog = null;
    _setStatus(ClientConnectionStatus.disconnected);
    debugPrint(
      'KDS link lost ($reason); reconnecting to ${_wsUri()} in backoff',
    );
    unawaited(_retireSocket());
    _scheduleReconnect();
  }

  /// Tears down the current socket's subscription and closes it. Safe to call
  /// when there is no socket.
  Future<void> _retireSocket() async {
    final channel = _channel;
    _channel = null;
    _watchdog?.cancel();
    _watchdog = null;
    final sub = _socketSub;
    _socketSub = null;
    try {
      await sub?.cancel();
    } catch (_) {
      // A subscription that will not cancel cleanly is still being abandoned.
    }
    try {
      await channel?.sink.close();
    } catch (_) {
      // Already gone, which is the outcome we wanted anyway.
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      if (!isConnected) return;
      if (DateTime.now().difference(_lastFrameAt) <= staleAfter) return;
      final channel = _channel;
      if (channel == null) return;
      debugPrint(
        'KDS link silent for over ${staleAfter.inSeconds}s; forcing reconnect',
      );
      _onSocketLost(channel, 'no frames from host');
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionalDisconnect) return;
    if (_retryTimer != null) return;
    _attempt++;
    final delay = Duration(
      milliseconds: (500 * _attempt).clamp(
        500,
        _maxRetryDelay.inMilliseconds,
      ),
    );
    _setStatus(ClientConnectionStatus.connecting);
    _retryTimer = Timer(delay, () async {
      _retryTimer = null;
      if (_disposed || _intentionalDisconnect) return;
      try {
        await _open();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  /// Sends a frame. Dropped while offline rather than queued: the host replays
  /// every active order with authoritative item states when this display
  /// registers, so a stale bump flushed minutes later would fight that replay
  /// instead of being corrected by it.
  void send(dynamic message) {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('KDS link down; dropped outgoing ${_describe(message)}');
      return;
    }
    try {
      channel.sink.add(message is String ? message : jsonEncode(message));
    } catch (_) {
      // The socket died between the status check and the write. onDone/onError
      // will drive the reconnect; this frame is intentionally not replayed.
      debugPrint('KDS send failed; dropped ${_describe(message)}');
    }
  }

  String _describe(dynamic message) {
    if (message is String) return 'frame';
    if (message is Map && message['type'] != null) {
      return '${message['type']} frame';
    }
    return 'frame';
  }

  /// Stops reconnecting and drops the link. The host/port are forgotten, so a
  /// later [connect] is treated as a fresh dial.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _retireSocket();
    _host = '';
    _port = 0;
    _attempt = 0;
    _setStatus(ClientConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _intentionalDisconnect = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_retireSocket());
    // Assigned rather than routed through `_setStatus`, which ignores updates
    // once disposed. Without this a disposed service kept reporting itself as
    // connected, which is exactly the sort of stale claim callers must not see.
    _status = ClientConnectionStatus.disconnected;
    _frames.close();
    _statusController.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) '../web_io_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../providers/service_providers.dart';
import 'discovery_service.dart';
import 'sync_engine.dart';

class SyncPeer {
  final String hostId;
  String address;
  int port;
  String role;
  int lastSyncMs;
  String? error;
  SyncPeer({
    required this.hostId,
    required this.address,
    required this.port,
    required this.role,
    this.lastSyncMs = 0,
    this.error,
  });
}

class SyncStatus {
  final bool isRunning;
  final List<SyncPeer> peers;
  final String? lastError;
  final DateTime? lastSyncTime;
  const SyncStatus({
    this.isRunning = false,
    this.peers = const [],
    this.lastError,
    this.lastSyncTime,
  });
}

class SyncService {
  final KDSDatabase db;
  SyncService(this.db);

  static const Duration _requestTimeout = Duration(seconds: 5);

  /// A peer that has not announced itself in this long is dropped. Peers are
  /// only ever *added* by discovery, so without expiry the map grows for the
  /// life of the process and every round keeps paying the 5s timeout for hosts
  /// that were switched off days ago.
  Duration peerExpiry = const Duration(minutes: 10);

  Timer? _pollTimer;
  bool _isRunning = false;
  String? _selfHostId;
  final Map<String, DateTime> _peerLastSeen = {};
  StreamSubscription? _discoverySub;
  final Map<String, SyncPeer> _peers = {};
  String? _lastError;
  DateTime? _lastSyncTime;
  final _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  List<SyncPeer> get peers => _peers.values.toList();
  SyncStatus get currentStatus => SyncStatus(
    isRunning: _isRunning,
    peers: _peers.values.toList(),
    lastError: _lastError,
    lastSyncTime: _lastSyncTime,
  );

  void start(String selfHostId, Stream<DiscoveredHost> discoveryStream,
      {Duration interval = const Duration(seconds: 10)}) {
    _isRunning = true;
    _selfHostId = selfHostId;

    _discoverySub?.cancel();
    _discoverySub = discoveryStream.listen((host) {
      if (host.hostId == null || host.hostId!.isEmpty || host.hostId == _selfHostId) {
        return;
      }
      if (host.role != 'primary' && host.role != 'backup') {
        return;
      }
      final peer = _peers[host.hostId!];
      final changed = peer == null;
      if (peer == null) {
        _peers[host.hostId!] = SyncPeer(
          hostId: host.hostId!,
          address: host.address,
          port: host.port,
          role: host.role ?? 'primary',
        );
      } else if (peer.address != host.address ||
          peer.port != host.port ||
          (host.role != null && host.role != peer.role)) {
        // A host that came back on a different address, or was demoted between
        // primary and backup, was previously only refreshed on address change.
        peer
          ..address = host.address
          ..port = host.port
          ..role = host.role ?? peer.role;
      }
      _peerLastSeen[host.hostId!] = DateTime.now();
      if (changed) _emitStatus();
    }, onError: (_) {});

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      _expireStalePeers();
      _syncOnce();
    });
    _emitStatus();
  }

  void _expireStalePeers() {
    if (_peerLastSeen.isEmpty) return;
    final cutoff = DateTime.now().subtract(peerExpiry);
    final expired = _peerLastSeen.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    if (expired.isEmpty) return;
    for (final id in expired) {
      _peers.remove(id);
      _peerLastSeen.remove(id);
    }
    _emitStatus();
  }

  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _discoverySub?.cancel();
    _discoverySub = null;
    _peers.clear();
    _peerLastSeen.clear();
    _selfHostId = null;
    _emitStatus();
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  /// Guards against overlapping rounds. A slow or timing-out peer can outlast the
  /// poll interval, and two rounds interleaving would apply each other's
  /// half-finished change sets and race on `peer.lastSyncMs`.
  bool _syncInFlight = false;

  Future<void> _syncOnce() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final engine = SyncEngine(db);
      for (final peer in _peers.values.toList()) {
        await _syncWithPeer(peer, engine);
      }
      _lastError = null;
    } finally {
      // Cleared even if a peer threw something unexpected, otherwise one bad
      // host would stop sync permanently instead of retrying next tick.
      _syncInFlight = false;
    }
    _lastSyncTime = DateTime.now();
    _emitStatus();
  }

  Future<void> _syncWithPeer(SyncPeer peer, SyncEngine engine) async {
    // Two clients for one exchange. Both are closed in `finally` so a timeout
    // or a reset connection cannot leak a socket every 10 seconds for the life
    // of the process — on a device that meant the peer list slowly starving the
    // host's own HTTP capacity.
    final pullClient = HttpClient();
    final pushClient = HttpClient();
    try {
      final pullUrl =
          'http://${peer.address}:${peer.port}/api/sync/changes?since=${peer.lastSyncMs}';
      final pullReq = await pullClient
          .getUrl(Uri.parse(pullUrl))
          .timeout(_requestTimeout);
      final pullResp = await pullReq.close().timeout(_requestTimeout);
      final pullBody = await pullResp.transform(utf8.decoder).join().timeout(
        _requestTimeout,
      );

      if (pullResp.statusCode == 200 && pullBody.isNotEmpty) {
        await engine.applyChanges(pullBody);
      } else if (pullResp.statusCode != 200) {
        throw HttpException(
          'Pull failed with status ${pullResp.statusCode}',
          uri: Uri.parse(pullUrl),
        );
      }

      final pushUrl = 'http://${peer.address}:${peer.port}/api/sync/apply';
      final localChanges = await engine.getChanges(peer.lastSyncMs);
      final pushReq = await pushClient
          .postUrl(Uri.parse(pushUrl))
          .timeout(_requestTimeout);
      pushReq.headers.contentType = ContentType.json;
      pushReq.write(localChanges);
      final pushResp = await pushReq.close().timeout(_requestTimeout);
      // The body has to be drained or the connection cannot be reused or
      // released cleanly.
      await pushResp.drain<void>().timeout(_requestTimeout);
      if (pushResp.statusCode != 200) {
        throw HttpException(
          'Push failed with status ${pushResp.statusCode}',
          uri: Uri.parse(pushUrl),
        );
      }

      // Only advanced on a fully successful exchange. Moving it on a partial
      // one would skip the changes that were in flight at the time.
      peer.lastSyncMs = DateTime.now().millisecondsSinceEpoch;
      peer.error = null;
    } catch (e) {
      peer.error = e.toString();
      _lastError = 'Sync with ${peer.hostId} failed: $e';
    } finally {
      pullClient.close(force: true);
      pushClient.close(force: true);
    }
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.statusStream;
});
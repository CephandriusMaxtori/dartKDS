import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../providers/app_state_providers.dart';
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

  Timer? _pollTimer;
  bool _isRunning = false;
  String? _selfHostId;
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
      if (peer == null) {
        _peers[host.hostId!] = SyncPeer(
          hostId: host.hostId!,
          address: host.address,
          port: host.port,
          role: host.role ?? 'primary',
        );
        _emitStatus();
      } else if (peer.address != host.address || peer.port != host.port) {
        peer
          ..address = host.address
          ..port = host.port
          ..role = host.role ?? peer.role;
        _emitStatus();
      }
    }, onError: (_) {});

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _syncOnce());
    _emitStatus();
  }

  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _discoverySub?.cancel();
    _discoverySub = null;
    _peers.clear();
    _selfHostId = null;
    _emitStatus();
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  Future<void> _syncOnce() async {
    final engine = SyncEngine(db);
    for (final peer in _peers.values.toList()) {
      try {
        // Pull changes from peer
        final pullClient = HttpClient();
        final pullUrl =
            'http://${peer.address}:${peer.port}/api/sync/changes?since=${peer.lastSyncMs}';
        final pullReq = await pullClient
            .getUrl(Uri.parse(pullUrl))
            .timeout(const Duration(seconds: 5));
        final pullResp = await pullReq.close().timeout(const Duration(seconds: 5));
        final pullBody = await pullResp.transform(utf8.decoder).join();
        pullClient.close(force: true);

        if (pullResp.statusCode == 200 && pullBody.isNotEmpty) {
          await engine.applyChanges(pullBody);
        }

        // Push local changes to peer
        final pushClient = HttpClient();
        final pushUrl = 'http://${peer.address}:${peer.port}/api/sync/apply';
        final localChanges = await engine.getChanges(peer.lastSyncMs);
        final pushReq = await pushClient
            .postUrl(Uri.parse(pushUrl))
            .timeout(const Duration(seconds: 5));
        pushReq.headers.contentType = ContentType.json;
        pushReq.write(localChanges);
        final pushResp = await pushReq.close().timeout(const Duration(seconds: 5));
        await pushResp.drain<void>();
        pushClient.close(force: true);

        peer.lastSyncMs = DateTime.now().millisecondsSinceEpoch;
        peer.error = null;
      } catch (e) {
        peer.error = e.toString();
      }
    }
    _lastSyncTime = DateTime.now();
    _emitStatus();
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return Stream.value(const SyncStatus());
  }
  return syncService.statusStream;
});
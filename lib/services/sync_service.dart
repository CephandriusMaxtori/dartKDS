import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../providers/app_state_providers.dart';
import '../providers/service_providers.dart';
import 'sync_engine.dart';

class SyncPeer {
  final String hostId;
  final String address;
  final int port;
  final String role;
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
  final Map<String, SyncPeer> _peers = {};
  String? _lastError;
  DateTime? _lastSyncTime;
  final _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => SyncStatus(
    isRunning: _isRunning,
    peers: _peers.values.toList(),
    lastError: _lastError,
    lastSyncTime: _lastSyncTime,
  );

  void start(String selfHostId, {Duration interval = const Duration(seconds: 10)}) {
    _isRunning = true;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _syncOnce(selfHostId));
    _emitStatus();
  }

  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _peers.clear();
    _emitStatus();
  }

  void addPeer(SyncPeer peer) {
    _peers[peer.hostId] = peer;
    _emitStatus();
  }

  void removePeer(String hostId) {
    _peers.remove(hostId);
    _emitStatus();
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  Future<void> _syncOnce(String selfHostId) async {
    final engine = SyncEngine(db);
    for (final peer in _peers.values.toList()) {
      if (peer.hostId == selfHostId) continue;
      try {
        // Pull changes from peer
        final pullUrl = 'http://${peer.address}:${peer.port}/api/sync/changes?since=${peer.lastSyncMs}';
        final pullClient = HttpClient();
        final pullReq = await pullClient.getUrl(Uri.parse(pullUrl)).timeout(const Duration(seconds: 5));
        final pullResp = await pullReq.close().timeout(const Duration(seconds: 5));
        final pullBody = await pullResp.transform(utf8.decoder).join();
        pullClient.close(force: true);

        if (pullResp.statusCode == 200 && pullBody.isNotEmpty) {
          await engine.applyChanges(pullBody);
        }

        // Push local changes to peer
        final pushUrl = 'http://${peer.address}:${peer.port}/api/sync/apply';
        final localChanges = await engine.getChanges(peer.lastSyncMs);
        final pushClient = HttpClient();
        final pushReq = await pushClient.postUrl(Uri.parse(pushUrl)).timeout(const Duration(seconds: 5));
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

final syncServiceProvider = Provider<SyncService?>((ref) {
  return null;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return Stream.value(const SyncStatus());
  }
  return syncService.statusStream;
});

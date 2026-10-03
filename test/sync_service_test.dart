import 'dart:async';

import 'package:dartkds/models/database.dart';
import 'package:dartkds/services/discovery_service.dart';
import 'package:dartkds/services/sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the parts of [SyncService] that keep multi-host state converging
/// without needing two hosts to talk to each other.
void main() {
  late KDSDatabase db;
  late SyncService sync;

  setUp(() {
    db = KDSDatabase.forTesting(NativeDatabase.memory());
    sync = SyncService(db);
    // Generous by default so only the expiry test has to think about timing;
    // 10 minutes matches production.
    sync.peerExpiry = const Duration(minutes: 10);
  });

  tearDown(() async {
    sync.dispose();
    await db.close();
  });

  /// Port 9 (discard) on loopback refuses, so each round fails fast instead of
  /// sitting out the request timeout.
  DiscoveredHost deadPeer() =>
      DiscoveredHost('127.0.0.1', 9, hostId: 'peer-a', role: 'primary');

  /// Waits for [predicate] or fails the test. Sync runs on a timer, so its
  /// outcome is not observable on the same turn it was triggered.
  Future<void> waitFor(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 5),
    String reason = 'condition',
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for $reason');
  }

  test('a peer is tracked from its first announcement', () async {
    final controller = StreamController<DiscoveredHost>();
    addTearDown(controller.close);

    sync.start(
      'self',
      controller.stream,
      interval: const Duration(milliseconds: 10),
    );
    controller.add(deadPeer());
    await pumpEventQueue();

    expect(sync.peers.map((p) => p.hostId), contains('peer-a'));
  });

  test('a peer that stops announcing is dropped from the roster', () async {
    final controller = StreamController<DiscoveredHost>();
    addTearDown(controller.close);
    // Shortened from 10 minutes so the drop is observable inside a test.
    sync.peerExpiry = const Duration(milliseconds: 40);

    sync.start(
      'self',
      controller.stream,
      interval: const Duration(milliseconds: 10),
    );
    controller.add(deadPeer());
    await pumpEventQueue();
    expect(sync.peers, isNotEmpty);

    // Discovery goes quiet with no goodbye. Peers used to be only ever added, so
    // the roster grew for the life of the process and every round kept paying
    // the request timeout for a host that was switched off.
    controller.close();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(sync.peers, isEmpty);
  });

  test('a failing peer does not advance its sync watermark', () async {
    final controller = StreamController<DiscoveredHost>();
    addTearDown(controller.close);

    sync.start(
      'self',
      controller.stream,
      interval: const Duration(milliseconds: 10),
    );
    controller.add(deadPeer());
    await pumpEventQueue();
    await waitFor(
      () => sync.peers.any((p) => p.error != null),
      reason: 'peer-a to record a failure',
    );

    final peer = sync.peers.firstWhere((p) => p.hostId == 'peer-a');
    // Moving the watermark after a failed exchange would permanently skip the
    // changes that were in flight at the time.
    expect(peer.lastSyncMs, 0);
    expect(peer.error, isNotNull);
  });

  test('one unreachable peer does not stop sync for the others', () async {
    final controller = StreamController<DiscoveredHost>();
    addTearDown(controller.close);

    sync.start(
      'self',
      controller.stream,
      interval: const Duration(milliseconds: 10),
    );
    controller.add(deadPeer());
    controller.add(
      DiscoveredHost('127.0.0.1', 9, hostId: 'peer-b', role: 'backup'),
    );
    await pumpEventQueue();
    await waitFor(
      () => sync.peers.length == 2 && sync.peers.every((p) => p.error != null),
      reason: 'both peers to record a failure',
    );

    // Both get their own error rather than the first one aborting the round.
    expect(sync.peers, hasLength(2));
  });

  test('stop clears the roster and stops polling', () async {
    final controller = StreamController<DiscoveredHost>();
    addTearDown(controller.close);

    sync.start(
      'self',
      controller.stream,
      interval: const Duration(milliseconds: 10),
    );
    controller.add(deadPeer());
    await pumpEventQueue();
    expect(sync.peers, isNotEmpty);

    sync.stop();
    expect(sync.peers, isEmpty);
    expect(sync.currentStatus.isRunning, isFalse);
  });
}

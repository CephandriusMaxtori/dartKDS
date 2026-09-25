import 'dart:convert';

import 'package:dartkds/data/remote_host_store.dart';
import 'package:dartkds/services/web_host_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the payload shape emitted by `HostServer._buildHostSnapshotJson`.
String snapshotFrame({
  int menuCount = 2,
  int stationCount = 2,
  int modifierCount = 1,
}) {
  return jsonEncode({
    'type': 'HostSnapshot',
    'host': {'hostId': 'abc', 'role': 'primary'},
    'orders': [
      {
        'uuid': 'o1',
        'customerName': 'Guest',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'status': 0,
        'isTab': true,
        'items': [
          {
            'uuid': 'i1',
            'name': 'Burger',
            'modifiers': ['No Onion'],
            'stationTag': 'GRILL',
            'status': 0,
            'price': 9.5,
          },
        ],
      },
    ],
    'menu': List.generate(menuCount, (i) => {
      'id': i + 1,
      'guid': 'g$i',
      'name': 'Item $i',
      'category': 'All Items',
      'defaultStation': 'GRILL',
      'modifiers': ['Extra'],
      'requiredModifiers': [],
      'tags': [],
      'price': 5.0,
      'stockQuantity': 10,
      'trackStock': true,
      'oneTouch': false,
    }),
    'stations': List.generate(
      stationCount,
      (i) => {'id': i + 1, 'name': 'Station $i'},
    ),
    'modifiers': List.generate(
      modifierCount,
      (i) => {'id': i + 1, 'name': 'Mod $i'},
    ),
    'analytics': [
      {'name': 'Burger', 'quantity': 2, 'revenue': 19.0, 'modifierCounts': {'No Onion': 1}},
    ],
    'clients': [
      {
        'id': 'c1',
        'deviceName': 'Grill Screen',
        'currentStation': 'GRILL',
        'connectedAt': DateTime(2026, 1, 1).toIso8601String(),
      },
    ],
    'hosts': [
      {'hostId': 'abc', 'role': 'primary', 'url': ''},
    ],
  });
}

void main() {
  test('HostSnapshotData decodes a host snapshot', () {
    final data = HostSnapshotData.fromMap(
      jsonDecode(snapshotFrame()) as Map<String, dynamic>,
    );

    expect(data.menu.length, 2);
    expect(data.menu.first.name, 'Item 0');
    expect(data.menu.first.stockQuantity, 10);
    expect(data.menu.first.trackStock, isTrue);
    expect(data.stations.map((s) => s.name), ['Station 0', 'Station 1']);
    expect(data.modifiers.single.name, 'Mod 0');
    expect(data.orders.single.uuid, 'o1');
    expect(data.itemsByOrder['o1']!.single.name, 'Burger');
    expect(data.itemsByOrder['o1']!.single.orderUuid, 'o1');
    expect(data.analytics.single.quantity, 2);
    expect(data.analytics.single.modifierCounts['No Onion'], 1);
    expect(data.clients.single.currentStation, 'GRILL');
    expect(data.hosts.single['hostId'], 'abc');
  });

  test('store serves a snapshot that arrived before the store existed', () async {
    final client = WebHostClient();
    client.handleFrame(snapshotFrame());
    await pumpEventQueue();

    final store = RemoteHostStore(client);

    expect((await store.watchStations().first).length, 2);
    expect((await store.watchMenuItems().first).length, 2);
    expect((await store.watchGlobalModifiers().first).length, 1);
    expect((await store.getMenuItems()).length, 2);
    store.dispose();
  });

  test('store serves snapshots that arrive after it subscribed', () async {
    final client = WebHostClient();
    final store = RemoteHostStore(client);

    final firstEmission = store.watchStations().first;
    client.handleFrame(snapshotFrame(stationCount: 3));
    await pumpEventQueue();

    expect((await firstEmission).length, 3);
    store.dispose();
  });

  test('repeated watch calls return the same stream instance', () {
    final client = WebHostClient();
    final store = RemoteHostStore(client);

    // StreamBuilder compares streams by identity; a fresh stream per build
    // would resubscribe forever.
    expect(identical(store.watchMenuItems(), store.watchMenuItems()), isTrue);
    expect(identical(store.watchStations(), store.watchStations()), isTrue);
    expect(
      identical(store.watchOrderItems('o1'), store.watchOrderItems('o1')),
      isTrue,
    );
    store.dispose();
  });

  test('late subscriber still gets the latest snapshot', () async {
    final client = WebHostClient();
    final store = RemoteHostStore(client);
    client.handleFrame(snapshotFrame(menuCount: 7));
    await pumpEventQueue();

    // Simulates opening the menu library after data is already flowing.
    expect((await store.watchMenuItems().first).length, 7);
    store.dispose();
  });

  test('WebHostReady does not fall through and build a blank snapshot', () {
    final client = WebHostClient();

    // `WebHostReady` used to fall into the `HostSnapshot` branch, so the client
    // cached an all-empty snapshot and any view that subscribed in that window
    // rendered an empty library.
    client.handleFrame(
      jsonEncode({
        'type': 'WebHostReady',
        'hostId': 'abc',
        'role': 'primary',
      }),
    );

    expect(client.latestSnapshot, isNull);
  });

  test('DataChanged asks the host for a fresh snapshot', () {
    final client = WebHostClient();
    final sent = <Map<String, dynamic>>[];
    client.debugSendOverride = (m) => sent.add(m);

    // Not connected yet: the host has nothing to answer with.
    client.handleFrame(jsonEncode({'type': 'DataChanged'}));
    expect(sent, isEmpty);

    client.handleFrame(
      jsonEncode({
        'type': 'WebHostReady',
        'hostId': 'abc',
        'role': 'primary',
      }),
    );
    client.handleFrame(jsonEncode({'type': 'DataChanged'}));

    expect(sent.where((m) => m['type'] == 'RequestSnapshot'), hasLength(1));
  });

  test('a malformed snapshot is reported instead of silently dropped', () {
    final client = WebHostClient();

    // `menu` is an object rather than a list, so decoding has to fail.
    client.handleFrame(
      jsonEncode({
        'type': 'HostSnapshot',
        'host': {'hostId': 'abc', 'role': 'primary'},
        'menu': {'not': 'a list'},
      }),
    );

    expect(client.latestSnapshot, isNull);
    expect(client.lastFrameError, isNotNull);
  });

  test('a host-side snapshot failure reaches the browser', () {
    final client = WebHostClient();

    client.handleFrame(
      jsonEncode({
        'type': 'SnapshotError',
        'message': 'database is locked',
      }),
    );

    expect(client.lastFrameError, contains('database is locked'));
  });
}

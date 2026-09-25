import 'dart:convert';

import 'package:dartkds/data/host_store.dart';
import 'package:dartkds/data/remote_host_store.dart';
import 'package:dartkds/providers/host_store_provider.dart';
import 'package:dartkds/services/web_host_client.dart';
import 'package:dartkds/ui/host/views/library_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String snapshotFrame() => jsonEncode({
  'type': 'HostSnapshot',
  'host': {'hostId': 'abc', 'role': 'primary'},
  'orders': [],
  'menu': [
    {
      'id': 1,
      'guid': 'g1',
      'name': 'Smash Burger',
      'category': 'Mains',
      'defaultStation': 'GRILL',
      'modifiers': ['No Onion'],
      'requiredModifiers': [],
      'tags': [],
      'price': 9.5,
      'stockQuantity': 10,
      'trackStock': true,
      'oneTouch': false,
    },
  ],
  'stations': [
    {'id': 1, 'name': 'GRILL'},
  ],
  'modifiers': [
    {'id': 1, 'name': 'Extra Cheese'},
  ],
  'analytics': [],
  'clients': [],
  'hosts': [
    {'hostId': 'abc', 'role': 'primary', 'url': ''},
  ],
});

Widget host(HostStore store) => ProviderScope(
  overrides: [hostStoreProvider.overrideWithValue(store)],
  child: const MaterialApp(
    home: Scaffold(body: LibraryView()),
  ),
);

/// Pumps a fixed number of frames.
///
/// `pumpAndSettle` is unusable here: the library form contains `TextField`s,
/// whose cursor blink animation never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    // Give the list enough room that its rows are actually built.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('menu library renders items from the store', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = WebHostClient();
    client.handleFrame(snapshotFrame());
    await tester.pump();

    await tester.pumpWidget(host(RemoteHostStore(client)));
    await settle(tester);

    expect(find.text('SMASH BURGER'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('menu library resolves the spinner when the snapshot arrives late', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = WebHostClient();
    final store = RemoteHostStore(client);

    await tester.pumpWidget(host(store));
    await settle(tester);

    // Nothing has arrived yet: the library is legitimately still loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    client.handleFrame(snapshotFrame());
    await settle(tester);

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'library stayed on a spinner after the snapshot arrived',
    );
    expect(find.text('SMASH BURGER'), findsOneWidget);
  });

  testWidgets('WebHostReady frame does not clobber a real snapshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = WebHostClient();
    // The host sends WebHostReady *before* HostSnapshot.
    client.handleFrame(
      jsonEncode({
        'type': 'WebHostReady',
        'hostId': 'abc',
        'role': 'primary',
      }),
    );
    client.handleFrame(snapshotFrame());
    await tester.pump();

    await tester.pumpWidget(host(RemoteHostStore(client)));
    await settle(tester);

    expect(find.text('SMASH BURGER'), findsOneWidget);
    expect(find.textContaining('Database Error'), findsNothing);
  });
}

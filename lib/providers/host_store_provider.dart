import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drift_host_store.dart';
import '../data/host_store.dart';
import '../data/remote_host_store.dart';
import '../models/connected_client.dart';
import '../models/database.dart';
import '../services/web_host_client.dart';
import 'service_providers.dart';

/// The single data source every host view talks to.
///
/// Native devices wrap Drift directly. The browser build gets a
/// [RemoteHostStore] bound to the [WebHostClient] bridge instead, which is why
/// `main.dart` overrides [webHostClientProvider] before the host UI is built.
final hostStoreProvider = Provider<HostStore>((ref) {
  final client = ref.watch(webHostClientProvider);
  if (client == null) {
    final store = DriftHostStore(
      db: ref.watch(databaseProvider),
      server: ref.watch(hostServerProvider),
    );
    ref.onDispose(store.dispose);
    return store;
  }
  final store = RemoteHostStore(client);
  ref.onDispose(store.dispose);
  return store;
});

/// Non-null only in the browser build. Overridden in `main.dart` for web so the
/// rest of the app can stay platform-agnostic.
final webHostClientProvider = Provider<WebHostClient?>((ref) => null);

/// Connected kitchen displays, whichever store is active.
final hostClientsProvider = StreamProvider<List<ConnectedClient>>(
  (ref) => ref.watch(hostStoreProvider).watchClients(),
);

/// Open orders, whichever store is active.
final hostOrdersProvider = StreamProvider<List<KDSOrderData>>(
  (ref) => ref.watch(hostStoreProvider).watchOrders(),
);

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/discovery_service.dart';
import '../services/host_server.dart';
import '../services/client_service.dart';
import '../services/sync_service.dart';
import '../models/database.dart';
import '../models/connected_client.dart';

final databaseProvider = Provider((ref) => KDSDatabase());

final discoveryServiceProvider = Provider((ref) => DiscoveryService());

final hostServerProvider = Provider((ref) => HostServer());

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

final connectedClientsProvider = StreamProvider<List<ConnectedClient>>((ref) {
  final server = ref.watch(hostServerProvider);
  final controller = StreamController<List<ConnectedClient>>();
  
  server.onClientsChanged = () {
    controller.add(server.connectedClients);
  };
  
  // Initial value
  controller.add(server.connectedClients);
  
  ref.onDispose(() {
    server.onClientsChanged = null;
    controller.close();
  });
  
  return controller.stream;
});

final clientServiceProvider = Provider((ref) => ClientService());

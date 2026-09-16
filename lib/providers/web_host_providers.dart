import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/web_host_client.dart';

// ── Data Models ────────────────────────────────────────────────

class WHMenuItem {
  final int id;
  final String guid, name, category, defaultStation;
  final List<String> modifiers, requiredModifiers, tags;
  final double price;
  final int stockQuantity;
  final bool trackStock;
  final bool oneTouch;

  const WHMenuItem({
    required this.id,
    required this.guid,
    required this.name,
    required this.category,
    required this.defaultStation,
    required this.modifiers,
    required this.requiredModifiers,
    required this.tags,
    required this.price,
    required this.stockQuantity,
    required this.trackStock,
    required this.oneTouch,
  });

  factory WHMenuItem.fromMap(Map<String, dynamic> m) => WHMenuItem(
        id: (m['id'] as num).toInt(),
        guid: (m['guid'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        category: (m['category'] ?? 'All Items').toString(),
        defaultStation: (m['defaultStation'] ?? 'Main Station').toString(),
        modifiers: _strList(m['modifiers']),
        requiredModifiers: _strList(m['requiredModifiers']),
        tags: _strList(m['tags']),
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (m['stockQuantity'] as num?)?.toInt() ?? 0,
        trackStock: m['trackStock'] == true,
        oneTouch: m['oneTouch'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'guid': guid,
        'name': name,
        'category': category,
        'defaultStation': defaultStation,
        'modifiers': modifiers,
        'requiredModifiers': requiredModifiers,
        'tags': tags,
        'price': price,
        'stockQuantity': stockQuantity,
        'trackStock': trackStock,
        'oneTouch': oneTouch,
      };
}

class WHOrderItem {
  final String uuid, name, stationTag;
  final List<String> modifiers;
  final int status;
  final double price;
  const WHOrderItem(
      {required this.uuid,
      required this.name,
      required this.stationTag,
      required this.modifiers,
      required this.status,
      required this.price});

  factory WHOrderItem.fromMap(Map<String, dynamic> m) => WHOrderItem(
        uuid: m['uuid'] ?? '',
        name: m['name'] ?? '',
        stationTag: m['stationTag'] ?? 'GENERAL',
        modifiers: _strList(m['modifiers']),
        status: (m['status'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'uuid': uuid,
        'name': name,
        'modifiers': modifiers,
        'stationTag': stationTag,
        'status': status,
        'price': price,
      };
}

class WHOrder {
  final String uuid, customerName;
  final DateTime timestamp;
  final int status;
  final List<WHOrderItem> items;
  const WHOrder(
      {required this.uuid,
      required this.customerName,
      required this.timestamp,
      required this.status,
      required this.items});
  factory WHOrder.fromMap(Map<String, dynamic> m) => WHOrder(
        uuid: m['uuid'] ?? '',
        customerName: m['customerName'] ?? 'Guest',
        timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
        status: (m['status'] as num?)?.toInt() ?? 0,
        items: (m['items'] as List? ?? [])
            .map((i) => WHOrderItem.fromMap(i))
            .toList(),
      );
}

class WHStation {
  final int id;
  final String name;
  const WHStation({required this.id, required this.name});
  factory WHStation.fromMap(Map<String, dynamic> m) =>
      WHStation(id: (m['id'] as num).toInt(), name: m['name'] ?? '');
}

class WHModifier {
  final int id;
  final String name;
  const WHModifier({required this.id, required this.name});
  factory WHModifier.fromMap(Map<String, dynamic> m) =>
      WHModifier(id: (m['id'] as num).toInt(), name: m['name'] ?? '');
}

class WHClient {
  final String id, deviceName, currentStation;
  const WHClient(
      {required this.id,
      required this.deviceName,
      required this.currentStation});
  factory WHClient.fromMap(Map<String, dynamic> m) => WHClient(
        id: m['id'] ?? '',
        deviceName: m['deviceName'] ?? '',
        currentStation: m['currentStation'] ?? '',
      );
}

class WHSnapshot {
  final String hostId, hostRole;
  final List<WHOrder> orders;
  final List<WHMenuItem> menu;
  final List<WHStation> stations;
  final List<WHModifier> modifiers;
  final List<WHClient> clients;

  const WHSnapshot({
    required this.hostId,
    required this.hostRole,
    required this.orders,
    required this.menu,
    required this.stations,
    required this.modifiers,
    required this.clients,
  });

  factory WHSnapshot.fromMap(Map<String, dynamic> m) => WHSnapshot(
        hostId: m['host']?['hostId'] ?? '',
        hostRole: m['host']?['role'] ?? 'primary',
        orders: (m['orders'] as List? ?? [])
            .map((o) => WHOrder.fromMap(o))
            .toList(),
        menu: (m['menu'] as List? ?? [])
            .map((i) => WHMenuItem.fromMap(i))
            .toList(),
        stations: (m['stations'] as List? ?? [])
            .map((s) => WHStation.fromMap(s))
            .toList(),
        modifiers: (m['modifiers'] as List? ?? [])
            .map((d) => WHModifier.fromMap(d))
            .toList(),
        clients: (m['clients'] as List? ?? [])
            .map((c) => WHClient.fromMap(c))
            .toList(),
      );
}

List<String> _strList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String) {
    return v.split('|').where((s) => s.isNotEmpty).toList();
  }
  return [];
}

// ── Providers ──────────────────────────────────────────────────

final webHostBridgeProvider = Provider<WebHostClient>((ref) {
  final client = WebHostClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final webHostStatusProvider = StreamProvider<WebHostStatus>((ref) {
  return ref.watch(webHostBridgeProvider).statusStream;
});

class WebHostSnapshotNotifier extends StateNotifier<WHSnapshot?> {
  final WebHostClient _bridge;
  StreamSubscription? _sub;

  WebHostSnapshotNotifier(this._bridge) : super(null) {
    _sub = _bridge.events.listen((data) {
      final type = data['type'] as String?;
      if (type == 'HostSnapshot') {
        state = WHSnapshot.fromMap(data);
      } else if (type == 'DataChanged') {
        _bridge.requestSnapshot();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final webHostSnapshotProvider =
    StateNotifierProvider<WebHostSnapshotNotifier, WHSnapshot?>((ref) {
  final bridge = ref.watch(webHostBridgeProvider);
  final notifier = WebHostSnapshotNotifier(bridge);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// Convenience derived providers
final whMenuProvider = Provider<List<WHMenuItem>>((ref) {
  return ref.watch(webHostSnapshotProvider)?.menu ?? const [];
});
final whStationsProvider = Provider<List<WHStation>>((ref) {
  return ref.watch(webHostSnapshotProvider)?.stations ?? const [];
});
final whModifiersProvider = Provider<List<WHModifier>>((ref) {
  return ref.watch(webHostSnapshotProvider)?.modifiers ?? const [];
});
final whOrdersProvider = Provider<List<WHOrder>>((ref) {
  return ref.watch(webHostSnapshotProvider)?.orders ?? const [];
});
final whClientsProvider = Provider<List<WHClient>>((ref) {
  return ref.watch(webHostSnapshotProvider)?.clients ?? const [];
});

// WHOrder currently being edited in the intake tab (set from the sent queue).
final webHostEditOrderProvider = StateProvider<WHOrder?>((ref) => null);

// Host tab index for the web host UI (mirrors hostTabIndexProvider).
final webHostTabIndexProvider = StateProvider<int>((ref) => 0);

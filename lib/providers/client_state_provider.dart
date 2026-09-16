import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_status.dart';
import '../models/item_status.dart';
import 'app_state_providers.dart';

class ClientOrder {
  final String uuid;
  final String customerName;
  final DateTime timestamp;
  final OrderStatus status;
  final List<ClientItem> items;

  ClientOrder({
    required this.uuid,
    required this.customerName,
    required this.timestamp,
    required this.status,
    required this.items,
  });

  ClientOrder copyWith({List<ClientItem>? items}) {
    return ClientOrder(
      uuid: uuid,
      customerName: customerName,
      timestamp: timestamp,
      status: status,
      items: items ?? this.items,
    );
  }
}

class ClientItem {
  final String uuid;
  final String name;
  final List<String> modifiers;
  final String stationTag;
  bool isBumped;

  ClientItem({
    required this.uuid,
    required this.name,
    required this.modifiers,
    required this.stationTag,
    this.isBumped = false,
  });
}

class ClientStateNotifier extends StateNotifier<List<ClientOrder>> {
  ClientStateNotifier() : super([]);

  ClientOrder? handleEvent(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      if (data['type'] == 'ItemBumped') {
        setItemBumped(
          data['orderUuid'],
          data['itemUuid'],
          data['isBumped'] == true,
        );
        return null;
      }
      if (data['type'] == 'TicketFinished') {
        return removeOrder(data['orderUuid']);
      }
      if (data['type'] == 'OrderDeleted') {
        final uuid = data['orderUuid'] as String?;
        if (uuid != null) removeOrder(uuid);
        return null;
      }
      if (data['type'] == 'OrderCreated' || data['type'] == 'OrderUpdated') {
        final orderData = data['order'];
        final isUpdate = data['type'] == 'OrderUpdated';

        final newOrder = ClientOrder(
          uuid: orderData['uuid'],
          customerName: orderData['customerName'],
          timestamp: DateTime.parse(orderData['timestamp']),
          status: OrderStatus.values[orderData['status']],
          items: (orderData['items'] as List)
              .map(
                (i) => ClientItem(
                  uuid: i['uuid'],
                  name: i['name'],
                  modifiers: List<String>.from(i['modifiers']),
                  stationTag: i['stationTag'],
                  isBumped:
                      (i['status'] as int?) == ItemStatus.bumped.index,
                ),
              )
              .toList(),
        );

        if (isUpdate) {
          state = [
            for (final o in state)
              if (o.uuid == newOrder.uuid) newOrder else o,
          ];
          // If the order wasn't in state (maybe it was cleared but then updated), add it.
          if (!state.any((o) => o.uuid == newOrder.uuid)) {
            state = [...state, newOrder];
          }
        } else {
          // SAFEGUARD: Check if order already exists (prevents duplicate recalls)
          final exists = state.any((o) => o.uuid == newOrder.uuid);
          if (exists) {
            // Treat as update
            state = [
              for (final o in state)
                if (o.uuid == newOrder.uuid) newOrder else o,
            ];
          } else {
            state = [...state, newOrder];
          }
        }
      }
      return null;
    } catch (e) {
      print('Error parsing client event: $e');
      return null;
    }
  }

  void toggleItemBump(String orderUuid, String itemUuid) {
    state = [
      for (final order in state)
        if (order.uuid == orderUuid)
          order.copyWith(
            items: [
              for (final item in order.items)
                if (item.uuid == itemUuid)
                  ClientItem(
                    uuid: item.uuid,
                    name: item.name,
                    modifiers: item.modifiers,
                    stationTag: item.stationTag,
                    isBumped: !item.isBumped,
                  )
                else
                  item,
            ],
          )
        else
          order,
    ];
  }

  void setItemBumped(String orderUuid, String itemUuid, bool value) {
    state = [
      for (final order in state)
        if (order.uuid == orderUuid)
          order.copyWith(
            items: [
              for (final item in order.items)
                if (item.uuid == itemUuid)
                  ClientItem(
                    uuid: item.uuid,
                    name: item.name,
                    modifiers: item.modifiers,
                    stationTag: item.stationTag,
                    isBumped: value,
                  )
                else
                  item,
            ],
          )
        else
          order,
    ];
  }

  ClientOrder? removeOrder(String orderUuid) {
    try {
      final order = state.firstWhere((o) => o.uuid == orderUuid);
      state = state.where((o) => o.uuid != orderUuid).toList();
      return order;
    } catch (_) {
      return null;
    }
  }

  void addOrder(ClientOrder order) {
    if (!state.any((o) => o.uuid == order.uuid)) {
      state = [...state, order];
    }
  }
}

class RecentBumpsNotifier extends StateNotifier<List<ClientOrder>> {
  RecentBumpsNotifier() : super([]);

  void add(ClientOrder order) {
    // Avoid duplicates in recent list
    state = [
      order,
      ...state.where((o) => o.uuid != order.uuid),
    ].take(10).toList();
  }

  void remove(String uuid) {
    state = state.where((o) => o.uuid != uuid).toList();
  }

  void clear() {
    state = [];
  }
}

final clientStateProvider =
    StateNotifierProvider<ClientStateNotifier, List<ClientOrder>>(
      (ref) => ClientStateNotifier(),
    );
final recentBumpsProvider =
    StateNotifierProvider<RecentBumpsNotifier, List<ClientOrder>>(
      (ref) => RecentBumpsNotifier(),
    );

final filteredTicketsProvider = Provider.autoDispose<List<ClientOrder>>((ref) {
  final tickets = ref.watch(clientStateProvider);
  final stationTag = ref.watch(stationTagProvider) ?? 'GENERAL';

  return tickets.where((order) {
    if (stationTag == 'GENERAL' || stationTag == 'EXPO') return true;
    return order.items.any(
      (item) => item.stationTag.toUpperCase() == stationTag.toUpperCase(),
    );
  }).toList();
});

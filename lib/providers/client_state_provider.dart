import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_status.dart';

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

  void handleEvent(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      if (data['type'] == 'ItemBumped') {
        setItemBumped(data['orderUuid'], data['itemUuid'], data['isBumped'] == true);
        return;
      }
      if (data['type'] == 'TicketFinished') {
        removeOrder(data['orderUuid']);
        return;
      }
      if (data['type'] == 'OrderCreated' || data['type'] == 'OrderUpdated') {
        final orderData = data['order'];
        final isUpdate = data['type'] == 'OrderUpdated';

        final newOrder = ClientOrder(
          uuid: orderData['uuid'],
          customerName: orderData['customerName'],
          timestamp: DateTime.parse(orderData['timestamp']),
          status: OrderStatus.values[orderData['status']],
          items: (orderData['items'] as List).map((i) => ClientItem(
            uuid: i['uuid'],
            name: i['name'],
            modifiers: List<String>.from(i['modifiers']),
            stationTag: i['stationTag'],
          )).toList(),
        );

        if (isUpdate) {
          state = [
            for (final o in state)
              if (o.uuid == newOrder.uuid) newOrder else o
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
            state = [for (final o in state) if (o.uuid == newOrder.uuid) newOrder else o];
          } else {
            state = [...state, newOrder];
          }
        }
      }
    } catch (e) {
      print('Error parsing client event: $e');
    }
  }

  void toggleItemBump(String orderUuid, String itemUuid) {
    state = [
      for (final order in state)
        if (order.uuid == orderUuid)
          order.copyWith(items: [
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
                item
          ])
        else
          order
    ];
  }

  void setItemBumped(String orderUuid, String itemUuid, bool value) {
    state = [
      for (final order in state)
        if (order.uuid == orderUuid)
          order.copyWith(items: [
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
                item
          ])
        else
          order
    ];
  }

  void removeOrder(String orderUuid) {
    state = state.where((o) => orderUuid != o.uuid).toList();
  }
}

final clientStateProvider = StateNotifierProvider<ClientStateNotifier, List<ClientOrder>>((ref) => ClientStateNotifier());

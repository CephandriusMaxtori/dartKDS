import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../models/database.dart';
import '../../../models/item_status.dart';
import '../../../providers/app_state_providers.dart';
import '../../../providers/intake_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_provider.dart';

class SentQueueView extends ConsumerWidget {
  const SentQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider);
    final server = ref.watch(hostServerProvider);
    final timeFormat = settings.use24HourFormat ? 'HH:mm' : 'h:mm a';

    return StreamBuilder<List<KDSOrderData>>(
      stream: (db.select(db.kDSOrders)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!;

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Color(0xFFE5E7EB)),
                SizedBox(height: 16),
                Text('No Orders Sent Yet', style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.uuid.substring(0, 4).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Text(
                              DateFormat(timeFormat).format(order.timestamp),
                              style: const TextStyle(color: Color(0xFF6B7280), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _editOrder(context, ref, db, order),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111111).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EDIT',
                                  style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _recallOrder(context, db, server, order),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'RECALL',
                                  style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Items summary
                    StreamBuilder<List<KDSItemData>>(
                      stream: (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(order.uuid))).watch(),
                      builder: (context, itemSnapshot) {
                        if (!itemSnapshot.hasData) return const SizedBox.shrink();
                        final items = itemSnapshot.data!;
                        final orderTotal = items.fold<double>(0, (sum, item) => sum + item.price);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...items.map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
                                      const SizedBox(width: 8),
                                      Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  Text('\$${i.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            )),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF6B7280))),
                                Text('\$${orderTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editOrder(BuildContext context, WidgetRef ref, KDSDatabase db, KDSOrderData order) async {
    final items = await (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(order.uuid))).get();
    final allMenuItems = await db.select(db.menuItems).get();

    final List<IntakeItem> intakeItems = [];
    for (final item in items) {
      final menuItem = allMenuItems.firstWhere(
        (m) => m.name == item.name,
        orElse: () => MenuItemData(
          id: -1,
          guid: '',
          name: item.name,
          category: 'History',
          defaultStation: item.stationTag,
          modifiers: [],
          price: item.price,
          requiredModifiers: [],
          tags: [],
          stockQuantity: 0,
          trackStock: false,
          updatedAtMs: 0,
        ),
      );
      intakeItems.add(IntakeItem(
        menuItem: menuItem,
        selectedModifiers: item.modifiers,
        quantity: 1,
      ));
    }

    ref.read(intakeProvider.notifier).loadOrder(order.uuid, order.customerName, intakeItems);
    ref.read(hostTabIndexProvider.notifier).state = 0; // Switch to ORDER tab

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _recallOrder(BuildContext context, KDSDatabase db, dynamic server, KDSOrderData order) async {
    HapticFeedback.mediumImpact();
    
    final items = await (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(order.uuid))).get();
    
    final List<Map<String, dynamic>> jsonItems = items.map((i) => {
      'uuid': i.uuid,
      'name': i.name,
      'modifiers': i.modifiers,
      'stationTag': i.stationTag,
      'status': ItemStatus.pending.index, // Reset to pending for the KDS
      'price': i.price,
    }).toList();

    final broadcastPayload = jsonEncode({
      'type': 'OrderCreated',
      'order': {
        'uuid': order.uuid,
        'customerName': order.customerName,
        'timestamp': order.timestamp.toIso8601String(),
        'status': order.status.index,
        'items': jsonItems,
      }
    });

    server.broadcast(broadcastPayload);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent Order #${order.uuid.substring(0, 4).toUpperCase()} back to Kitchen'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }
}

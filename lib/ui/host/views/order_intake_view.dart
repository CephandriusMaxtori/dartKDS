import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/database.dart';
import '../../../models/order_status.dart';
import '../../../models/item_status.dart';
import '../../../providers/intake_provider.dart';
import '../../../providers/service_providers.dart';

class OrderIntakeView extends ConsumerWidget {
  const OrderIntakeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final intakeState = ref.watch(intakeProvider);

    return Column(
      children: [
        // Upper Half: Menu Grid
        Expanded(
          flex: 55,
          child: StreamBuilder<List<MenuItemData>>(
            stream: db.select(db.menuItems).watch(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_add, size: 64, color: Color(0xFF6B7280)),
                      SizedBox(height: 16),
                      Text('No Items in Library', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                      Text('Go to Library tab to add items', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _handleItemTap(context, ref, item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        // Lower Half: Current Ticket
        Expanded(
          flex: 45,
          child: Container(
            color: Theme.of(context).cardTheme.color ?? Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURRENT TICKET (${intakeState.items.length})',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6B7280), fontSize: 11),
                      ),
                      if (intakeState.items.isNotEmpty)
                        GestureDetector(
                          onTap: () => ref.read(intakeProvider.notifier).clear(),
                          child: const Text('CLEAR', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: intakeState.items.length,
                    itemBuilder: (context, index) {
                      final item = intakeState.items[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(item.menuItem.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color)),
                        subtitle: item.selectedModifiers.isNotEmpty 
                          ? Text(item.selectedModifiers.join(', '), style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12))
                          : Text(item.menuItem.defaultStation, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF6B7280), size: 20),
                          onPressed: () => ref.read(intakeProvider.notifier).removeItem(index),
                        ),
                        onTap: () => _showModifierDialog(context, ref, item.menuItem, editIndex: index, initialSelected: item.selectedModifiers),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: intakeState.items.isEmpty ? const Color(0xFFE5E7EB) : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: intakeState.items.isEmpty ? null : () => _sendToKitchen(context, ref),
                      child: const Text(
                        'SEND TO KITCHEN',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleItemTap(BuildContext context, WidgetRef ref, MenuItemData item) {
    if (item.modifiers.isEmpty) {
      ref.read(intakeProvider.notifier).addItem(item);
      HapticFeedback.lightImpact();
      return;
    }

    _showModifierDialog(context, ref, item);
  }

  void _showModifierDialog(BuildContext context, WidgetRef ref, MenuItemData item, {int? editIndex, List<String>? initialSelected}) {
    List<String> selected = List.from(initialSelected ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Modifiers: ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.modifiers.map((mod) {
                final isSelected = selected.contains(mod);
                return FilterChip(
                  label: Text(mod),
                  selected: isSelected,
                  onSelected: (val) {
                    setDialogState(() {
                      if (val) {
                        selected.add(mod);
                      } else {
                        selected.remove(mod);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF2563EB),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                if (editIndex != null) {
                  ref.read(intakeProvider.notifier).updateItemModifiers(editIndex, selected);
                } else {
                  ref.read(intakeProvider.notifier).addItem(item, selectedModifiers: selected);
                }
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: Text(editIndex != null ? 'UPDATE' : 'ADD TO TICKET'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToKitchen(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final state = ref.read(intakeProvider);
    final db = ref.read(databaseProvider);
    final server = ref.read(hostServerProvider);
    
    final orderUuid = const Uuid().v4();
    final timestamp = DateTime.now();

    await db.into(db.kDSOrders).insert(KDSOrderData(
      uuid: orderUuid,
      customerName: state.customerName.isEmpty ? 'Guest' : state.customerName,
      timestamp: timestamp,
      status: OrderStatus.pending,
    ));

    final List<Map<String, dynamic>> jsonItems = [];

    for (final item in state.items) {
      final itemUuid = const Uuid().v4();
      await db.into(db.kDSItems).insert(KDSItemsCompanion.insert(
        uuid: itemUuid,
        orderUuid: orderUuid,
        name: item.menuItem.name,
        modifiers: item.selectedModifiers,
        stationTag: item.menuItem.defaultStation,
        status: ItemStatus.pending,
      ));

      jsonItems.add({
        'uuid': itemUuid,
        'name': item.menuItem.name,
        'modifiers': item.selectedModifiers,
        'stationTag': item.menuItem.defaultStation,
        'status': ItemStatus.pending.index,
      });
    }

    final broadcastPayload = jsonEncode({
      'type': 'OrderCreated',
      'order': {
        'uuid': orderUuid,
        'customerName': state.customerName.isEmpty ? 'Guest' : state.customerName,
        'timestamp': timestamp.toIso8601String(),
        'status': OrderStatus.pending.index,
        'items': jsonItems,
      }
    });

    server.broadcast(broadcastPayload);
    ref.read(intakeProvider.notifier).clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order Sent!'), backgroundColor: Color(0xFF22C55E)),
    );
  }
}

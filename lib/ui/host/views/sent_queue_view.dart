import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../models/database.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_provider.dart';

class SentQueueView extends ConsumerWidget {
  const SentQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider);
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
                        Text(
                          DateFormat(timeFormat).format(order.timestamp),
                          style: const TextStyle(color: Color(0xFF6B7280), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(order.customerName, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    const Divider(height: 24),
                    // Items summary
                    StreamBuilder<List<KDSItemData>>(
                      stream: (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(order.uuid))).watch(),
                      builder: (context, itemSnapshot) {
                        if (!itemSnapshot.hasData) return const SizedBox.shrink();
                        final items = itemSnapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: items.map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
                                const SizedBox(width: 8),
                                Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )).toList(),
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
}

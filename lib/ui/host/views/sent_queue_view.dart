import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/host_store.dart';
import '../../../models/database.dart';
import '../../../models/order_status.dart';
import '../../../providers/app_state_providers.dart';
import '../../../providers/intake_provider.dart';
import '../../../providers/host_store_provider.dart';
import '../../../providers/settings_provider.dart';

class SentQueueView extends ConsumerWidget {
  const SentQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(hostStoreProvider);
    final settings = ref.watch(settingsProvider);
    
    final theme = Theme.of(context);
    final timeFormat = settings.use24HourFormat ? 'HH:mm' : 'h:mm a';

    return StreamBuilder<List<KDSOrderData>>(
      stream: store.watchOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        final activeOrders = orders
            .where((o) => o.status != OrderStatus.complete)
            .toList();
        final closedOrders = orders
            .where((o) => o.status == OrderStatus.complete)
            .toList();

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: theme.scaffoldBackgroundColor,
                child: TabBar(
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  tabs: [
                    Tab(text: 'ACTIVE (${activeOrders.length})'),
                    Tab(text: 'CLOSED (${closedOrders.length})'),
                    Tab(text: 'ALL (${orders.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOrderList(
                      context,
                      ref,
                      store,
                      activeOrders,
                      timeFormat,
                      theme,
                      'No Active Orders',
                      'Orders still in the kitchen will appear here.',
                    ),
                    _buildOrderList(
                      context,
                      ref,
                      store,
                      closedOrders,
                      timeFormat,
                      theme,
                      'No Closed Orders',
                      'Finished orders will appear here.',
                    ),
                    _buildOrderList(
                      context,
                      ref,
                      store,
                      orders,
                      timeFormat,
                      theme,
                      'No Orders',
                      'Submitted orders will appear here.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    WidgetRef ref,
    HostStore store,
    List<KDSOrderData> orders,
    String timeFormat,
    ThemeData theme,
    String emptyTitle,
    String emptySub,
  ) {
    final emptyColor = theme.hintColor;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: emptyColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              emptyTitle,
              style: TextStyle(
                color: emptyColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                emptySub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: emptyColor.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isActive = order.status != OrderStatus.complete;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          order.customerName.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${order.uuid.substring(0, 4).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(order.status),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat(timeFormat).format(order.timestamp),
                          style: TextStyle(
                            color: theme.hintColor,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _editOrder(context, ref, store, order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.add_rounded
                                      : Icons.edit_outlined,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isActive ? 'ADD ITEMS' : 'EDIT',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
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
                  stream: store.watchOrderItems(order.uuid),
                  builder: (context, itemSnapshot) {
                    if (!itemSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final items = itemSnapshot.data!;
                    final orderTotal = items.fold<double>(
                      0,
                      (sum, item) => sum + item.price,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...items.map(
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Color(0xFF22C55E),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (i.modifiers.isNotEmpty)
                                          Text(
                                            i.modifiers.join(', '),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.bold,
                                              backgroundColor: const Color(
                                                0xFFFACC15,
                                              ).withValues(alpha: 0.1),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '\$${i.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: theme.hintColor,
                              ),
                            ),
                            Text(
                              '\$${orderTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
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
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    String text;
    switch (status) {
      case OrderStatus.pending:
        color = const Color(0xFFF59E0B);
        text = 'ACTIVE';
        break;
      case OrderStatus.partial:
        color = const Color(0xFF2AA31F);
        text = 'IN PROGRESS';
        break;
      case OrderStatus.ready:
        color = const Color(0xFF22C55E);
        text = 'SERVED';
        break;
      case OrderStatus.complete:
        color = const Color(0xFF6B7280);
        text = 'CLOSED';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _editOrder(
    BuildContext context,
    WidgetRef ref,
    HostStore store,
    KDSOrderData order,
  ) async {
    final items = await store.getOrderItems(order.uuid);
    final allMenuItems = await store.getMenuItems();

    final List<IntakeItem> intakeItems = [];
    for (final item in items) {
      final menuItem = allMenuItems.firstWhere(
        (m) => m.name == item.name,
        orElse: () => MenuItemData(
          id: -1,
          guid: '',
          name: item.name,
          category: 'General',
          defaultStation: item.stationTag,
          modifiers: [],
          price: item.price,
          requiredModifiers: [],
          tags: [],
          stockQuantity: 0,
          trackStock: false,
          oneTouch: false,
          updatedAtMs: 0,
        ),
      );
      intakeItems.add(
        IntakeItem(
          menuItem: menuItem,
          selectedModifiers: item.modifiers,
          quantity: 1,
        ),
      );
    }

    ref
        .read(intakeProvider.notifier)
        .loadOrder(order.uuid, order.customerName, intakeItems);
    ref.read(hostTabIndexProvider.notifier).state = 0; // Switch to ORDER tab
  }
}

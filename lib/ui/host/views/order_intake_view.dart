import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart';
import 'package:drift/drift.dart' as drift;
import '../../../models/database.dart';
import '../../../models/order_status.dart';
import '../../../models/item_status.dart';
import '../../../providers/intake_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_provider.dart';

class OrderIntakeView extends ConsumerStatefulWidget {
  const OrderIntakeView({super.key});

  @override
  ConsumerState<OrderIntakeView> createState() => _OrderIntakeViewState();
}

class _OrderIntakeViewState extends ConsumerState<OrderIntakeView> {
  late ConfettiController _confettiController;
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  String _selectedTag = 'ALL';

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final intakeState = ref.watch(intakeProvider);
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double totalPrice = 0;
    for (var item in intakeState.items) {
      totalPrice += item.menuItem.price * item.quantity;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomHeight = (screenHeight * 0.4).clamp(160.0, 280.0);

    return Stack(
      children: [
        Column(
          children: [
            // Search and Categories - Refined Design
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search menu...',
                      hintStyle: TextStyle(color: theme.hintColor, fontWeight: FontWeight.normal),
                      prefixIcon: Icon(Icons.search, size: 18, color: theme.hintColor),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterChipRow(
                    stream: db.select(db.menuItems).watch().map((items) {
                      final cats = items.map((i) => i.category.trim().toUpperCase())
                          .where((c) => c.isNotEmpty && c != 'ALL' && c != 'ALL ITEMS')
                          .toSet();
                      return ['ALL', ...cats];
                    }),
                    selected: _selectedCategory,
                    onSelected: (c) => setState(() => _selectedCategory = c),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterChipRow(
                    stream: db.select(db.menuItems).watch().map((items) {
                      final tags = items.expand((i) => i.tags)
                          .map((t) => t.trim().toUpperCase())
                          .where((t) => t.isNotEmpty && t != 'ALL')
                          .toSet();
                      return ['ALL', ...tags];
                    }),
                    selected: _selectedTag,
                    onSelected: (t) => setState(() => _selectedTag = t),
                  ),
                ],
              ),
            ),
            // Menu Grid
            Expanded(
              child: StreamBuilder<List<MenuItemData>>(
                stream: db.select(db.menuItems).watch(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  var items = snapshot.data!;
                  if (_selectedCategory != 'ALL') items = items.where((i) => i.category.toUpperCase() == _selectedCategory).toList();
                  if (_searchQuery.isNotEmpty) items = items.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
                  if (_selectedTag != 'ALL') items = items.where((i) => i.tags.any((t) => t.toUpperCase() == _selectedTag)).toList();
                  
                  if (items.isEmpty) {
                    return Center(child: Text('No items found', style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600)));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isOut = item.trackStock && item.stockQuantity <= 0;
                      
                      return Material(
                        color: isOut ? theme.dividerColor.withOpacity(0.3) : theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: isOut ? null : () => _handleItemTap(context, ref, item),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOut ? Colors.transparent : theme.dividerColor,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, 
                                    fontSize: 13,
                                    color: isOut ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                if (item.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      item.tags.take(2).join(' • ').toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: isOut ? theme.hintColor : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (item.trackStock)
                                      Text(
                                        'QTY: ${item.stockQuantity}',
                                        style: TextStyle(
                                          fontSize: 10, 
                                          color: isOut ? Colors.red : const Color(0xFF666666), 
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    Text(
                                      '\$${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isOut ? theme.hintColor : const Color(0xFF2563EB), 
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Current Ticket Sidebar (Repurposed as bottom-snap for mobile)
            if (intakeState.items.isNotEmpty)
              Container(
                height: bottomHeight,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor, width: 2)),
              ),
              child: Material(
                color: theme.cardColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CURRENT TICKET (${intakeState.items.length})', style: theme.textTheme.labelLarge),
                          if (intakeState.items.isNotEmpty)
                            TextButton(
                              onPressed: () => ref.read(intakeProvider.notifier).clear(),
                              child: const Text('RESET', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: intakeState.items.length,
                        separatorBuilder: (context, index) => Divider(color: theme.dividerColor, height: 1),
                        itemBuilder: (context, index) {
                          final item = intakeState.items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            leading: Text('${item.quantity}×', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            title: Text(item.menuItem.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: item.selectedModifiers.isNotEmpty 
                              ? Text(item.selectedModifiers.join(' • '), style: const TextStyle(fontSize: 11, color: Color(0xFF666666)))
                              : null,
                            trailing: Text('\$${(item.menuItem.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            onTap: () => _showModifierDialog(context, ref, item.menuItem, editIndex: index, initialSelected: item.selectedModifiers, initialQuantity: item.quantity),
                          );
                        },
                      ),
                    ),
                    // Send Button - High Contrast Design
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: intakeState.items.isEmpty ? theme.dividerColor : const Color(0xFF111111),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: intakeState.items.isEmpty ? null : () => _sendToKitchen(context, ref),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                intakeState.editingOrderUuid != null ? 'UPDATE ORDER' : 'COMPLETE ORDER', 
                                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)
                              ),
                              if (totalPrice > 0) ...[
                                const SizedBox(width: 12),
                                const Text('•', style: TextStyle(color: Colors.white38)),
                                const SizedBox(width: 12),
                                Text('\$${totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.1,
              numberOfParticles: 50,
              shouldLoop: false,
              colors: const [Colors.blue, Colors.green, Colors.yellow, Colors.red],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChipRow({
    required Stream<List<String>> stream,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final theme = Theme.of(context);
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        final values = snapshot.data ?? ['ALL'];
        return SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final value = values[index];
              final isSelected = selected == value;
              return InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF111111) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF111111) : theme.dividerColor,
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleItemTap(BuildContext context, WidgetRef ref, MenuItemData item) {
    _showModifierDialog(context, ref, item);
  }

  void _showModifierDialog(BuildContext context, WidgetRef ref, MenuItemData item, {int? editIndex, List<String>? initialSelected, int initialQuantity = 1}) {
    List<String> selected = List.from(initialSelected ?? []);
    int quantity = initialQuantity;
    final db = ref.read(databaseProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => StreamBuilder<List<GlobalModifierData>>(
          stream: db.select(db.globalModifiers).watch(),
          builder: (context, snapshot) {
            final globals = snapshot.data ?? [];
            final requiredMods = item.requiredModifiers ?? [];
            final allModifiers = {
              ...requiredMods,
              ...item.modifiers,
              ...globals.map((g) => g.name)
            }.toList();
            bool isRequirementMet = requiredMods.isEmpty || selected.any((s) => requiredMods.contains(s));

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Theme.of(context).dividerColor)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.4)),
                  if (requiredMods.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('REQUIREMENT: SELECT ONE (${requiredMods.join(", ")})', 
                        style: TextStyle(fontSize: 10, color: isRequirementMet ? const Color(0xFF22C55E) : Colors.red, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUANTITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF666666), letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 2,
                            child: Center(child: Text('$quantity', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: (item.trackStock && quantity >= item.stockQuantity) ? null : () => setDialogState(() => quantity++),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('MODIFIERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF666666), letterSpacing: 1)),
                        const Spacer(),
                        if (requiredMods.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('SELECTION REQUIRED', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allModifiers.map((mod) {
                        final isSelected = selected.contains(mod);
                        final isReq = requiredMods.contains(mod);
                        return FilterChip(
                          label: Text(mod),
                          selected: isSelected,
                          onSelected: (val) => setDialogState(() => val ? selected.add(mod) : selected.remove(mod)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: isReq && !isSelected 
                                ? Colors.red 
                                : (isSelected ? Colors.transparent : Theme.of(context).dividerColor),
                              width: isReq && !isSelected ? 1.5 : 1,
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          selectedColor: const Color(0xFF111111),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isReq ? Colors.red.shade700 : Theme.of(context).textTheme.bodyMedium?.color),
                            fontWeight: (isSelected || isReq) ? FontWeight.w900 : FontWeight.w700,
                            fontSize: 12
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF666666)))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRequirementMet ? const Color(0xFF111111) : Theme.of(context).dividerColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isRequirementMet ? () {
                    if (editIndex != null) ref.read(intakeProvider.notifier).updateItem(editIndex, modifiers: selected, quantity: quantity);
                    else ref.read(intakeProvider.notifier).addItem(item, selectedModifiers: selected, quantity: quantity);
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  } : null,
                  child: Text(editIndex != null ? 'SAVE CHANGES' : 'ADD TO ORDER'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendToKitchen(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final state = ref.read(intakeProvider);
    final db = ref.read(databaseProvider);
    final server = ref.read(hostServerProvider);
    
    final isEditing = state.editingOrderUuid != null;
    final orderUuid = state.editingOrderUuid ?? const Uuid().v4();
    final timestamp = DateTime.now();

    if (isEditing) {
      // 1. Restore stock for old items before replacement
      final oldItems = await (db.select(db.kDSItems)..where((t) => t.orderUuid.equals(orderUuid))).get();
      for (final oldItem in oldItems) {
        final menuMatches = await (db.select(db.menuItems)..where((t) => t.name.equals(oldItem.name))).get();
        if (menuMatches.isNotEmpty && menuMatches.first.trackStock) {
          await (db.update(db.menuItems)..where((t) => t.id.equals(menuMatches.first.id))).write(
            MenuItemsCompanion(stockQuantity: drift.Value(menuMatches.first.stockQuantity + 1)),
          );
        }
      }
      // 2. Clear old items
      await (db.delete(db.kDSItems)..where((t) => t.orderUuid.equals(orderUuid))).go();
      // 3. Update order record
      await (db.update(db.kDSOrders)..where((t) => t.uuid.equals(orderUuid))).write(
        KDSOrdersCompanion(
          customerName: drift.Value(state.customerName.isEmpty ? 'Guest' : state.customerName),
          timestamp: drift.Value(timestamp),
          status: const drift.Value(OrderStatus.pending),
        ),
      );
    } else {
      await db.into(db.kDSOrders).insert(KDSOrderData(
        uuid: orderUuid,
        customerName: state.customerName.isEmpty ? 'Guest' : state.customerName,
        timestamp: timestamp,
        status: OrderStatus.pending,
      ));
    }

    final List<Map<String, dynamic>> jsonItems = [];
    for (final item in state.items) {
      if (item.menuItem.trackStock) {
        // Re-fetch to get latest stock after restoration (if any)
        final fresh = await (db.select(db.menuItems)..where((t) => t.id.equals(item.menuItem.id))).getSingle();
        await (db.update(db.menuItems)..where((t) => t.id.equals(item.menuItem.id))).write(
          MenuItemsCompanion(stockQuantity: drift.Value(fresh.stockQuantity - item.quantity)),
        );
      }
      for (int i = 0; i < item.quantity; i++) {
        final itemUuid = const Uuid().v4();
        await db.into(db.kDSItems).insert(KDSItemsCompanion.insert(
          uuid: itemUuid,
          orderUuid: orderUuid,
          name: item.menuItem.name,
          modifiers: item.selectedModifiers,
          stationTag: item.menuItem.defaultStation,
          status: ItemStatus.pending,
          price: drift.Value(item.menuItem.price),
        ));
        jsonItems.add({
          'uuid': itemUuid,
          'name': item.menuItem.name,
          'modifiers': item.selectedModifiers,
          'stationTag': item.menuItem.defaultStation,
          'status': ItemStatus.pending.index,
          'price': item.menuItem.price,
        });
      }
    }

    final broadcastPayload = jsonEncode({
      'type': isEditing ? 'OrderUpdated' : 'OrderCreated',
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
    
    if (ref.read(settingsProvider).enableConfetti) {
      _confettiController.play();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Order Updated Successfully' : 'Order Sent Successfully'), 
        backgroundColor: const Color(0xFF111111)
      )
    );
  }
}

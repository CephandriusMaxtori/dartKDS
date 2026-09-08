import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/database.dart';
import '../../models/order_status.dart';
import '../../models/item_status.dart';
import '../../providers/intake_provider.dart';
import '../../providers/service_providers.dart';

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final intakeState = ref.watch(intakeProvider);
    final db = ref.watch(databaseProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          if (!isMobile)
            TextButton(
              onPressed: () => ref.read(intakeProvider.notifier).clear(),
              child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<MenuItemData>>(
        stream: db.select(db.menuItems).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final menuCatalog = snapshot.data!;
          
          if (menuCatalog.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No items in your library', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Add Items in Settings'),
                  ),
                ],
              ),
            );
          }

          final categories = menuCatalog.map((e) => e.category).toSet().toList();
          _selectedCategory ??= categories.first;
          
          final itemsInCategory = menuCatalog.where((e) => e.category == _selectedCategory).toList();

          final menuGrid = Column(
            children: [
              Container(
                height: 70,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 12, bottom: 12),
                      child: Material(
                        color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            alignment: Alignment.center,
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width > 1200 ? 5 : (width > 600 ? 3 : 2),
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: itemsInCategory.length,
                  itemBuilder: (context, index) {
                    final item = itemsInCategory[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _handleItemTap(context, ref, item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.defaultStation,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              children: [
                Expanded(child: menuGrid),
                if (intakeState.items.isNotEmpty)
                  _buildMobileCartBar(context, intakeState),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: menuGrid),
              _buildCartSidebar(context, intakeState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileCartBar(BuildContext context, IntakeState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _showCartBottomSheet(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart),
            const SizedBox(width: 12),
            Text('VIEW TICKET (${state.items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(intakeProvider);
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Ticket', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                _buildCustomerField(),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return ListTile(
                        title: Text(item.menuItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: item.selectedModifiers.isNotEmpty
                            ? Text(item.selectedModifiers.join(', '), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => ref.read(intakeProvider.notifier).removeItem(index),
                        ),
                        onTap: () => _showModifierDialog(
                          context,
                          ref,
                          item.menuItem,
                          editIndex: index,
                          initialSelected: item.selectedModifiers,
                        ),
                      );
                    },
                  ),
                ),
                _buildActionFooter(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartSidebar(BuildContext context, IntakeState intakeState) {
    return Container(
      width: 380,
      color: Colors.white,
      child: Column(
        children: [
          _buildCustomerField(),
          Expanded(
            child: ListView.builder(
              itemCount: intakeState.items.length,
              itemBuilder: (context, index) {
                final cartItem = intakeState.items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(cartItem.menuItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: cartItem.selectedModifiers.isNotEmpty
                      ? Text(cartItem.selectedModifiers.join(', '), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                    onPressed: () => ref.read(intakeProvider.notifier).removeItem(index),
                  ),
                  onTap: () => _showModifierDialog(
                    context,
                    ref,
                    cartItem.menuItem,
                    editIndex: index,
                    initialSelected: cartItem.selectedModifiers,
                  ),
                );
              },
            ),
          ),
          _buildActionFooter(context, intakeState),
        ],
      ),
    );
  }

  Widget _buildCustomerField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Add Customer Name',
          prefixIcon: Icon(Icons.person_outline),
          border: InputBorder.none,
        ),
        onChanged: (val) => ref.read(intakeProvider.notifier).setCustomerName(val),
      ),
    );
  }

  Widget _buildActionFooter(BuildContext context, IntakeState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Items', style: TextStyle(fontSize: 16, color: Colors.grey)),
              Text('${state.items.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: state.items.isEmpty ? null : () => _submitOrder(ref),
            child: const Text('SEND TO KITCHEN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
                  selectedColor: const Color(0xFF007AFF),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white),
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

  Future<void> _submitOrder(WidgetRef ref) async {
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
    if (mounted) {
      // If we are in a bottom sheet on mobile, pop it first
      if (MediaQuery.of(context).size.width < 900) {
         Navigator.of(context, rootNavigator: true).pop(); // Close bottom sheet
      }
      Navigator.pop(context); // Close intake screen
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order sent to kitchen'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

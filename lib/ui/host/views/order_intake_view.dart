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

class OrderIntakeView extends ConsumerStatefulWidget {
  const OrderIntakeView({super.key});

  @override
  ConsumerState<OrderIntakeView> createState() => _OrderIntakeViewState();
}

class _OrderIntakeViewState extends ConsumerState<OrderIntakeView> {
  late ConfettiController _confettiController;
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

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

    double totalPrice = 0;
    for (var item in intakeState.items) {
      totalPrice += item.menuItem.price * item.quantity;
    }

    return Stack(
      children: [
        Column(
          children: [
            // Search and Categories
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search menu...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<String>>(
                    stream: db.select(db.menuItems).watch().map((items) => ['ALL', ...{...items.map((i) => i.category.toUpperCase())}]),
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? ['ALL'];
                      return SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = _selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (val) => setState(() => _selectedCategory = cat),
                              selectedColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Upper Half: Menu Grid
            Expanded(
              flex: 55,
              child: StreamBuilder<List<MenuItemData>>(
                stream: db.select(db.menuItems).watch(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  var items = snapshot.data!;

                  // Filter by Category
                  if (_selectedCategory != 'ALL') {
                    items = items.where((i) => i.category.toUpperCase() == _selectedCategory).toList();
                  }

                  // Filter by Search
                  if (_searchQuery.isNotEmpty) {
                    items = items.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
                  }
                  
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_searchQuery.isEmpty ? Icons.library_add : Icons.search_off, size: 64, color: const Color(0xFFE5E7EB)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'No Items in Category' : 'No matches found', 
                            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)
                          ),
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
                      final isOutOfStock = item.trackStock && item.stockQuantity <= 0;
                      
                      return Material(
                        color: isOutOfStock ? Colors.grey.shade200 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: isOutOfStock ? null : () => _handleItemTap(context, ref, item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: isOutOfStock ? Colors.transparent : const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800, 
                                    fontSize: 14,
                                    color: isOutOfStock ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (item.trackStock)
                                      Text(
                                        '(${item.stockQuantity}) ',
                                        style: TextStyle(
                                          fontSize: 12, 
                                          color: isOutOfStock ? Colors.red : Colors.orange.shade700, 
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    Text(
                                      '\$${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: isOutOfStock ? Colors.grey : const Color(0xFF2563EB), 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isOutOfStock)
                                  const Text(
                                    'OUT OF STOCK',
                                    style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w900),
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
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // Lower Half: Current Ticket
            Expanded(
              flex: 45,
              child: Material(
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
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                              child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                            ),
                            title: Text(item.menuItem.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color)),
                            subtitle: item.selectedModifiers.isNotEmpty 
                              ? Text(item.selectedModifiers.join(', '), style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12))
                              : Text(item.menuItem.defaultStation, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                            trailing: Text(
                              '\$${(item.menuItem.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _showModifierDialog(
                              context, 
                              ref, 
                              item.menuItem, 
                              editIndex: index, 
                              initialSelected: item.selectedModifiers,
                              initialQuantity: item.quantity,
                            ),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'SEND TO KITCHEN',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                              if (totalPrice > 0) ...[
                                const VerticalDivider(color: Colors.white54, width: 32, indent: 12, endIndent: 12),
                                Text(
                                  '\$${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
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
            final allModifiers = {...item.modifiers, ...globals.map((g) => g.name)}.toList();
            final requiredMods = item.requiredModifiers ?? [];
            
            bool isRequirementMet = true;
            if (requiredMods.isNotEmpty) {
              isRequirementMet = selected.any((s) => requiredMods.contains(s));
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add to Ticket: ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (requiredMods.isNotEmpty)
                    Text(
                      'REQUIRED: Select at least one (${requiredMods.join(", ")})',
                      style: TextStyle(fontSize: 12, color: isRequirementMet ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUANTITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, size: 32, color: Color(0xFFDC2626)),
                            onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                          ),
                          Column(
                            children: [
                              Text('$quantity', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                              if (item.trackStock)
                                Text('Max: ${item.stockQuantity}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF22C55E)),
                            onPressed: (item.trackStock && quantity >= item.stockQuantity) 
                              ? null 
                              : () => setDialogState(() => quantity++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('MODIFIERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Show Required Modifiers first with distinct styling if needed
                        ...allModifiers.map((mod) {
                          final isSelected = selected.contains(mod);
                          final isRequired = requiredMods.contains(mod);
                          return FilterChip(
                            label: Text(mod),
                            selected: isSelected,
                            onSelected: (val) {
                              setDialogState(() {
                                if (val) {
                                  // If it's a required mod, we might want to allow only one?
                                  // For now, just add it.
                                  selected.add(mod);
                                } else {
                                  selected.remove(mod);
                                }
                              });
                            },
                            side: isRequired && !isSelected ? const BorderSide(color: Colors.red, width: 2) : null,
                            selectedColor: const Color(0xFF2563EB),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRequirementMet ? const Color(0xFF2563EB) : Colors.grey, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isRequirementMet ? () {
                    if (editIndex != null) {
                      ref.read(intakeProvider.notifier).updateItem(editIndex, modifiers: selected, quantity: quantity);
                    } else {
                      ref.read(intakeProvider.notifier).addItem(item, selectedModifiers: selected, quantity: quantity);
                    }
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  } : null,
                  child: Text(editIndex != null ? 'UPDATE' : 'ADD TO TICKET'),
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
      // Decrement stock if tracking is enabled
      if (item.menuItem.trackStock) {
        await (db.update(db.menuItems)..where((t) => t.id.equals(item.menuItem.id))).write(
          MenuItemsCompanion(
            stockQuantity: drift.Value(item.menuItem.stockQuantity - item.quantity),
          ),
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
    _confettiController.play();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order Sent!'), backgroundColor: Color(0xFF22C55E)),
    );
  }
}

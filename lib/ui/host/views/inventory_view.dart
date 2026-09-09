import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:share_plus/share_plus.dart';
import '../../../models/database.dart';
import '../../../providers/service_providers.dart';

class InventoryView extends ConsumerWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVENTORY MANAGEMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: isCompact ? 18 : 22, 
                        letterSpacing: 1.2
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor and update current stock levels for your items.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: isCompact ? 12 : 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportShoppingList(context, db),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: isCompact ? const Text('LIST') : const Text('EXPORT LIST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<MenuItemData>>(
            stream: (db.select(db.menuItems)..where((t) => t.trackStock.equals(true))).watch(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final items = snapshot.data!;

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No Items Being Tracked', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Enable "Track Stock" for items in the Library tab.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                itemCount: items.length,
                separatorBuilder: (context, index) => SizedBox(height: isCompact ? 8 : 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isLow = item.stockQuantity > 0 && item.stockQuantity <= 5;
                  final isOut = item.stockQuantity <= 0;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isOut ? Colors.red : (isLow ? Colors.orange : const Color(0xFFE5E7EB)),
                        width: isOut || isLow ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 12 : 16),
                      child: isCompact 
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                        Text(item.defaultStation.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${item.stockQuantity}',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isOut ? Colors.red : Colors.black87),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(child: _buildStockButton(context, db, item, -1, '-1', const Color(0xFF2563EB))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildStockButton(context, db, item, 1, '+1', const Color(0xFF2563EB))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildStockButton(context, db, item, 0, 'ZERO', Colors.red)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildCustomStockButton(context, db, item)),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.defaultStation.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: Color(0xFF2563EB)),
                                      onPressed: () => _updateStock(db, item, item.stockQuantity - 1),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        '${item.stockQuantity}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: isOut ? Colors.red : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
                                      onPressed: () => _updateStock(db, item, item.stockQuantity + 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildStockButton(context, db, item, 0, 'ZERO', Colors.red),
                              const SizedBox(width: 8),
                              _buildCustomStockButton(context, db, item),
                            ],
                          ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomStockButton(BuildContext context, KDSDatabase db, MenuItemData item) {
    return InkWell(
      onTap: () => _showSetStockDialog(context, db, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.5)),
        ),
        child: const Text(
          'SET',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  void _showSetStockDialog(BuildContext context, KDSDatabase db, MenuItemData item) {
    final controller = TextEditingController(text: item.stockQuantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Stock: ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                _updateStock(db, item, val);
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockButton(BuildContext context, KDSDatabase db, MenuItemData item, int val, String label, Color color) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (label == 'ZERO') {
          _updateStock(db, item, 0);
        } else {
          _updateStock(db, item, item.stockQuantity + val);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  void _updateStock(KDSDatabase db, MenuItemData item, int newQuantity) async {
    if (newQuantity < 0) newQuantity = 0;
    await (db.update(db.menuItems)..where((t) => t.id.equals(item.id))).write(
      MenuItemsCompanion(stockQuantity: drift.Value(newQuantity)),
    );
  }

  void _exportShoppingList(BuildContext context, KDSDatabase db) async {
    final lowStockItems = await (db.select(db.menuItems)
          ..where((t) => t.trackStock.equals(true))
          ..where((t) => t.stockQuantity.isSmallerOrEqualValue(5)))
        .get();

    if (lowStockItems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All items are in stock! No list needed.')),
        );
      }
      return;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('KITCHEN SHOPPING LIST - ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('---------------------------');
    for (final item in lowStockItems) {
      final status = item.stockQuantity <= 0 ? 'OUT' : 'LOW (${item.stockQuantity})';
      buffer.writeln('[ ] ${item.name.toUpperCase()} - Status: $status');
    }
    buffer.writeln('---------------------------');
    buffer.writeln('Sent from DartKDS POS');

    await Share.share(buffer.toString(), subject: 'Kitchen Shopping List');
  }
}

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
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOCK MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.4)),
                      Text('Sync and monitor live inventory levels.', style: TextStyle(color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportShoppingList(context, db),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text(isCompact ? 'LIST' : 'EXPORT LIST', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MenuItemData>>(
              stream: (db.select(db.menuItems)..where((t) => t.trackStock.equals(true))).watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(child: Text('No tracked items found', style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600)));
                }

                return ListView.separated(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => SizedBox(height: isCompact ? 12 : 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isLow = item.stockQuantity > 0 && item.stockQuantity <= 5;
                    final isOut = item.stockQuantity <= 0;

                    return Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOut ? Colors.red : (isLow ? Colors.orange : theme.dividerColor),
                            width: isOut || isLow ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: isCompact 
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.2)),
                                          Text(item.defaultStation.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),
                                    Text('${item.stockQuantity}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isOut ? Colors.red : theme.textTheme.bodyLarge?.color)),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    _quickAdjust(context, db, item, -1, '-1'),
                                    const SizedBox(width: 8),
                                    _quickAdjust(context, db, item, 1, '+1'),
                                    const SizedBox(width: 8),
                                    _quickAdjust(context, db, item, 0, 'Zero', col: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(child: _setButton(context, db, item)),
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
                                      Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2)),
                                      Text(item.defaultStation.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                    ],
                                  ),
                                ),
                                _quickAdjust(context, db, item, -1, '-1'),
                                const SizedBox(width: 8),
                                _quickAdjust(context, db, item, 1, '+1'),
                                const SizedBox(width: 16),
                                Container(
                                  width: 80,
                                  alignment: Alignment.center,
                                  child: Text('${item.stockQuantity}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isOut ? Colors.red : theme.textTheme.bodyLarge?.color)),
                                ),
                                const SizedBox(width: 16),
                                _quickAdjust(context, db, item, 0, 'Zero', col: Colors.red),
                                const SizedBox(width: 8),
                                _setButton(context, db, item),
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
      ),
    );
  }

  Widget _quickAdjust(BuildContext context, KDSDatabase db, MenuItemData item, int val, String label, {Color? col}) {
    final theme = Theme.of(context);
    final color = col ?? theme.colorScheme.onSurface;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (label == 'Zero') _updateStock(db, item, 0);
        else _updateStock(db, item, item.stockQuantity + val);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 50,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }

  Widget _setButton(BuildContext context, KDSDatabase db, MenuItemData item) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: () => _showSetStockDialog(context, db, item),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: const Text('SET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  void _showSetStockDialog(BuildContext context, KDSDatabase db, MenuItemData item) {
    final controller = TextEditingController(text: item.stockQuantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).dividerColor)),
        title: Text('SET STOCK: ${item.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Manual Entry', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF666666)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111111), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) { _updateStock(db, item, val); Navigator.pop(context); }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _updateStock(KDSDatabase db, MenuItemData item, int newQuantity) async {
    if (newQuantity < 0) newQuantity = 0;
    await (db.update(db.menuItems)..where((t) => t.id.equals(item.id))).write(MenuItemsCompanion(
      stockQuantity: drift.Value(newQuantity),
      updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  void _exportShoppingList(BuildContext context, KDSDatabase db) async {
    final lowStockItems = await (db.select(db.menuItems)..where((t) => t.trackStock.equals(true))..where((t) => t.stockQuantity.isSmallerOrEqualValue(5))).get();
    if (lowStockItems.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All items are in stock.'))); return; }
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('SHOPPING LIST - ${DateTime.now().toString().substring(0, 16)}');
    for (final item in lowStockItems) buffer.writeln('[ ] ${item.name.toUpperCase()} (${item.stockQuantity <= 0 ? "OUT" : item.stockQuantity})');
    await Share.share(buffer.toString(), subject: 'Kitchen Shopping List');
  }
}

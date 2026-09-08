import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/service_providers.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stationController = TextEditingController();
  final _modifiersController = TextEditingController();

  void _addItem() async {
    if (_nameController.text.isEmpty || _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Category are required')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    await db.into(db.menuItems).insert(MenuItemsCompanion.insert(
          name: _nameController.text.trim(),
          category: _categoryController.text.trim(),
          defaultStation: _stationController.text.trim().isEmpty ? 'General' : _stationController.text.trim(),
          modifiers: _modifiersController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        ));

    final addedName = _nameController.text;
    _nameController.clear();
    _modifiersController.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $addedName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;
    final theme = Theme.of(context);

    final formWidget = Container(
      width: isMobile ? double.infinity : 350,
      color: theme.cardTheme.color,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Create Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(), hintText: 'e.g. Latte'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), hintText: 'e.g. Coffee'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stationController,
            decoration: const InputDecoration(labelText: 'Station', border: OutlineInputBorder(), hintText: 'e.g. Barista'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modifiersController,
            decoration: const InputDecoration(labelText: 'Modifiers (comma separated)', border: OutlineInputBorder(), hintText: 'e.g. Oat Milk, Soy Milk'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _addItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('SAVE ITEM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    final listWidget = StreamBuilder<List<MenuItemData>>(
      stream: db.select(db.menuItems).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No items yet. Add one to get started!'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: theme.cardTheme.color,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.category} • ${item.defaultStation}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => (db.delete(db.menuItems)..where((t) => t.id.equals(item.id))).go(),
                ),
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: isMobile
          ? SingleChildScrollView(
              child: Column(
                children: [
                  formWidget,
                  const Divider(height: 1),
                  SizedBox(
                    height: 400, // Fixed height for list on mobile within scrollview
                    child: listWidget,
                  ),
                ],
              ),
            )
          : Row(
              children: [
                formWidget,
                const VerticalDivider(width: 1),
                Expanded(child: listWidget),
              ],
            ),
    );
  }
}

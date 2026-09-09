import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../models/database.dart';
import '../../../providers/service_providers.dart';

class LibraryView extends ConsumerStatefulWidget {
  final int initialTab;
  const LibraryView({super.key, this.initialTab = 0});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  final _nameController = TextEditingController();
  final _modifiersController = TextEditingController();
  final _requiredModifiersController = TextEditingController();
  final _stationController = TextEditingController();
  final _globalModifierController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  bool _trackStock = false;
  String? _selectedStation;

  @override
  void dispose() {
    _nameController.dispose();
    _modifiersController.dispose();
    _requiredModifiersController.dispose();
    _stationController.dispose();
    _globalModifierController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return StreamBuilder<List<StationData>>(
      stream: db.select(db.stations).watch(),
      builder: (context, stationSnapshot) {
        if (stationSnapshot.hasError) {
          return Center(child: Text('Database Error: ${stationSnapshot.error}'));
        }
        
        if (!stationSnapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading Station Config...'),
              ],
            ),
          );
        }

        final stations = stationSnapshot.data ?? [];
        
        if (stations.isNotEmpty) {
          final stationExists = stations.any((s) => s.name == _selectedStation);
          if (!stationExists) {
            _selectedStation = stations.first.name;
          }
        } else {
          _selectedStation = null;
        }

        return DefaultTabController(
          length: 4,
          initialIndex: widget.initialTab,
          child: Column(
            children: [
              const TabBar(
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                tabs: [
                  Tab(text: 'ITEMS'),
                  Tab(text: 'STATIONS'),
                  Tab(text: 'MODIFIERS'),
                  Tab(text: 'BACKUP'),
                ],
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF6B7280),
                indicatorColor: Color(0xFF2563EB),
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildItemsTab(db, theme, stations),
                    _buildStationsTab(db, theme, stations),
                    _buildGlobalModifiersTab(db, theme),
                    _buildBackupTab(db, theme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsTab(KDSDatabase db, ThemeData theme, List<StationData> stations) {
    return StreamBuilder<List<MenuItemData>>(
      stream: db.select(db.menuItems).watch(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Database...'),
              ],
            ),
          );
        }
        final items = snapshot.data!;
        
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 0,
                  color: theme.cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('CREATE NEW ITEM',
                            style: TextStyle(fontWeight: FontWeight.w900, color: theme.hintColor, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _modifiersController,
                          decoration: const InputDecoration(
                            labelText: 'Available Modifiers (comma separated)',
                            hintText: 'e.g. No Onion, Extra Cheese',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _requiredModifiersController,
                          decoration: const InputDecoration(
                            labelText: 'Required Modifiers (comma separated)',
                            hintText: 'e.g. Rare, Medium, Well Done',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedStation,
                          decoration: const InputDecoration(
                            labelText: 'Routing Station',
                            border: OutlineInputBorder(),
                          ),
                          items: stations.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                          onChanged: (val) => setState(() => _selectedStation = val),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Track Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Prevent ordering when quantity is zero', style: TextStyle(fontSize: 12)),
                          value: _trackStock,
                          onChanged: (val) => setState(() => _trackStock = val),
                          activeColor: const Color(0xFF2563EB),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_trackStock) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial Stock Quantity',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        onPressed: () async {
                          if (_nameController.text.isNotEmpty && _selectedStation != null) {
                            final modifiers = _modifiersController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final requiredModifiers = _requiredModifiersController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final price = double.tryParse(_priceController.text) ?? 0.0;
                            final stock = int.tryParse(_stockController.text) ?? 0;

                            await db.into(db.menuItems).insert(MenuItemsCompanion.insert(
                                  name: _nameController.text,
                                  category: 'All Items',
                                  defaultStation: _selectedStation!,
                                  modifiers: modifiers,
                                  requiredModifiers: drift.Value(requiredModifiers),
                                  price: drift.Value(price),
                                  stockQuantity: drift.Value(stock),
                                  trackStock: drift.Value(_trackStock),
                                ));
                            _nameController.clear();
                            _modifiersController.clear();
                            _requiredModifiersController.clear();
                            _priceController.clear();
                            _stockController.clear();
                            setState(() => _trackStock = false);
                          }
                        },
                          child: const Text('ADD TO LIBRARY', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: theme.cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                if (item.trackStock)
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.stockQuantity <= 0 ? Colors.red.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'STOCK: ${item.stockQuantity}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: item.stockQuantity <= 0 ? Colors.red : Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                Text('\$${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.defaultStation.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                if (item.modifiers.isNotEmpty)
                                  ...item.modifiers.take(3).map((m) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      m,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  )),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                              onPressed: () => _showEditItemDialog(context, db, item, stations),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: theme.hintColor),
                              onPressed: () => (db.delete(db.menuItems)..where((t) => t.id.equals(item.id))).go(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStationsTab(KDSDatabase db, ThemeData theme, List<StationData> stations) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              color: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('ADD NEW STATION',
                        style: TextStyle(fontWeight: FontWeight.w900, color: theme.hintColor, fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _stationController,
                      decoration: const InputDecoration(
                        labelText: 'Station Name',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        hintText: 'e.g. Grill',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (_stationController.text.isNotEmpty) {
                          await db.into(db.stations).insert(StationsCompanion.insert(
                                name: _stationController.text.trim(),
                              ));
                          _stationController.clear();
                        }
                      },
                      child: const Text('SAVE STATION', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final station = stations[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: theme.cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                          onPressed: () => _showEditStationDialog(context, db, station),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.hintColor),
                          onPressed: () => (db.delete(db.stations)..where((t) => t.id.equals(station.id))).go(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: stations.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalModifiersTab(KDSDatabase db, ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 0,
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ADD GLOBAL MODIFIER',
                      style: TextStyle(fontWeight: FontWeight.w900, color: theme.hintColor, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _globalModifierController,
                    decoration: const InputDecoration(
                      labelText: 'Modifier Name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      hintText: 'e.g. Extra Sauce',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (_globalModifierController.text.isNotEmpty) {
                        await db.into(db.globalModifiers).insert(GlobalModifiersCompanion.insert(
                              name: _globalModifierController.text.trim(),
                            ));
                        _globalModifierController.clear();
                      }
                    },
                    child: const Text('SAVE MODIFIER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GlobalModifierData>>(
            stream: db.select(db.globalModifiers).watch(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final mods = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mods.length,
                itemBuilder: (context, index) {
                  final mod = mods[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: theme.cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: ListTile(
                      title: Text(mod.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.hintColor),
                        onPressed: () => (db.delete(db.globalModifiers)..where((t) => t.id.equals(mod.id))).go(),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showEditStationDialog(BuildContext context, KDSDatabase db, StationData station) {
    final controller = TextEditingController(text: station.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Station'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await (db.update(db.stations)..where((t) => t.id.equals(station.id))).write(
                  StationsCompanion(name: drift.Value(controller.text.trim())),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTab(KDSDatabase db, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader('BACKUP & SYNC'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFF2563EB)),
                title: const Text('Export Library', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Save your menu, stations, and modifiers to a file'),
                onTap: () => _exportLibrary(db),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload, color: Color(0xFF22C55E)),
                title: const Text('Import Library', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Restore or load a library from a file'),
                onTap: () => _importLibrary(db),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Use this to move your menu to another Host device or keep a backup of your configuration.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _exportLibrary(KDSDatabase db) async {
    try {
      final items = await db.select(db.menuItems).get();
      final stations = await db.select(db.stations).get();
      final modifiers = await db.select(db.globalModifiers).get();

      final data = {
        'version': 1,
        'menuItems': items.map((i) => {
          'name': i.name,
          'category': i.category,
          'defaultStation': i.defaultStation,
          'modifiers': i.modifiers,
          'requiredModifiers': i.requiredModifiers,
          'price': i.price,
          'stockQuantity': i.stockQuantity,
          'trackStock': i.trackStock,
        }).toList(),
        'stations': stations.map((s) => {'name': s.name}).toList(),
        'globalModifiers': modifiers.map((m) => {'name': m.name}).toList(),
      };

      final jsonString = jsonEncode(data);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/dartkds_library_backup.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'DartKDS Library Backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importLibrary(KDSDatabase db) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString);

        if (data['version'] != 1) throw 'Unsupported backup version';

        await db.transaction(() async {
          // Import Stations (ignore duplicates)
          for (var s in data['stations']) {
            await db.into(db.stations).insertOnConflictUpdate(
              StationsCompanion.insert(name: s['name'])
            );
          }

          // Import Global Modifiers
          for (var m in data['globalModifiers']) {
            await db.into(db.globalModifiers).insertOnConflictUpdate(
              GlobalModifiersCompanion.insert(name: m['name'])
            );
          }

          // Import Menu Items
          for (var i in data['menuItems']) {
            await db.into(db.menuItems).insert(
              MenuItemsCompanion.insert(
                name: i['name'],
                category: i['category'],
                defaultStation: i['defaultStation'],
                modifiers: List<String>.from(i['modifiers']),
                requiredModifiers: drift.Value(i['requiredModifiers'] != null ? List<String>.from(i['requiredModifiers']) : <String>[]),
                price: drift.Value(i['price'] ?? 0.0),
                stockQuantity: drift.Value(i['stockQuantity'] ?? 0),
                trackStock: drift.Value(i['trackStock'] ?? false),
              )
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Library imported successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _showEditItemDialog(BuildContext context, KDSDatabase db, MenuItemData item, List<StationData> stations) {
    final nameCtrl = TextEditingController(text: item.name);
    final modCtrl = TextEditingController(text: item.modifiers.join(', '));
    final reqModCtrl = TextEditingController(text: (item.requiredModifiers ?? []).join(', '));
    final priceCtrl = TextEditingController(text: item.price.toString());
    final stockCtrl = TextEditingController(text: item.stockQuantity.toString());
    bool trackStock = item.trackStock;
    String selectedStation = item.defaultStation;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                const SizedBox(height: 12),
                TextField(controller: modCtrl, decoration: const InputDecoration(labelText: 'Available Modifiers')),
                const SizedBox(height: 12),
                TextField(controller: reqModCtrl, decoration: const InputDecoration(labelText: 'Required Modifiers')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price', prefixText: '\$')),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Track Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: trackStock,
                  onChanged: (val) => setDialogState(() => trackStock = val),
                  contentPadding: EdgeInsets.zero,
                ),
                if (trackStock)
                  TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Quantity')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: stations.any((s) => s.name == selectedStation) ? selectedStation : (stations.isNotEmpty ? stations.first.name : null),
                  decoration: const InputDecoration(labelText: 'Station'),
                  items: stations.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                  onChanged: (val) => setDialogState(() => selectedStation = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final modifiers = modCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final requiredModifiers = reqModCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final price = double.tryParse(priceCtrl.text) ?? 0.0;
                  final stock = int.tryParse(stockCtrl.text) ?? 0;
                  
                  await (db.update(db.menuItems)..where((t) => t.id.equals(item.id))).write(
                    MenuItemsCompanion(
                      name: drift.Value(nameCtrl.text.trim()),
                      defaultStation: drift.Value(selectedStation),
                      modifiers: drift.Value(modifiers),
                      requiredModifiers: drift.Value(requiredModifiers),
                      price: drift.Value(price),
                      stockQuantity: drift.Value(stock),
                      trackStock: drift.Value(trackStock),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}

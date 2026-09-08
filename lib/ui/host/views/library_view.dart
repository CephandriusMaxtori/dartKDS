import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../models/database.dart';
import '../../../providers/service_providers.dart';

class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  final _nameController = TextEditingController();
  final _modifiersController = TextEditingController();
  final _stationController = TextEditingController();
  String? _selectedStation;

  @override
  void dispose() {
    _nameController.dispose();
    _modifiersController.dispose();
    _stationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return StreamBuilder<List<StationData>>(
      stream: db.select(db.stations).watch(),
      builder: (context, stationSnapshot) {
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
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'ITEMS'),
                  Tab(text: 'STATIONS'),
                ],
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF6B7280),
                indicatorColor: Color(0xFF2563EB),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildItemsTab(db, theme, stations),
                    _buildStationsTab(db, theme, stations),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                            labelText: 'Modifiers (comma separated)',
                            hintText: 'e.g. No Onion, Extra Cheese',
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

                              await db.into(db.menuItems).insert(MenuItemsCompanion.insert(
                                    name: _nameController.text,
                                    category: 'All Items',
                                    defaultStation: _selectedStation!,
                                    modifiers: modifiers,
                                  ));
                              _nameController.clear();
                              _modifiersController.clear();
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
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.hintColor),
                          onPressed: () => (db.delete(db.menuItems)..where((t) => t.id.equals(item.id))).go(),
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
}

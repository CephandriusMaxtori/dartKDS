import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.js_interop) '../../../web_path_provider_stub.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' if (dart.library.js_interop) '../../../web_io_stub.dart';
import '../../../models/database.dart';
import '../../../providers/app_state_providers.dart';
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
  final _tagsController = TextEditingController();
  final _stationController = TextEditingController();
  final _globalModifierController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController(text: 'All Items');
  bool _trackStock = false;
  bool _oneTouch = false;
  String? _selectedStation;

  @override
  void dispose() {
    _nameController.dispose();
    _modifiersController.dispose();
    _requiredModifiersController.dispose();
    _tagsController.dispose();
    _stationController.dispose();
    _globalModifierController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
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
          return Center(
            child: Text('Database Error: ${stationSnapshot.error}'),
          );
        }
        if (!stationSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stations = stationSnapshot.data ?? [];
        if (stations.isNotEmpty &&
            (_selectedStation == null ||
                !stations.any((s) => s.name == _selectedStation))) {
          _selectedStation = stations.first.name;
        }

        final initialTab = ref.watch(libraryTabIndexProvider);

        return DefaultTabController(
          length: 4,
          initialIndex: initialTab,
          key: ValueKey('library_tab_$initialTab'),
          child: Column(
            children: [
              TabBar(
                onTap: (index) =>
                    ref.read(libraryTabIndexProvider.notifier).state = index,
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.onSurface,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                dividerColor: theme.dividerColor,
                tabs: const [
                  Tab(text: 'ITEMS'),
                  Tab(text: 'STATIONS'),
                  Tab(text: 'MODIFIERS'),
                  Tab(text: 'BACKUP'),
                ],
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

  Widget _buildItemsTab(
    KDSDatabase db,
    ThemeData theme,
    List<StationData> stations,
  ) {
    return StreamBuilder<List<MenuItemData>>(
      stream: db.select(db.menuItems).watch(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'NEW MENU ITEM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Color(0xFF666666),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _nameController,
                        'Item Name',
                        hint: 'e.g. Smash Burger',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _priceController,
                        'Price',
                        hint: '0.00',
                        prefix: r'$',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _modifiersController,
                        'Available Modifiers',
                        hint: 'Bacon, Cheese, Egg',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _requiredModifiersController,
                        'Required Modifiers',
                        hint: 'Rare, Medium, Well',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _tagsController,
                        'Tags (for menu filters)',
                        hint: 'Gluten Free, Spicy, Chef Special',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _categoryController,
                        'Category',
                        hint: 'e.g. Burgers, Sides, Drinks',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStation,
                        decoration: _inputDecoration('Routing Station'),
                        items: stations
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.name,
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStation = val),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          title: const Text(
                            'TRACK INVENTORY',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          value: _trackStock,
                          onChanged: (val) => setState(() => _trackStock = val),
                          activeThumbColor: const Color(0xFF111111),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      if (_trackStock) ...[
                        const SizedBox(height: 8),
                        _buildTextField(
                          _stockController,
                          'Current Stock',
                          keyboard: TextInputType.number,
                        ),
                      ],
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          title: const Text(
                            'ONE TOUCH ADD',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          subtitle: const Text(
                            'Adds to ticket instantly on tap (skips modifier screen).',
                            style: TextStyle(fontSize: 10),
                          ),
                          value: _oneTouch,
                          onChanged: (val) => setState(() => _oneTouch = val),
                          activeThumbColor: const Color(0xFF2563EB),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (_nameController.text.isNotEmpty &&
                              _selectedStation != null) {
                            final mods = _modifiersController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final reqs = _requiredModifiersController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final tags = _tagsController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            await db
                                .into(db.menuItems)
                                .insert(
                                  MenuItemsCompanion.insert(
                                    guid: drift.Value(const Uuid().v4()),
                                    name: _nameController.text,
                                    category: _categoryController.text.isEmpty
                                        ? 'All Items'
                                        : _categoryController.text.trim(),
                                    defaultStation: _selectedStation!,
                                    modifiers: mods,
                                    requiredModifiers: drift.Value(reqs),
                                    tags: drift.Value(tags),
                                    price: drift.Value(
                                      double.tryParse(_priceController.text) ??
                                          0.0,
                                    ),
                                    stockQuantity: drift.Value(
                                      int.tryParse(_stockController.text) ?? 0,
                                    ),
                                    trackStock: drift.Value(_trackStock),
                                    oneTouch: drift.Value(_oneTouch),
                                    updatedAtMs: drift.Value(
                                      DateTime.now().millisecondsSinceEpoch,
                                    ),
                                  ),
                                );
                            _nameController.clear();
                            _modifiersController.clear();
                            _requiredModifiersController.clear();
                            _tagsController.clear();
                            _priceController.clear();
                            _stockController.clear();
                            _categoryController.text = 'All Items';
                            setState(() {
                              _trackStock = false;
                              _oneTouch = false;
                            });
                          }
                        },
                        child: const Text(
                          'SAVE TO LIBRARY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  return Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.name.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildTag(
                                    item.defaultStation.toUpperCase(),
                                    const Color(0xFFF3F4F6),
                                    const Color(0xFF666666),
                                  ),
                                  if (item.trackStock)
                                    _buildTag(
                                      'STOCK: ${item.stockQuantity}',
                                      const Color(0xFFFFF7ED),
                                      const Color(0xFFC2410C),
                                    ),
                                  if (item.oneTouch)
                                    _buildTag(
                                      'ONE TOUCH',
                                      const Color(0xFFEFF6FF),
                                      const Color(0xFF2563EB),
                                    ),
                                  ...item.tags.map(
                                    (t) => _buildTag(
                                      t,
                                      const Color(0xFFEFF6FF),
                                      const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                              if ((item.requiredModifiers ?? []).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'REQUIRED: ${(item.requiredModifiers ?? []).join(", ")}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: MenuAnchor(
                          builder: (context, controller, child) => IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onPressed: () => controller.isOpen
                                ? controller.close()
                                : controller.open(),
                          ),
                          menuChildren: [
                            MenuItemButton(
                              onPressed: () => _showEditItemDialog(
                                context,
                                db,
                                item,
                                stations,
                              ),
                              leadingIcon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                              ),
                              child: const Text(
                                'EDIT ITEM',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            MenuItemButton(
                              onPressed: () => (db.delete(
                                db.menuItems,
                              )..where((t) => t.id.equals(item.id))).go(),
                              leadingIcon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              child: const Text(
                                'DELETE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: items.length),
              ),
            ),
          ],
        );
      },
    );
  }

  // Common UI Helper for refined tags
  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textCol,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Refined Input Styling
  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: Color(0xFF666666),
      ),
      floatingLabelStyle: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Color(0xFF111111),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    String? prefix,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      decoration: _inputDecoration(label, hint: hint, prefix: prefix),
    );
  }

  Widget _buildStationsTab(
    KDSDatabase db,
    ThemeData theme,
    List<StationData> stations,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'NEW STATION',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Color(0xFF666666),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _stationController,
                    'Station Name',
                    hint: 'e.g. Grill',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      if (_stationController.text.isNotEmpty) {
                        await db
                            .into(db.stations)
                            .insert(
                              StationsCompanion.insert(
                                name: _stationController.text.trim(),
                                updatedAtMs: drift.Value(
                                  DateTime.now().millisecondsSinceEpoch,
                                ),
                              ),
                            );
                        _stationController.clear();
                      }
                    },
                    child: const Text(
                      'CREATE STATION',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final station = stations[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: ListTile(
                      title: Text(
                        station.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                _showEditStationDialog(context, db, station),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => (db.delete(
                              db.stations,
                            )..where((t) => t.id.equals(station.id))).go(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: stations.length),
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
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'NEW GLOBAL MODIFIER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Color(0xFF666666),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _globalModifierController,
                  'Modifier Name',
                  hint: 'e.g. Extra Sauce',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (_globalModifierController.text.isNotEmpty) {
                      await db
                          .into(db.globalModifiers)
                          .insert(
                            GlobalModifiersCompanion.insert(
                              name: _globalModifierController.text.trim(),
                              updatedAtMs: drift.Value(
                                DateTime.now().millisecondsSinceEpoch,
                              ),
                            ),
                          );
                      _globalModifierController.clear();
                    }
                  },
                  child: const Text(
                    'SAVE MODIFIER',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GlobalModifierData>>(
            stream: db.select(db.globalModifiers).watch(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final mods = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mods.length,
                itemBuilder: (context, index) {
                  final mod = mods[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: ListTile(
                          title: Text(
                            mod.name.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => (db.delete(
                              db.globalModifiers,
                            )..where((t) => t.id.equals(mod.id))).go(),
                          ),
                        ),
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

  Widget _buildBackupTab(KDSDatabase db, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'SYSTEM BACKUP',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: Color(0xFF666666),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.download_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text(
                    'EXPORT LIBRARY',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Backup menu, stations, and modifiers',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () => _exportLibrary(db),
                ),
                Divider(height: 1, color: theme.dividerColor),
                ListTile(
                  leading: const Icon(
                    Icons.upload_rounded,
                    color: Color(0xFF22C55E),
                  ),
                  title: const Text(
                    'IMPORT LIBRARY',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Restore from a backup file',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () => _importLibrary(db),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'DANGER ZONE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: Color(0xFFDC2626),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
              ),
              title: const Text(
                'CLEAR ALL LIBRARY DATA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                ),
              ),
              subtitle: const Text(
                'Wipe all items, stations, and modifiers',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () => _showResetLibraryConfirmation(db),
            ),
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
        'menuItems': items
            .map(
              (i) => {
                'guid': i.guid,
                'name': i.name,
                'category': i.category,
                'defaultStation': i.defaultStation,
                'modifiers': i.modifiers,
                'requiredModifiers': i.requiredModifiers,
                'tags': i.tags,
                'price': i.price,
                'stockQuantity': i.stockQuantity,
                'trackStock': i.trackStock,
                'oneTouch': i.oneTouch,
              },
            )
            .toList(),
        'stations': stations.map((s) => {'name': s.name}).toList(),
        'globalModifiers': modifiers.map((m) => {'name': m.name}).toList(),
      };
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/dartkds_backup.json');
      await file.writeAsString(jsonEncode(data));
      await Share.shareXFiles([XFile(file.path)], text: 'DartKDS Backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importLibrary(KDSDatabase db) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final confirmation = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'IMPORT LIBRARY',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will merge the backup data with your current library. Existing items with the same name will be updated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'PROCEED',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

      if (confirmation != true) return;

      final fileContent = await File(result.files.single.path!).readAsString();
      final data = jsonDecode(fileContent) as Map<String, dynamic>;

      if (data['menuItems'] == null) throw Exception('Invalid backup file');

      await db.transaction(() async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Import Stations
        if (data['stations'] != null) {
          for (var s in data['stations']) {
            await db
                .into(db.stations)
                .insertOnConflictUpdate(
                  StationsCompanion.insert(
                    name: s['name'],
                    updatedAtMs: drift.Value(nowMs),
                  ),
                );
          }
        }

        // Import Global Modifiers
        if (data['globalModifiers'] != null) {
          for (var m in data['globalModifiers']) {
            await db
                .into(db.globalModifiers)
                .insertOnConflictUpdate(
                  GlobalModifiersCompanion.insert(
                    name: m['name'],
                    updatedAtMs: drift.Value(nowMs),
                  ),
                );
          }
        }

        // Import Menu Items (Merge by name)
        final existingItems = await db.select(db.menuItems).get();
        for (var i in data['menuItems']) {
          final String name = i['name'] ?? 'Unknown Item';
          final String guid = i['guid'] ?? const Uuid().v4();

          final existing = existingItems
              .where((e) => e.name == name)
              .firstOrNull;

          final companion = MenuItemsCompanion(
            guid: drift.Value(guid),
            name: drift.Value(name),
            category: drift.Value(i['category'] ?? 'All Items'),
            defaultStation: drift.Value(i['defaultStation'] ?? 'Main Station'),
            modifiers: drift.Value(List<String>.from(i['modifiers'] ?? [])),
            requiredModifiers: drift.Value(
              List<String>.from(i['requiredModifiers'] ?? []),
            ),
            tags: drift.Value(List<String>.from(i['tags'] ?? [])),
            price: drift.Value((i['price'] as num?)?.toDouble() ?? 0.0),
            stockQuantity: drift.Value(i['stockQuantity'] ?? 0),
            trackStock: drift.Value(i['trackStock'] ?? false),
            oneTouch: drift.Value(i['oneTouch'] ?? false),
            updatedAtMs: drift.Value(nowMs),
          );

          if (existing != null) {
            await (db.update(
              db.menuItems,
            )..where((t) => t.id.equals(existing.id))).write(companion);
          } else {
            await db.into(db.menuItems).insert(companion);
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import Successful'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showResetLibraryConfirmation(KDSDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'CLEAR ALL LIBRARY DATA?',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
        ),
        content: const Text(
          'This will delete all Menu Items, Stations, and Global Modifiers. Order history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CLEAR ALL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.transaction(() async {
        await db.delete(db.menuItems).go();
        await db.delete(db.stations).go();
        await db.delete(db.globalModifiers).go();
        // Re-seed default station
        await db
            .into(db.stations)
            .insert(StationsCompanion.insert(name: 'Main Station'));
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Library Cleared')));
      }
    }
  }

  void _showEditStationDialog(
    BuildContext context,
    KDSDatabase db,
    StationData station,
  ) {
    final controller = TextEditingController(text: station.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: const Text(
          'EDIT STATION',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          decoration: _inputDecoration('Station Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF666666),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await (db.update(
                  db.stations,
                )..where((t) => t.id.equals(station.id))).write(
                  StationsCompanion(
                    name: drift.Value(controller.text.trim()),
                    updatedAtMs: drift.Value(
                      DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
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

  void _showEditItemDialog(
    BuildContext context,
    KDSDatabase db,
    MenuItemData item,
    List<StationData> stations,
  ) {
    final nameCtrl = TextEditingController(text: item.name);
    final modCtrl = TextEditingController(text: item.modifiers.join(', '));
    final reqModCtrl = TextEditingController(
      text: (item.requiredModifiers ?? []).join(', '),
    );
    final tagsCtrl = TextEditingController(text: item.tags.join(', '));
    final categoryCtrl = TextEditingController(text: item.category);
    final priceCtrl = TextEditingController(text: item.price.toString());
    final stockCtrl = TextEditingController(
      text: item.stockQuantity.toString(),
    );
    bool trackStock = item.trackStock;
    bool oneTouch = item.oneTouch;
    String selectedStation = item.defaultStation;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          title: const Text(
            'EDIT MENU ITEM',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, 'Item Name'),
                const SizedBox(height: 12),
                _buildTextField(
                  priceCtrl,
                  'Price',
                  prefix: r'$',
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildTextField(modCtrl, 'Available Modifiers'),
                const SizedBox(height: 12),
                _buildTextField(reqModCtrl, 'Required Modifiers'),
                const SizedBox(height: 12),
                _buildTextField(tagsCtrl, 'Tags (for menu filters)'),
                const SizedBox(height: 12),
                _buildTextField(categoryCtrl, 'Category'),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'TRACK INVENTORY',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  value: trackStock,
                  onChanged: (val) => setDialogState(() => trackStock = val),
                  contentPadding: EdgeInsets.zero,
                ),
                if (trackStock)
                  _buildTextField(
                    stockCtrl,
                    'Current Stock',
                    keyboard: TextInputType.number,
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'ONE TOUCH ADD',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  subtitle: const Text(
                    'Adds to ticket instantly on tap (skips modifier screen).',
                    style: TextStyle(fontSize: 10),
                  ),
                  value: oneTouch,
                  onChanged: (val) => setDialogState(() => oneTouch = val),
                  activeThumbColor: const Color(0xFF2563EB),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: stations.any((s) => s.name == selectedStation)
                      ? selectedStation
                      : (stations.isNotEmpty ? stations.first.name : null),
                  decoration: _inputDecoration('Station'),
                  items: stations
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.name,
                          child: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedStation = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF666666),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final tags = tagsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  await (db.update(
                    db.menuItems,
                  )..where((t) => t.id.equals(item.id))).write(
                    MenuItemsCompanion(
                      name: drift.Value(nameCtrl.text.trim()),
                      category: drift.Value(
                        categoryCtrl.text.isEmpty
                            ? 'All Items'
                            : categoryCtrl.text.trim(),
                      ),
                      defaultStation: drift.Value(selectedStation),
                      modifiers: drift.Value(
                        modCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
                      requiredModifiers: drift.Value(
                        reqModCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                      ),
                      tags: drift.Value(tags),
                      price: drift.Value(
                        double.tryParse(priceCtrl.text) ?? 0.0,
                      ),
                      stockQuantity: drift.Value(
                        int.tryParse(stockCtrl.text) ?? 0,
                      ),
                      trackStock: drift.Value(trackStock),
                      oneTouch: drift.Value(oneTouch),
                      updatedAtMs: drift.Value(
                        DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('SAVE CHANGES'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
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
import '../../shared/responsive_utils.dart';

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
  bool _filtersExpanded = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  int _calcColumns(double width) {
    if (width < 400) return 3;
    if (width < 700) return 4;
    if (width < 1000) return 5;
    if (width < 1300) return 6;
    return 7;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet =
        Responsive.isTablet(context) || Responsive.isDesktop(context);
    final theme = Theme.of(context);
    final intakeState = ref.watch(intakeProvider);

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: RepaintBoundary(child: _buildMenuSection(context)),
            ),
            if (isTablet && intakeState.items.isNotEmpty)
              Container(
                width: 360,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: theme.dividerColor, width: 2),
                  ),
                ),
                child: RepaintBoundary(
                  child: _buildOrderSummarySection(context, isSidePanel: true),
                ),
              ),
          ],
        ),
        if (!isTablet && intakeState.items.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: _buildOrderSummarySection(context, isSidePanel: false),
            ),
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
              colors: const [
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.red,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        _buildOpenTabsBar(context),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      setState(() => _searchQuery = val.toLowerCase());
                    },
                  );
                },
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search menu...',
                  hintStyle: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: theme.hintColor,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 14, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Text(
                        _filtersExpanded ? 'HIDE FILTERS' : 'FILTERS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.hintColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!_filtersExpanded &&
                          (_selectedCategory != 'ALL' ||
                              _selectedTag != 'ALL')) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$_selectedCategory${_selectedTag != 'ALL' ? ' · $_selectedTag' : ''}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        _filtersExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: theme.hintColor,
                      ),
                    ],
                  ),
                ),
              ),
              if (_filtersExpanded) ...[
                const SizedBox(height: 8),
                _buildFilterChipRow(
                  stream: db.select(db.menuItems).watch().map((items) {
                    final cats = items
                        .map((i) => i.category.trim().toUpperCase())
                        .where(
                          (c) => c.isNotEmpty && c != 'ALL' && c != 'ALL ITEMS',
                        )
                        .toSet();
                    return ['ALL', ...cats];
                  }),
                  selected: _selectedCategory,
                  onSelected: (c) => setState(() => _selectedCategory = c),
                ),
                const SizedBox(height: 8),
                _buildFilterChipRow(
                  stream: db.select(db.menuItems).watch().map((items) {
                    final tags = items
                        .expand((i) => i.tags)
                        .map((t) => t.trim().toUpperCase())
                        .where((t) => t.isNotEmpty && t != 'ALL')
                        .toSet();
                    return ['ALL', ...tags];
                  }),
                  selected: _selectedTag,
                  onSelected: (t) => setState(() => _selectedTag = t),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MenuItemData>>(
            stream: db.select(db.menuItems).watch(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var items = snapshot.data!;
              if (_selectedCategory != 'ALL') {
                items = items
                    .where((i) => i.category.toUpperCase() == _selectedCategory)
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                items = items
                    .where((i) => i.name.toLowerCase().contains(_searchQuery))
                    .toList();
              }
              if (_selectedTag != 'ALL') {
                items = items
                    .where(
                      (i) => i.tags.any((t) => t.toUpperCase() == _selectedTag),
                    )
                    .toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No items found',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = _calcColumns(constraints.maxWidth);
                  return GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isOut = item.trackStock && item.stockQuantity <= 0;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: isOut
                              ? theme.dividerColor.withValues(alpha: 0.2)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: isOut
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    _handleItemTap(context, ref, item);
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isOut
                                      ? Colors.transparent
                                      : theme.dividerColor,
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isOut
                                          ? theme.hintColor
                                          : theme.textTheme.bodyLarge?.color,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  if (item.oneTouch || item.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        [
                                          if (item.oneTouch) '⚡ QUICK',
                                          ...item.tags
                                              .take(1)
                                              .map((t) => t.toUpperCase()),
                                        ].join(' • '),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: isOut
                                              ? theme.hintColor
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                      if (item.trackStock)
                                        Text(
                                          isOut
                                              ? 'OUT'
                                              : '${item.stockQuantity}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: isOut
                                                ? Colors.red
                                                : theme.hintColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpenTabsBar(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final intakeState = ref.watch(intakeProvider);
    final theme = Theme.of(context);

    return StreamBuilder<List<KDSOrderData>>(
      stream:
          (db.select(db.kDSOrders)
                ..where((t) => t.status.isNotIn([OrderStatus.complete.index]))
                ..orderBy([(t) => drift.OrderingTerm.desc(t.timestamp)]))
              .watch(),
      builder: (context, snapshot) {
        final openOrders = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_bar_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'OPEN BAR TABS (${openOrders.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _promptNewTabName(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'NEW TAB',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected:
                            intakeState.editingOrderUuid == null &&
                            intakeState.customerName.isEmpty &&
                            intakeState.items.isEmpty,
                        selectedColor: theme.colorScheme.primary.withValues(
                          alpha: 0.2,
                        ),
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'QUICK ORDER',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        onSelected: (_) {
                          ref.read(intakeProvider.notifier).clear();
                        },
                      ),
                    ),
                    ...openOrders.map((order) {
                      final isSelected =
                          intakeState.editingOrderUuid == order.uuid;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StreamBuilder<List<KDSItemData>>(
                          stream:
                              (db.select(db.kDSItems)..where(
                                    (t) => t.orderUuid.equals(order.uuid),
                                  ))
                                  .watch(),
                          builder: (context, itemSnap) {
                            final items = itemSnap.data ?? [];
                            final orderTotal = items.fold<double>(
                              0,
                              (s, i) => s + i.price,
                            );

                            return ChoiceChip(
                              selected: isSelected,
                              selectedColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                              side: isSelected
                                  ? BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🍺 ',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${order.customerName.toUpperCase()} · \$${orderTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      fontSize: 11,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ],
                              ),
                              onSelected: (_) =>
                                  _selectOpenTab(context, ref, db, order),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptNewTabName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.local_bar_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text(
              'START BAR TAB',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'TAB / GUEST / TABLE NAME',
                hintText: 'e.g. Alex, Table 4, Bar 2',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  [
                    'BAR 1',
                    'BAR 2',
                    'BAR 3',
                    'TABLE 1',
                    'TABLE 2',
                    'TABLE 3',
                  ].map((label) {
                    return ActionChip(
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        controller.text = label;
                      },
                    );
                  }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OPEN TAB'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      ref.read(intakeProvider.notifier).clear();
      ref.read(intakeProvider.notifier).setCustomerName(name);
    }
  }

  Future<void> _selectOpenTab(
    BuildContext context,
    WidgetRef ref,
    KDSDatabase db,
    KDSOrderData order,
  ) async {
    final items = await (db.select(
      db.kDSItems,
    )..where((t) => t.orderUuid.equals(order.uuid))).get();
    final allMenuItems = await db.select(db.menuItems).get();

    final List<IntakeItem> intakeItems = [];
    for (final item in items) {
      final menuItem = allMenuItems.firstWhere(
        (m) => m.name == item.name,
        orElse: () => MenuItemData(
          id: -1,
          guid: '',
          name: item.name,
          category: 'Bar',
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
  }

  Widget _buildOrderSummarySection(
    BuildContext context, {
    required bool isSidePanel,
  }) {
    final intakeState = ref.watch(intakeProvider);
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    double totalPrice = 0;
    for (var item in intakeState.items) {
      totalPrice += item.menuItem.price * item.quantity;
    }

    final isEditingTab = intakeState.editingOrderUuid != null;
    final tabName = intakeState.customerName.isEmpty
        ? 'GUEST'
        : intakeState.customerName.toUpperCase();

    final panelContent = Material(
      color: theme.cardColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isEditingTab
                  ? const Color(0xFFFACC15).withValues(alpha: 0.12)
                  : theme.dividerColor.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_bar_rounded,
                  size: 16,
                  color: isEditingTab
                      ? const Color(0xFFD97706)
                      : theme.hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller:
                        TextEditingController(text: intakeState.customerName)
                          ..selection = TextSelection.collapsed(
                            offset: intakeState.customerName.length,
                          ),
                    onChanged: (val) =>
                        ref.read(intakeProvider.notifier).setCustomerName(val),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'TAB / GUEST NAME',
                      hintStyle: TextStyle(
                        color: theme.hintColor,
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (isEditingTab)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OPEN TAB',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ITEMS ON TAB (${intakeState.items.length})',
                  style: theme.textTheme.labelLarge,
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          'CLEAR TICKET?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        content: const Text(
                          'This will clear items from the current view.',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(intakeProvider.notifier).clear();
                            },
                            child: const Text(
                              'CLEAR',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'CLEAR',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: intakeState.items.length,
              separatorBuilder: (context, index) =>
                  Divider(color: theme.dividerColor, height: 1),
              itemBuilder: (context, index) {
                final item = intakeState.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: Text(
                    '${item.quantity}×',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  title: Text(
                    item.menuItem.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: item.selectedModifiers.isNotEmpty
                      ? Text(
                          item.selectedModifiers.join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666666),
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${(item.menuItem.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            ref.read(intakeProvider.notifier).removeItem(index),
                      ),
                    ],
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
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: intakeState.items.isEmpty
                              ? theme.dividerColor
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          isEditingTab ? 'SEND ROUND' : 'OPEN TAB & SEND',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: intakeState.items.isEmpty
                            ? null
                            : () =>
                                  _sendToKitchen(context, ref, closeTab: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: intakeState.items.isEmpty
                              ? theme.dividerColor
                              : const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                        label: const Text(
                          'PAY & CLOSE TAB',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: intakeState.items.isEmpty
                            ? null
                            : () =>
                                  _showPaymentDialog(context, ref, totalPrice),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isSidePanel) {
      return panelContent;
    } else {
      final bottomHeight = (screenHeight * 0.4).clamp(200.0, 340.0);
      return Container(
        height: bottomHeight,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
          border: Border(top: BorderSide(color: theme.dividerColor, width: 2)),
        ),
        child: panelContent,
      );
    }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, double total) {
    final controller = TextEditingController();
    double received = 0;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final change = (received - total).clamp(0.0, 999999.0);
          final isShort = received > 0 && received < total;

          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            title: const Text(
              'PAYMENT & CLOSE TAB',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL DUE',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'CASH RECEIVED',
                      labelStyle: const TextStyle(fontSize: 12),
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        received = double.tryParse(val) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (received > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isShort
                            ? Colors.orange.withValues(alpha: 0.1)
                            : const Color(0xFF22C55E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isShort
                              ? Colors.orange
                              : const Color(0xFF22C55E),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isShort ? 'REMAINING:' : 'CHANGE DUE:',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '\$${(isShort ? total - received : change).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isShort
                                  ? Colors.orange
                                  : const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [5, 10, 20, 50, 100].map((amt) {
                      return ActionChip(
                        label: Text('\$$amt'),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                        onPressed: () {
                          controller.text = amt.toString();
                          setState(() => received = amt.toDouble());
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      controller.text = total.toStringAsFixed(2);
                      setState(() => received = total);
                    },
                    child: const Text(
                      'EXACT CHANGE',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _sendToKitchen(context, ref, closeTab: true);
                },
                child: const Text('SETTLE & CLOSE TAB'),
              ),
            ],
          );
        },
      ),
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
                    color: isSelected
                        ? const Color(0xFF111111)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF111111)
                          : theme.dividerColor,
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
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
    final hasModifiers =
        item.modifiers.isNotEmpty || (item.requiredModifiers ?? []).isNotEmpty;
    if (!hasModifiers || item.oneTouch) {
      ref.read(intakeProvider.notifier).addItem(item);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to Tab: ${item.name}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF111111),
        ),
      );
      return;
    }
    _showModifierDialog(context, ref, item);
  }

  void _showModifierDialog(
    BuildContext context,
    WidgetRef ref,
    MenuItemData item, {
    int? editIndex,
    List<String>? initialSelected,
    int initialQuantity = 1,
  }) {
    List<String> selected = List.from(initialSelected ?? []);
    int quantity = initialQuantity;
    final db = ref.read(databaseProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
            StreamBuilder<List<GlobalModifierData>>(
              stream: db.select(db.globalModifiers).watch(),
              builder: (context, snapshot) {
                final globals = snapshot.data ?? [];
                final requiredMods = item.requiredModifiers ?? [];
                final allModifiers = {
                  ...requiredMods,
                  ...item.modifiers,
                  ...globals.map((g) => g.name),
                }.toList();
                bool isRequirementMet =
                    requiredMods.isEmpty ||
                    selected.any((s) => requiredMods.contains(s));

                return AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (requiredMods.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'REQUIREMENT: SELECT ONE (${requiredMods.join(", ")})',
                            style: TextStyle(
                              fontSize: 10,
                              color: isRequirementMet
                                  ? const Color(0xFF22C55E)
                                  : Colors.red,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUANTITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF666666),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: quantity > 1
                                      ? () => setDialogState(() => quantity--)
                                      : null,
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed:
                                      (item.trackStock &&
                                          quantity >= item.stockQuantity)
                                      ? null
                                      : () => setDialogState(() => quantity++),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'MODIFIERS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF666666),
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            if (requiredMods.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SELECTION REQUIRED',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
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
                              onSelected: (val) => setDialogState(
                                () => val
                                    ? selected.add(mod)
                                    : selected.remove(mod),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isReq && !isSelected
                                      ? Colors.red
                                      : (isSelected
                                            ? Colors.transparent
                                            : Theme.of(context).dividerColor),
                                  width: isReq && !isSelected ? 1.5 : 1,
                                ),
                              ),
                              backgroundColor: Colors.transparent,
                              selectedColor: const Color(0xFF111111),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isReq
                                          ? Colors.red.shade700
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color),
                                fontWeight: (isSelected || isReq)
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 12,
                              ),
                              showCheckmark: false,
                            );
                          }).toList(),
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
                        backgroundColor: isRequirementMet
                            ? const Color(0xFF111111)
                            : Theme.of(context).dividerColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isRequirementMet
                          ? () {
                              if (editIndex != null) {
                                ref
                                    .read(intakeProvider.notifier)
                                    .updateItem(
                                      editIndex,
                                      modifiers: selected,
                                      quantity: quantity,
                                    );
                              } else {
                                ref
                                    .read(intakeProvider.notifier)
                                    .addItem(
                                      item,
                                      selectedModifiers: selected,
                                      quantity: quantity,
                                    );
                              }
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        editIndex != null ? 'SAVE CHANGES' : 'ADD TO TAB',
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  Future<void> _sendToKitchen(
    BuildContext context,
    WidgetRef ref, {
    bool closeTab = false,
  }) async {
    HapticFeedback.heavyImpact();
    final state = ref.read(intakeProvider);
    final db = ref.read(databaseProvider);
    final server = ref.read(hostServerProvider);

    final isEditing = state.editingOrderUuid != null;
    final orderUuid = state.editingOrderUuid ?? const Uuid().v4();
    final timestamp = DateTime.now();
    final finalStatus = closeTab ? OrderStatus.complete : OrderStatus.pending;
    final tabName = state.customerName.isEmpty ? 'Guest' : state.customerName;

    if (isEditing) {
      final oldItems = await (db.select(
        db.kDSItems,
      )..where((t) => t.orderUuid.equals(orderUuid))).get();
      for (final oldItem in oldItems) {
        final menuMatches = await (db.select(
          db.menuItems,
        )..where((t) => t.name.equals(oldItem.name))).get();
        if (menuMatches.isNotEmpty && menuMatches.first.trackStock) {
          await (db.update(
            db.menuItems,
          )..where((t) => t.id.equals(menuMatches.first.id))).write(
            MenuItemsCompanion(
              stockQuantity: drift.Value(menuMatches.first.stockQuantity + 1),
              updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
      }
      await (db.delete(
        db.kDSItems,
      )..where((t) => t.orderUuid.equals(orderUuid))).go();
      await (db.update(
        db.kDSOrders,
      )..where((t) => t.uuid.equals(orderUuid))).write(
        KDSOrdersCompanion(
          customerName: drift.Value(tabName),
          timestamp: drift.Value(timestamp),
          status: drift.Value(finalStatus),
          updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    } else {
      await db
          .into(db.kDSOrders)
          .insert(
            KDSOrderData(
              uuid: orderUuid,
              customerName: tabName,
              timestamp: timestamp,
              status: finalStatus,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }

    final List<Map<String, dynamic>> jsonItems = [];
    for (final item in state.items) {
      if (item.menuItem.trackStock) {
        final fresh = await (db.select(
          db.menuItems,
        )..where((t) => t.id.equals(item.menuItem.id))).getSingle();
        await (db.update(
          db.menuItems,
        )..where((t) => t.id.equals(item.menuItem.id))).write(
          MenuItemsCompanion(
            stockQuantity: drift.Value(fresh.stockQuantity - item.quantity),
            updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
      for (int i = 0; i < item.quantity; i++) {
        final itemUuid = const Uuid().v4();
        await db
            .into(db.kDSItems)
            .insert(
              KDSItemsCompanion.insert(
                uuid: itemUuid,
                orderUuid: orderUuid,
                name: item.menuItem.name,
                modifiers: item.selectedModifiers,
                stationTag: item.menuItem.defaultStation,
                status: ItemStatus.pending,
                price: drift.Value(item.menuItem.price),
                updatedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
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
      'type': closeTab
          ? 'TicketFinished'
          : (isEditing ? 'OrderUpdated' : 'OrderCreated'),
      'orderUuid': orderUuid,
      'order': {
        'uuid': orderUuid,
        'customerName': tabName,
        'timestamp': timestamp.toIso8601String(),
        'status': finalStatus.index,
        'items': jsonItems,
      },
    });

    server.broadcast(broadcastPayload);
    ref.read(intakeProvider.notifier).clear();

    if (ref.read(settingsProvider).enableConfetti) {
      _confettiController.play();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          closeTab
              ? 'Tab "$tabName" Closed & Paid!'
              : (isEditing
                    ? 'Tab "$tabName" Updated!'
                    : 'Round Sent for Tab "$tabName"!'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: closeTab
            ? const Color(0xFF16A34A)
            : const Color(0xFF111111),
      ),
    );
  }
}

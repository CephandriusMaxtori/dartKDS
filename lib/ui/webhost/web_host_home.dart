import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/web_host_providers.dart';
import '../../providers/app_state_providers.dart';
import '../../services/web_host_client.dart';

const _kBlue = Color(0xFF2563EB);
const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFFACC15);
const _kRed = Color(0xFFEF4444);
const _kPurple = Color(0xFF7C3AED);

/// Full host UI running in the browser. Connects back to the native host that
/// served this page over WebSocket, mirrors its database state via
/// [webHostSnapshotProvider], and executes all writes on the native host.
class WebHostHome extends ConsumerStatefulWidget {
  const WebHostHome({super.key});

  @override
  ConsumerState<WebHostHome> createState() => _WebHostHomeState();
}

class _WebHostHomeState extends ConsumerState<WebHostHome>
    with SingleTickerProviderStateMixin {
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    final bridge = ref.read(webHostBridgeProvider);
    try {
      await bridge.connect(role: ref.read(hostIdentityProvider).role);
    } catch (_) {}
  }

  Future<void> _reconnect() async {
    _retryTimer?.cancel();
    try {
      await ref
          .read(webHostBridgeProvider)
          .connect(role: ref.read(hostIdentityProvider).role);
    } catch (_) {
      _retryTimer = Timer(const Duration(seconds: 5), _reconnect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(webHostStatusProvider).valueOrNull;
    final tab = ref.watch(webHostTabIndexProvider);
    final hostRole = ref.watch(hostIdentityProvider).role;

    final connected = status == WebHostStatus.connected;
    final connecting = status == WebHostStatus.connecting;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('DARTKDS'),
            const SizedBox(width: 6),
            Text(
              'WEB HOST',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (hostRole == HostRole.backup ? _kPurple : _kBlue)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                hostRole == HostRole.backup ? 'BACKUP' : 'PRIMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: hostRole == HostRole.backup ? _kPurple : _kBlue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch device role',
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            onPressed: () {
              ref.read(webHostBridgeProvider).disconnect();
              ref.read(deviceRoleProvider.notifier).setRole(DeviceRole.unset);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (connected
                              ? _kGreen
                              : connecting
                              ? _kAmber
                              : _kRed)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? _kGreen
                            : connecting
                            ? _kAmber
                            : _kRed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected
                          ? 'CONNECTED'
                          : connecting
                          ? 'CONNECTING…'
                          : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: connected
                            ? _kGreen
                            : connecting
                            ? _kAmber
                            : _kRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: !connected
          ? _buildOffline(status)
          : IndexedStack(
              index: tab,
              children: const [
                _IntakeTab(),
                _SentQueueTab(),
                _InventoryTab(),
                _LibraryTab(),
                _ClientsTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => ref.read(webHostTabIndexProvider.notifier).state = i,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'INTAKE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'SENT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'STOCK',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'LIBRARY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices_rounded),
            label: 'CLIENTS',
          ),
        ],
      ),
    );
  }

  Widget _buildOffline(WebHostStatus? status) {
    final connecting = status == WebHostStatus.connecting;
    final failed = status == WebHostStatus.error;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: (failed ? _kRed : _kAmber).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              failed ? Icons.error_rounded : Icons.sync_rounded,
              size: 40,
              color: failed ? _kRed : _kAmber,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            connecting
                ? 'CONNECTING TO HOST…'
                : failed
                ? 'CONNECTION FAILED'
                : 'HOST OFFLINE',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting back to ${Uri.base.host}:8080',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _reconnect,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('RECONNECT'),
          ),
        ],
      ),
    );
  }
}

// ── Shared pieces ──────────────────────────────────────────────

Color _statusColor(int status) {
  switch (status) {
    case 1:
      return _kAmber;
    case 2:
      return const Color(0xFF84CC16);
    case 3:
      return _kGreen;
    default:
      return const Color(0xFF9CA3AF);
  }
}

Widget _chip(String text, {Color color = const Color(0xFF9CA3AF)}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 10,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
      ],
    ),
  );
}

// ── ORDER INTAKE ──────────────────────────────────────────────

class _IntakeTab extends ConsumerStatefulWidget {
  const _IntakeTab();
  @override
  ConsumerState<_IntakeTab> createState() => _IntakeTabState();
}

class _CartLine {
  final WHMenuItem menuItem;
  int quantity = 1;
  List<String> selectedModifiers;
  _CartLine(this.menuItem, this.selectedModifiers);
}

class _IntakeTabState extends ConsumerState<_IntakeTab> {
  final _cart = <_CartLine>[];
  final _searchCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  String? _category;
  String _editingOrderUuid = '';

  @override
  void initState() {
    super.initState();
    // Prefill from an order selected for editing in the sent queue.
    final edit = ref.read(webHostEditOrderProvider);
    if (edit != null) {
      _loadOrderIntoCart(edit);
      ref.read(webHostEditOrderProvider.notifier).state = null;
    }
  }

  void _loadOrderIntoCart(WHOrder order) {
    final menu = ref.read(whMenuProvider);
    _editingOrderUuid = order.uuid;
    _customerCtrl.text = order.customerName;
    _cart.clear();
    for (final item in order.items) {
      final menuItem = menu.firstWhere(
        (m) => m.name == item.name,
        orElse: () => WHMenuItem(
          id: -1,
          guid: '',
          name: item.name,
          category: 'History',
          defaultStation: item.stationTag,
          modifiers: const [],
          requiredModifiers: const [],
          tags: const [],
          price: item.price,
          stockQuantity: 0,
          trackStock: false,
          oneTouch: false,
        ),
      );
      _cart.add(_CartLine(menuItem, item.modifiers));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem(WHMenuItem item) async {
    final modifiers = item.modifiers.toList();
    if (modifiers.isEmpty || item.oneTouch) {
      setState(() => _cart.add(_CartLine(item, const [])));
      return;
    }
    final selection = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ModifiersDialog(menuItem: item),
    );
    if (selection == null || !mounted) return;
    setState(() => _cart.add(_CartLine(item, selection)));
  }

  int get _subtotal => _cart.fold(
    0,
    (sum, l) => sum + (l.quantity * l.menuItem.price * 100).round(),
  );

  void _send() {
    final bridge = ref.read(webHostBridgeProvider);
    if (_cart.isEmpty) return;
    final items = <Map<String, dynamic>>[];
    for (final line in _cart) {
      for (var i = 0; i < line.quantity; i++) {
        items.add({
          'name': line.menuItem.name,
          'modifiers': line.selectedModifiers,
          'stationTag': line.menuItem.defaultStation,
          'price': line.menuItem.price,
        });
      }
    }
    if (_editingOrderUuid.isNotEmpty) {
      bridge.updateOrder(
        uuid: _editingOrderUuid,
        customerName: _customerCtrl.text.trim().isEmpty
            ? 'Guest'
            : _customerCtrl.text.trim(),
        items: items,
      );
    } else {
      bridge.createOrder(
        customerName: _customerCtrl.text.trim().isEmpty
            ? 'Guest'
            : _customerCtrl.text.trim(),
        items: items,
      );
    }
    setState(() {
      _cart.clear();
      _customerCtrl.clear();
      _editingOrderUuid = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ORDER SENT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(whMenuProvider);
    final categories = <String>[];
    for (final i in menu) {
      if (!categories.contains(i.category)) categories.add(i.category);
    }

    final search = _searchCtrl.text.trim().toLowerCase();
    final filtered = menu.where((i) {
      if (search.isNotEmpty &&
          !i.name.toLowerCase().contains(search) &&
          !i.category.toLowerCase().contains(search)) {
        return false;
      }
      if (_category != null && i.category != _category) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'SEARCH MENU…',
                  isDense: true,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _catChip(
                'All',
                _category == null,
                () => setState(() => _category = null),
                count: menu.length,
              ),
              for (final c in categories)
                _catChip(
                  c,
                  _category == c,
                  () => setState(() => _category = c),
                  count: menu.where((m) => m.category == c).length,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(
                  Icons.search_off_rounded,
                  'NO MATCHES',
                  'Try a different search or category',
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisExtent: 70,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final lowStock =
                            item.trackStock && item.stockQuantity <= 5;
                        return Material(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _addItem(item),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: lowStock
                                      ? _kRed.withValues(alpha: 0.5)
                                      : Theme.of(context).dividerColor,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.name.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)}'
                                        '  ·  ${item.defaultStation}'
                                        '${item.trackStock ? '  ·  STOCK ${item.stockQuantity}' : ''}'
                                        '${item.oneTouch ? '  ·  ⚡ ONE TOUCH' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: lowStock
                                              ? _kRed
                                              : item.oneTouch
                                              ? _kBlue
                                              : Theme.of(context).hintColor,
                                          fontWeight: lowStock
                                              ? FontWeight.w800
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.modifiers.isNotEmpty)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Icon(
                                        Icons.tune_rounded,
                                        size: 15,
                                        color: _kPurple.withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
        if (_cart.isNotEmpty) _buildCartBar(),
      ],
    );
  }

  Widget _catChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.black54 : Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildCartBar() {
    final editing = _editingOrderUuid.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      editing
                          ? Icons.edit_rounded
                          : Icons.shopping_cart_rounded,
                      size: 18,
                      color: editing ? _kBlue : Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      editing
                          ? 'EDITING #${_editingOrderUuid.substring(0, 4).toUpperCase()}'
                          : 'CURRENT ORDER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 12,
                        color: editing ? _kBlue : Theme.of(context).hintColor,
                      ),
                    ),
                    const Spacer(),
                    if (_cart.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _cart.clear();
                          if (editing) {
                            _editingOrderUuid = '';
                            _customerCtrl.clear();
                          }
                        }),
                        child: const Text('CLEAR'),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final line = _cart[i];
                      final lineTotal = line.quantity * line.menuItem.price;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.menuItem.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                if (line.selectedModifiers.isNotEmpty)
                                  Text(
                                    line.selectedModifiers.join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyBtn(
                                  Icons.remove_rounded,
                                  () => setState(() {
                                    if (--line.quantity <= 0) {
                                      _cart.remove(line);
                                    }
                                  }),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${line.quantity}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                _qtyBtn(
                                  Icons.add_rounded,
                                  () => setState(() => line.quantity++),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 72,
                            child: Text(
                              '\$${lineTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            visualDensity: VisualDensity.compact,
                            color: Theme.of(context).hintColor,
                            onPressed: () => setState(() => _cart.remove(line)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _customerCtrl,
                        decoration: const InputDecoration(
                          hintText: 'CUSTOMER NAME',
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${(_subtotal / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '${_cart.fold(0, (s, l) => s + l.quantity)} items',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _send,
                      icon: Icon(
                        editing ? Icons.save_rounded : Icons.send_rounded,
                        size: 18,
                      ),
                      label: Text(editing ? 'UPDATE ORDER' : 'SEND ORDER'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
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
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ModifiersDialog extends StatefulWidget {
  final WHMenuItem menuItem;
  const _ModifiersDialog({required this.menuItem});
  @override
  State<_ModifiersDialog> createState() => _ModifiersDialogState();
}

class _ModifiersDialogState extends State<_ModifiersDialog> {
  final _selected = <String>{};
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(
            widget.menuItem.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Icon(Icons.tune_rounded, size: 18, color: _kPurple),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT MODIFIERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in widget.menuItem.modifiers)
                  FilterChip(
                    label: Text(m),
                    selected: _selected.contains(m),
                    onSelected: (sel) => setState(
                      () => sel ? _selected.add(m) : _selected.remove(m),
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text(
            _selected.isEmpty
                ? 'ADD WITHOUT MODS'
                : 'ADD (${_selected.length})',
          ),
        ),
      ],
    );
  }
}

// ── SENT QUEUE ─────────────────────────────────────────────────

class _SentQueueTab extends ConsumerStatefulWidget {
  const _SentQueueTab();
  @override
  ConsumerState<_SentQueueTab> createState() => _SentQueueTabState();
}

class _SentQueueTabState extends ConsumerState<_SentQueueTab> {
  Future<void> _delete(String uuid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE ORDER?'),
        content: const Text(
          'This permanently removes the order and its history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(webHostBridgeProvider).deleteOrder(uuid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(whOrdersProvider).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final openOrders = orders.where((o) => o.status != 3).toList();
    final closedOrders = orders.where((o) => o.status == 3).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              isScrollable: false,
              tabAlignment: TabAlignment.fill,
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
              tabs: [
                Tab(text: 'OPEN (${openOrders.length})'),
                Tab(text: 'CLOSED (${closedOrders.length})'),
                Tab(text: 'ALL (${orders.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(
                  openOrders,
                  'NO OPEN ORDERS',
                  'Active orders waiting to be fulfilled will appear here',
                ),
                _buildOrderList(
                  closedOrders,
                  'NO CLOSED ORDERS',
                  'Completed orders will appear here',
                ),
                _buildOrderList(
                  orders,
                  'NO ORDERS YET',
                  'Orders you send will appear here',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    List<WHOrder> orderList,
    String emptyTitle,
    String emptySub,
  ) {
    if (orderList.isEmpty) {
      return _emptyState(Icons.history_rounded, emptyTitle, emptySub);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orderList.length,
      itemBuilder: (context, i) {
        final order = orderList[i];
        final finished = order.status == 3;
        final itemCount = order.items.fold<int>(0, (s, it) => s + 1);
        final total = order.items.fold<double>(0, (s, it) => s + it.price);
        final minutesAgo = DateTime.now().difference(order.timestamp).inMinutes;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          order.status,
                        ).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${order.uuid.substring(0, 4).toUpperCase()}',
                        style: TextStyle(
                          color: _statusColor(order.status),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.customerName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _chip(
                      finished
                          ? 'Finished'
                          : order.status == 1
                          ? 'Partial'
                          : order.status == 2
                          ? 'Ready'
                          : 'Active',
                      color: _statusColor(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.timestamp.hour.toString().padLeft(2, '0')}:${order.timestamp.minute.toString().padLeft(2, '0')}  ·  $minutesAgo min ago',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final item in order.items.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        if (item.status == 3)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _kGreen,
                          )
                        else if (item.status == 2)
                          const Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: _kAmber,
                          )
                        else
                          const Icon(
                            Icons.radio_button_unchecked_rounded,
                            size: 15,
                            color: Color(0xFF9CA3AF),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.modifiers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              item.modifiers.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (order.items.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${order.items.length - 6} more items',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$itemCount items  ·  \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(webHostEditOrderProvider.notifier).state =
                            order;
                        ref.read(webHostTabIndexProvider.notifier).state = 0;
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('EDIT'),
                    ),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(webHostBridgeProvider)
                          .recallOrder(order.uuid),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('RECALL'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: _kRed,
                      onPressed: () => _delete(order.uuid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── INVENTORY ──────────────────────────────────────────────────

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(whMenuProvider);
    final bridge = ref.watch(webHostBridgeProvider);
    final tracked = menu.where((i) => i.trackStock).toList();
    if (tracked.isEmpty) {
      return _emptyState(
        Icons.inventory_2_rounded,
        'NO STOCK-TRACKED ITEMS',
        'Enable TRACK STOCK on menu items in LIBRARY',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tracked.length,
      itemBuilder: (context, i) {
        final item = tracked[i];
        final low = item.stockQuantity <= 5;
        final progress = (item.stockQuantity / (item.stockQuantity + 20)).clamp(
          0.0,
          1.0,
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (low) _chip('LOW', color: _kRed),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category}  ·  ${item.defaultStation}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: low ? _kRed : _kGreen,
                          backgroundColor: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: () => bridge.setStock(
                          item.id,
                          (item.stockQuantity - 1).clamp(0, 99999),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${item.stockQuantity}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: low ? _kRed : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: () =>
                            bridge.setStock(item.id, item.stockQuantity + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── LIBRARY ────────────────────────────────────────────────────

class _LibraryTab extends ConsumerStatefulWidget {
  const _LibraryTab();
  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  Future<void> _menuForm([WHMenuItem? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(
      text: existing?.category ?? 'All Items',
    );
    final statCtrl = TextEditingController(
      text: existing?.defaultStation ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing == null ? '' : '${existing.price}',
    );
    final modCtrl = TextEditingController(
      text: existing?.modifiers.join(',') ?? '',
    );
    var trackStock = existing?.trackStock ?? false;
    var oneTouch = existing?.oneTouch ?? false;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            existing == null ? 'NEW MENU ITEM' : 'EDIT MENU ITEM',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'NAME',
                      prefixIcon: Icon(Icons.fastfood_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: catCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CATEGORY',
                      prefixIcon: Icon(Icons.category_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: statCtrl,
                    decoration: const InputDecoration(
                      labelText: 'STATION',
                      prefixIcon: Icon(Icons.dns_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'PRICE',
                      prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modCtrl,
                    decoration: const InputDecoration(
                      labelText: 'MODIFIERS (comma-separated)',
                      prefixIcon: Icon(Icons.tune_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'TRACK STOCK',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    value: trackStock,
                    onChanged: (v) => setDlgState(() => trackStock = v),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'ONE TOUCH ADD',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Skips modifier screen on tap in intake',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: oneTouch,
                    onChanged: (v) => setDlgState(() => oneTouch = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final menu = {
      if (existing != null) 'id': existing.id,
      'name': nameCtrl.text.trim(),
      'category': catCtrl.text.trim().isEmpty
          ? 'All Items'
          : catCtrl.text.trim(),
      'defaultStation': statCtrl.text.trim().isEmpty
          ? (existing?.defaultStation ?? 'Main Station')
          : statCtrl.text.trim(),
      'modifiers': modCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'requiredModifiers': const <String>[],
      'tags': existing?.tags ?? const [],
      'price': price,
      'stockQuantity': existing?.stockQuantity ?? 0,
      'trackStock': trackStock,
      'oneTouch': oneTouch,
    };
    ref.read(webHostBridgeProvider).saveMenu(menu);
  }

  Future<String?> _nameDialog({
    required String title,
    required String initial,
    String? hint,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    return save == true ? ctrl.text.trim() : null;
  }

  Future<void> _stationForm(int? existingId, String existingName) async {
    final name = await _nameDialog(title: 'STATION', initial: existingName);
    if (name == null || name.isEmpty) return;
    ref.read(webHostBridgeProvider).saveStation({
      'id': ?existingId,
      'name': name,
    });
  }

  Future<void> _modifierForm(int? existingId, String existingName) async {
    final name = await _nameDialog(title: 'MODIFIER', initial: existingName);
    if (name == null || name.isEmpty) return;
    ref.read(webHostBridgeProvider).saveModifier({
      'id': ?existingId,
      'name': name,
    });
  }

  Future<void> _confirmDelete({
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(subtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(whMenuProvider);
    final stations = ref.watch(whStationsProvider);
    final modifiers = ref.watch(whModifiersProvider);
    final bridge = ref.watch(webHostBridgeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'MENU ITEMS')),
            FilledButton.tonalIcon(
              onPressed: () => _menuForm(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD ITEM'),
            ),
          ],
        ),
        ...menu.map(
          (i) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fastfood_rounded,
                  size: 19,
                  color: _kBlue,
                ),
              ),
              title: Text(
                i.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${i.category} · ${i.defaultStation} · '
                '\$${i.price.toStringAsFixed(2)}'
                '${i.trackStock ? " · STOCK ${i.stockQuantity}" : ""}'
                '${i.oneTouch ? " · ⚡ ONE TOUCH" : ""}'
                '${i.modifiers.isNotEmpty ? " · ${i.modifiers.length} mods" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _menuForm(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: _kRed,
                    onPressed: () => _confirmDelete(
                      title: 'DELETE "${i.name}"?',
                      subtitle:
                          'Menu items used by past orders keep their history.',
                      onDelete: () => bridge.deleteMenu(i.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'STATIONS')),
            FilledButton.tonalIcon(
              onPressed: () => _stationForm(null, ''),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD STATION'),
            ),
          ],
        ),
        ...stations.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.dns_rounded, size: 19, color: _kPurple),
              ),
              title: Text(
                s.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _stationForm(s.id, s.name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: _kRed,
                    onPressed: () => _confirmDelete(
                      title: 'DELETE STATION "${s.name}"?',
                      subtitle: '',
                      onDelete: () => bridge.deleteStation(s.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'MODIFIERS')),
            FilledButton.tonalIcon(
              onPressed: () => _modifierForm(null, ''),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD MODIFIER'),
            ),
          ],
        ),
        ...modifiers.map(
          (m) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tune_rounded, size: 19, color: _kGreen),
              ),
              title: Text(
                m.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _modifierForm(m.id, m.name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: _kRed,
                    onPressed: () => _confirmDelete(
                      title: 'DELETE MODIFIER "${m.name}"?',
                      subtitle: '',
                      onDelete: () => bridge.deleteModifier(m.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── CLIENTS ────────────────────────────────────────────────────

class _ClientsTab extends ConsumerStatefulWidget {
  const _ClientsTab();
  @override
  ConsumerState<_ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<_ClientsTab> {
  final _broadcastCtrl = TextEditingController();
  bool _rushMode = false;
  String? _targetStation;

  @override
  void dispose() {
    _broadcastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(whClientsProvider);
    final stations = ref.watch(whStationsProvider);
    final bridge = ref.read(webHostBridgeProvider);
    // Every station a device could be listening on: catalog stations +
    // stations currently held by connected devices.
    final allStations = <String>{
      for (final s in stations) s.name.toUpperCase(),
      for (final c in clients)
        if (c.currentStation.isNotEmpty) c.currentStation.toUpperCase(),
    }.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign_rounded, size: 18, color: _kAmber),
                    const SizedBox(width: 8),
                    const Text(
                      'KITCHEN BROADCAST',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _targetStation,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'TARGET STATION',
                    prefixIcon: Icon(Icons.dns_rounded, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('ALL SCREENS'),
                    ),
                    for (final s in allStations)
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() => _targetStation = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _broadcastCtrl,
                        decoration: InputDecoration(
                          hintText: _targetStation == null
                              ? 'Message to all kitchen screens…'
                              : 'Message to $_targetStation…',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendBroadcast(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      onPressed: _sendBroadcast,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'RUSH MODE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Highlights active tickets on client screens',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  value: _rushMode,
                  activeTrackColor: _kRed,
                  onChanged: (v) {
                    setState(() => _rushMode = v);
                    bridge.setRushMode(v);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(title: 'CONNECTED DEVICES', count: '${clients.length}'),
        if (clients.isEmpty)
          _emptyState(
            Icons.devices_rounded,
            'NO DEVICES CONNECTED',
            'Kitchen tablets appear here when they connect',
          )
        else
          ...clients.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _kGreen.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.tablet_android_rounded,
                    size: 19,
                    color: _kGreen,
                  ),
                ),
                title: Text(
                  c.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${c.currentStation} · ${c.id.substring(0, 4).toUpperCase()}',
                ),
                trailing: _chip('ONLINE', color: _kGreen),
              ),
            ),
          ),
      ],
    );
  }

  void _sendBroadcast() {
    final text = _broadcastCtrl.text.trim();
    if (text.isEmpty) return;
    ref
        .read(webHostBridgeProvider)
        .broadcastMessage(text, station: _targetStation);
    _broadcastCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _targetStation == null
              ? 'BROADCAST SENT TO ALL SCREENS'
              : 'BROADCAST SENT TO $_targetStation',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

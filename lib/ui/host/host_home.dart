import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'views/order_intake_view.dart';
import 'views/library_view.dart';
import 'views/inventory_view.dart';
import 'views/more_view.dart';
import '../../providers/app_state_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/service_providers.dart';
import '../../models/connected_client.dart';

class HostHome extends ConsumerStatefulWidget {
  const HostHome({super.key});

  @override
  ConsumerState<HostHome> createState() => _HostHomeState();
}

class _HostHomeState extends ConsumerState<HostHome> {
  final List<Widget> _views = [
    const OrderIntakeView(),
    const InventoryView(),
    const LibraryView(),
    const MoreView(),
  ];

  bool _initialized = false;
  Set<String> _knownClientIds = {};

  void _onClientsChanged(List<ConnectedClient> clients) {
    final ids = clients.map((c) => c.id).toSet();
    if (!_initialized) {
      _initialized = true;
      _knownClientIds = ids;
      return;
    }
    final newClients = clients.where((c) => !_knownClientIds.contains(c.id)).toList();
    _knownClientIds = ids;
    for (final client in newClients) {
      _showClientConnectedDialog(client);
    }
  }

  Future<void> _showClientConnectedDialog(ConnectedClient client) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.dividerColor),
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            const Text(
              'NEW CLIENT CONNECTED',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${client.deviceName} joined the kitchen display network.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Text(
                    'STATION: ${client.currentStation.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final timeFormat = settings.use24HourFormat ? 'HH:mm' : 'h:mm a';
    final currentIndex = ref.watch(hostTabIndexProvider);

    ref.listen<AsyncValue<List<ConnectedClient>>>(
      connectedClientsProvider,
      (previous, next) {
        if (previous == null || !next.hasValue) return;
        _onClientsChanged(next.value ?? []);
      },
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              currentIndex == 0 ? 'TERMINAL' : (currentIndex == 1 ? 'STOCK' : (currentIndex == 2 ? 'LIBRARY' : 'SYSTEM')),
              style: const TextStyle(letterSpacing: 1.5, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.dividerColor)),
            ),
            alignment: Alignment.center,
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return Text(
                  DateFormat(timeFormat).format(DateTime.now()),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace', fontSize: 15),
                );
              },
            ),
          ),
        ],
      ),
      body: _views[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor, width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => ref.read(hostTabIndexProvider.notifier).state = index,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.apps_outlined, size: 22), activeIcon: Icon(Icons.apps_rounded, size: 22), label: 'ORDER'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined, size: 22), activeIcon: Icon(Icons.inventory_2_rounded, size: 22), label: 'STOCK'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined, size: 22), activeIcon: Icon(Icons.menu_book_rounded, size: 22), label: 'MENU'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded, size: 22), label: 'MORE'),
          ],
        ),
      ),
    );
  }
}

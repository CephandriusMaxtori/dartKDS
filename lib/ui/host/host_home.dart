import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'views/order_intake_view.dart';
import 'views/library_view.dart';
import 'views/inventory_view.dart';
import 'views/more_view.dart';
import '../../providers/settings_provider.dart';
import '../../providers/service_providers.dart';

class HostHome extends ConsumerStatefulWidget {
  const HostHome({super.key});

  @override
  ConsumerState<HostHome> createState() => _HostHomeState();
}

class _HostHomeState extends ConsumerState<HostHome> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const OrderIntakeView(),
    const InventoryView(),
    const LibraryView(),
    const MoreView(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final timeFormat = settings.use24HourFormat ? 'HH:mm' : 'h:mm a';

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
              _currentIndex == 0 ? 'TERMINAL' : (_currentIndex == 1 ? 'STOCK' : (_currentIndex == 2 ? 'LIBRARY' : 'SYSTEM')),
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
      body: _views[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor, width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF111111),
          unselectedItemColor: const Color(0xFF999999),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.apps_rounded, size: 22), label: 'ORDER'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded, size: 22), label: 'STOCK'),
            BottomNavigationBarItem(icon: Icon(Icons.book_rounded, size: 22), label: 'MENU'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded, size: 22), label: 'MORE'),
          ],
        ),
      ),
    );
  }
}

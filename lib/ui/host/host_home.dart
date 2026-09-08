import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'views/order_intake_view.dart';
import 'views/library_view.dart';
import 'views/sent_queue_view.dart';
import 'views/settings_view.dart';
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
    const LibraryView(),
    const SentQueueView(),
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final timeFormat = settings.use24HourFormat ? 'HH:mm' : 'h:mm a';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 12),
            const SizedBox(width: 8),
            Text(
              _currentIndex == 0 
                ? 'Take Order' 
                : (_currentIndex == 1 
                  ? 'Library' 
                  : (_currentIndex == 2 ? 'Sent Queue' : 'Settings')),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Discovery',
            onPressed: () async {
              await ref.read(discoveryServiceProvider).stop();
              await ref.read(discoveryServiceProvider).register(8080);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Discovery Service Restarted')),
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  return Text(
                    DateFormat(timeFormat).format(DateTime.now()),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _views[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed, // Use fixed to show label for 4 items
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_shopping_cart), label: 'Take Order'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.send_and_archive), label: 'Sent Queue'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

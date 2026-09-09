import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sent_queue_view.dart';
import 'settings_view.dart';
import 'library_view.dart';

class MoreView extends ConsumerWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: GridView.count(
        crossAxisCount: isCompact ? 2 : 3,
        mainAxisSpacing: isCompact ? 12 : 16,
        crossAxisSpacing: isCompact ? 12 : 16,
        childAspectRatio: isCompact ? 1.1 : 1.4,
        children: [
          _buildMoreCard(
            context,
            title: 'SENT QUEUE',
            subtitle: 'Historical orders',
            icon: Icons.history,
            color: Colors.blue,
            target: const SentQueueView(),
          ),
          _buildMoreCard(
            context,
            title: 'STATIONS',
            subtitle: 'Routing config',
            icon: Icons.router,
            color: Colors.orange,
            target: const LibraryView(initialTab: 1), // STATIONS tab
          ),
          _buildMoreCard(
            context,
            title: 'MODIFIERS',
            subtitle: 'Global options',
            icon: Icons.tune,
            color: Colors.purple,
            target: const LibraryView(initialTab: 2), // MODIFIERS tab
          ),
          _buildMoreCard(
            context,
            title: 'BACKUP',
            subtitle: 'Import & Export',
            icon: Icons.backup,
            color: Colors.green,
            target: const LibraryView(initialTab: 3), // BACKUP tab
          ),
          _buildMoreCard(
            context,
            title: 'SETTINGS',
            subtitle: 'App preferences',
            icon: Icons.settings,
            color: Colors.grey,
            target: const SettingsView(),
          ),
          _buildMoreCard(
            context,
            title: 'DEVICES',
            subtitle: 'Connected displays',
            icon: Icons.important_devices,
            color: Colors.indigo,
            target: const SettingsView(), // Also in settings for now
          ),
        ],
      ),
    );
  }

  Widget _buildMoreCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget target,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: target,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

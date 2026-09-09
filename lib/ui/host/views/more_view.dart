import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sent_queue_view.dart';
import 'settings_view.dart';
import 'library_view.dart';

class MoreView extends ConsumerWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MANAGEMENT HUB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.4)),
                  Text('System configuration and reporting.', style: TextStyle(color: Color(0xFF666666), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: isCompact ? 2 : 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildCard(context, 'SENT QUEUE', 'Order history', Icons.history_rounded, const Color(0xFF2563EB), const SentQueueView()),
                _buildCard(context, 'STATIONS', 'Routing lines', Icons.router_rounded, const Color(0xFFD97706), const LibraryView(initialTab: 1)),
                _buildCard(context, 'MODIFIERS', 'Global choices', Icons.tune_rounded, const Color(0xFF7C3AED), const LibraryView(initialTab: 2)),
                _buildCard(context, 'BACKUP', 'Data sync', Icons.backup_table_rounded, const Color(0xFF059669), const LibraryView(initialTab: 3)),
                _buildCard(context, 'DEVICES', 'KDS display list', Icons.important_devices_rounded, const Color(0xFF4B5563), const SettingsView()),
                _buildCard(context, 'SETTINGS', 'Preferences', Icons.settings_rounded, const Color(0xFF111111), const SettingsView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String sub, IconData icon, Color color, Widget target) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => Scaffold(appBar: AppBar(title: Text(title)), body: target))),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            Text(sub, style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

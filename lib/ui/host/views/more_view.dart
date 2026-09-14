import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sent_queue_view.dart';
import 'settings_view.dart';
import 'library_view.dart';
import 'analytics_view.dart';
import '../../../providers/app_state_providers.dart';

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
                  Text(
                    'MANAGEMENT HUB',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'System configuration and reporting.',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                _buildCard(
                  context,
                  ref,
                  'MENU LIBRARY',
                  'Items & Catalog',
                  Icons.menu_book_rounded,
                  const Color(0xFF111111),
                  const LibraryView(),
                  tabIndex: 0,
                ),
                _buildCard(
                  context,
                  ref,
                  'STATIONS',
                  'Routing lines',
                  Icons.router_rounded,
                  const Color(0xFFD97706),
                  const LibraryView(),
                  tabIndex: 1,
                ),
                _buildCard(
                  context,
                  ref,
                  'MODIFIERS',
                  'Global choices',
                  Icons.tune_rounded,
                  const Color(0xFF7C3AED),
                  const LibraryView(),
                  tabIndex: 2,
                ),
                _buildCard(
                  context,
                  ref,
                  'SYSTEM SETTINGS',
                  'Devices & Network',
                  Icons.important_devices_rounded,
                  const Color(0xFF2563EB),
                  const SettingsView(),
                ),
                _buildCard(
                  context,
                  ref,
                  'BACKUP',
                  'Data sync',
                  Icons.backup_table_rounded,
                  const Color(0xFF059669),
                  const LibraryView(),
                  tabIndex: 3,
                ),
                _buildCard(
                  context,
                  ref,
                  'SALES CHARTS',
                  'Revenue & Trends',
                  Icons.bar_chart_rounded,
                  const Color(0xFF22C55E),
                  const AnalyticsView(),
                ),
                _buildCard(
                  context,
                  ref,
                  'KITCHEN ALERTS',
                  'Send Broadcasts',
                  Icons.campaign_rounded,
                  const Color(0xFFDC2626),
                  const SizedBox.shrink(),
                  isBroadcast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.dividerColor),
        ),
        title: const Text(
          'KITCHEN BROADCAST',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. 86 Smash Burgers, Rush coming in...',
            hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(hostServerProvider)
                    .broadcast(
                      jsonEncode({
                        'type': 'KitchenBroadcast',
                        'message': controller.text.trim(),
                      }),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text(
              'SEND TO ALL SCREENS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    String sub,
    IconData icon,
    Color color,
    Widget target, {
    int? tabIndex,
    bool isBroadcast = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        if (isBroadcast) {
          _showBroadcastDialog(context, ref);
          return;
        }
        if (tabIndex != null) {
          ref.read(libraryTabIndexProvider.notifier).state = tabIndex;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: target,
            ),
          ),
        );
      },
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
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

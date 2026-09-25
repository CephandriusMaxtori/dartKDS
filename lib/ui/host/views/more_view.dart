import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_view.dart';
import 'library_view.dart';
import 'analytics_view.dart';
import '../../shared/responsive_utils.dart';
import '../../../providers/app_state_providers.dart';
import '../../../providers/host_store_provider.dart';

class MoreView extends ConsumerWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ContentWidth(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Derive the grid from the space the content actually gets, so the
            // cards stay the same comfortable size on a phone and a 27" monitor.
            final columns = gridColumnsFor(constraints.maxWidth);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
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
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
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
                        const Color(0xFF2AA31F),
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _showBroadcastDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final stations = await ref.read(hostStoreProvider).getConnectedStations();
    if (!context.mounted) return;
    String? targetStation;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.dividerColor),
          ),
          title: const Text(
            'KITCHEN BROADCAST',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'e.g. 86 Smash Burgers, Rush coming in...',
                    hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: targetStation,
                  decoration: const InputDecoration(
                    labelText: 'TARGET STATION',
                    prefixIcon: Icon(Icons.dns_rounded, size: 18),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('ALL SCREENS'),
                    ),
                    for (final s in stations)
                      DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      ),
                  ],
                  onChanged: (v) => setDlgState(() => targetStation = v),
                ),
              ],
            ),
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
                  ref.read(hostStoreProvider).broadcastKitchenMessage(
                        controller.text.trim(),
                        station: targetStation,
                      );
                  Navigator.pop(context);
                }
              },
              child: Text(
                targetStation == null ? 'SEND TO ALL SCREENS' : 'SEND TO $targetStation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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
              body: ContentWidth(maxWidth: 1000, child: target),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
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

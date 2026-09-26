import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) '../../../web_io_stub.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.js_interop) '../../../web_path_provider_stub.dart';
import '../../../models/database.dart';
import '../../../data/host_store.dart';
import '../../../providers/host_store_provider.dart';

class AnalyticsView extends ConsumerWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(hostStoreProvider);
    final theme = Theme.of(context);
    final chartKey = GlobalKey();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<ItemSalesStat>>(
        stream: store.watchItemSalesStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;
          if (stats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 64,
                    color: theme.hintColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NO SALES DATA YET',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            );
          }

          double totalRevenue = 0;
          int totalSold = 0;

          for (final stat in stats) {
            totalRevenue += stat.revenue;
            totalSold += stat.quantity;
          }

          final sortedStats = stats; // Already sorted by revenue in SQL
          final maxRevenue = sortedStats.isNotEmpty
              ? sortedStats.first.revenue
              : 1.0;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'SALES PERFORMANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.cardColor,
                              foregroundColor: theme.textTheme.bodyMedium?.color,
                              elevation: 0,
                              side: BorderSide(color: theme.dividerColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.table_chart_rounded, size: 16),
                            label: const Text(
                              'EXPORT CSV',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            onPressed: () => _exportSalesReport(context, stats, totalRevenue, totalSold),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2AA31F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.image_rounded, size: 16),
                            label: const Text(
                              'EXPORT PNG',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            onPressed: () => _exportChartPng(context, chartKey),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.cardColor,
                              foregroundColor: Colors.red,
                              elevation: 0,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                            label: const Text(
                              'CLEAR HISTORY',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                            onPressed: () => _showClearConfirmation(context, store),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildSummaryCard(
                        theme,
                        'TOTAL REVENUE',
                        '\$${totalRevenue.toStringAsFixed(2)}',
                        Icons.payments_rounded,
                        const Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        theme,
                        'ITEMS SOLD',
                        totalSold.toString(),
                        Icons.shopping_basket_rounded,
                        const Color(0xFF2AA31F),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RepaintBoundary(
                    key: chartKey,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERFORMANCE BY ITEM',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...sortedStats
                              .take(5)
                              .map(
                                (stat) => _buildChartRow(theme, stat, maxRevenue),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final stat = sortedStats[index];
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
                            leading: CircleAvatar(
                              backgroundColor: theme.dividerColor,
                              child: Text(
                                (index + 1).toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              stat.name.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${stat.quantity} units sold',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (stat.modifierCounts.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      (stat.modifierCounts.entries.toList()..sort(
                                            (a, b) => b.value.compareTo(a.value),
                                          ))
                                          .take(3)
                                          .map((e) => '${e.key} (${e.value})')
                                          .join(', '),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: theme.hintColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '\$${stat.revenue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: sortedStats.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartRow(
    ThemeData theme,
    ItemSalesStat stat,
    double maxRevenue,
  ) {
    final percentage = stat.revenue / maxRevenue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stat.name.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                '\$${stat.revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          if (stat.modifierCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'Top Modifiers: ${(stat.modifierCounts.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(2)
                        .map((e) => e.key)
                        .join(', ')}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: theme.hintColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => Container(
                  height: 8,
                  width: constraints.maxWidth * percentage,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportSalesReport(
    BuildContext context,
    List<ItemSalesStat> stats,
    double totalRevenue,
    int totalSold,
  ) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'DartKDS Sales Report - Generated: ${DateTime.now().toIso8601String()}',
      );
      buffer.writeln('Total Revenue,\$${totalRevenue.toStringAsFixed(2)}');
      buffer.writeln('Total Items Sold,$totalSold');
      buffer.writeln('');
      buffer.writeln('Rank,Item Name,Units Sold,Revenue,Top Modifiers');

      for (int i = 0; i < stats.length; i++) {
        final stat = stats[i];
        final topMods = stat.modifierCounts.isNotEmpty
            ? (stat.modifierCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .map((e) => '${e.key} (${e.value})')
                .join('; ')
            : 'None';
        buffer.writeln(
          '${i + 1},"${stat.name}",${stat.quantity},\$${stat.revenue.toStringAsFixed(2)},"$topMods"',
        );
      }

      final csvString = buffer.toString();
      final bytes = utf8.encode(csvString);
      final fileName =
          'dartkds_sales_report_${DateTime.now().toIso8601String().substring(0, 10)}.csv';

      String? path;
      try {
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Sales Report',
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
      } catch (_) {}

      if (path != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sales report exported successfully to $path'),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        }
      } else if (kIsWeb) {
        return;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvString);
        await Share.shareXFiles([XFile(file.path)], text: 'DartKDS Sales Report');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportChartPng(BuildContext context, GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture chart widget.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to generate PNG image data.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final fileName =
          'dartkds_sales_chart_${DateTime.now().toIso8601String().substring(0, 10)}.png';

      String? path;
      try {
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Sales Chart PNG',
          fileName: fileName,
          bytes: pngBytes,
          type: FileType.custom,
          allowedExtensions: ['png'],
        );
      } catch (_) {}

      if (path != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chart image exported successfully to $path'),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        }
      } else if (kIsWeb) {
        return;
      } else {
        final dynamic directory = await getApplicationDocumentsDirectory();
        final dynamic file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'DartKDS Sales Chart PNG');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PNG Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearConfirmation(
    BuildContext context,
    HostStore store,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'CLEAR SALES & HISTORY?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all sales data, revenue statistics, and order history. Your menu library, stations, and settings will remain untouched.\n\nThis action cannot be undone.',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CLEAR HISTORY',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await store.clearSalesAndHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales data & order history cleared!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

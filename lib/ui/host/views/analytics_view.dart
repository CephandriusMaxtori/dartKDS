import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/database.dart';
import '../../../providers/service_providers.dart';

class AnalyticsView extends ConsumerWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<ItemSalesStat>>(
        stream: db.getItemSalesStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final stats = snapshot.data!;
          if (stats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 64,
                    color: theme.hintColor.withOpacity(0.3),
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
                        const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final stat = sortedStats[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
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
                        subtitle: Text(
                          '${stat.quantity} units sold',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '\$${stat.revenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF22C55E),
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
          const SizedBox(height: 6),
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
}

class _ItemStats {
  final String name;
  int quantity;
  double revenue;

  _ItemStats({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  _ItemStats add(double price) {
    quantity++;
    revenue += price;
    return this;
  }
}

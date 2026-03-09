import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'visitor_arrival_data.dart';

class CountryDetailScreen extends StatefulWidget {
  final String country;
  final VisitorArrivalDataManager dataManager;

  const CountryDetailScreen({
    super.key,
    required this.country,
    required this.dataManager,
  });

  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  late CountryDetailStats _stats;

  @override
  void initState() {
    super.initState();
    _stats = widget.dataManager.getCountryDetailStats(widget.country);
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  String _formatCurrency(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  String _getCountryFlag(String country) {
    const flags = {
      'India': '🇮🇳',
      'United Kingdom': '🇬🇧',
      'Russia': '🇷🇺',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'China': '🇨🇳',
      'USA': '🇺🇸',
      'Australia': '🇦🇺',
      'Japan': '🇯🇵',
      'South Korea': '🇰🇷',
      'Italy': '🇮🇹',
      'Spain': '🇪🇸',
      'Canada': '🇨🇦',
      'Netherlands': '🇳🇱',
      'UAE': '🇦🇪',
      'Qatar': '🇶🇦',
      'Poland': '🇵🇱',
      'Maldives': '🇲🇻',
    };
    return flags[country] ?? '🌍';
  }

  @override
  Widget build(BuildContext context) {
    final sortedYears = _stats.yearlyVisitors.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // Sort by year descending

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF673AB7),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getCountryFlag(widget.country),
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.country,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Visitor Statistics',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Summary Statistics
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Total Visitors Card
                      _buildSummaryCard(
                        'Total Visitors (All Years)',
                        _formatNumber(_stats.totalVisitors),
                        Icons.people,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 12),

                      // Best Year and Revenue Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Best Year',
                              _stats.bestYear.toString(),
                              Icons.emoji_events,
                              const Color(0xFFFFD700),
                              subtitle:
                                  '${_formatNumber(_stats.bestYearVisitors)} visitors',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Revenue',
                              'LKR ${_formatCurrency(_stats.totalRevenue)}',
                              Icons.attach_money,
                              const Color(0xFF9C27B0),
                              isCompact: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Yearly Breakdown Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Yearly Breakdown',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                // Yearly Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: sortedYears.map((entry) {
                      final year = entry.key;
                      final visitors = entry.value;
                      final isBestYear = year == _stats.bestYear;
                      final percentage = (_stats.totalVisitors > 0)
                          ? (visitors / _stats.totalVisitors) * 100
                          : 0.0;

                      return _buildYearCard(
                        year,
                        visitors,
                        percentage,
                        isBestYear,
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: isCompact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearCard(
    int year,
    int visitors,
    double percentage,
    bool isBestYear,
  ) {
    final revenue = (visitors * VisitorArrivalDataManager.ENTRY_FEE_LKR)
        .toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isBestYear ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isBestYear
            ? const BorderSide(color: Color(0xFFFFD700), width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: isBestYear
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.1),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Year badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isBestYear
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (isBestYear) ...[
                          const Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          year.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Percentage
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Statistics Row
              Row(
                children: [
                  Expanded(
                    child: _buildYearStat(
                      Icons.people_outline,
                      'Visitors',
                      _formatNumber(visitors),
                      const Color(0xFF4CAF50),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildYearStat(
                      Icons.attach_money,
                      'Revenue',
                      'LKR ${_formatCurrency(revenue)}',
                      const Color(0xFF9C27B0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

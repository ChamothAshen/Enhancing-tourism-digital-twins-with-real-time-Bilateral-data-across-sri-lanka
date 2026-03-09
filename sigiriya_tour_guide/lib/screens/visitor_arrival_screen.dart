import 'package:flutter/material.dart';
import 'visitor_arrival_data.dart';
import 'country_detail_screen.dart';
import 'package:intl/intl.dart';

class VisitorArrivalScreen extends StatefulWidget {
  const VisitorArrivalScreen({super.key});

  @override
  State<VisitorArrivalScreen> createState() => _VisitorArrivalScreenState();
}

class _VisitorArrivalScreenState extends State<VisitorArrivalScreen> {
  final VisitorArrivalDataManager _dataManager = VisitorArrivalDataManager();
  bool _isLoading = true;
  int? _selectedYear;
  YearlyStats? _stats;
  bool _showAllCountries = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _dataManager.loadData();

    if (mounted && _dataManager.isLoaded) {
      final years = _dataManager.getAvailableYears();
      setState(() {
        _selectedYear = years.isNotEmpty ? years.first : null;
        if (_selectedYear != null) {
          _stats = _dataManager.getYearlyStats(_selectedYear!);
        }
        _isLoading = false;
      });
    }
  }

  void _onYearChanged(int? year) {
    if (year != null) {
      setState(() {
        _selectedYear = year;
        _stats = _dataManager.getYearlyStats(year);
        _showAllCountries = false;
      });
    }
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading visitor data...'),
            ],
          ),
        ),
      );
    }

    if (_selectedYear == null || _stats == null) {
      return const Scaffold(body: Center(child: Text('No data available')));
    }

    final years = _dataManager.getAvailableYears();
    final displayCountries = _showAllCountries
        ? _stats!.topCountries
        : _stats!.topCountries.take(10).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF1E88E5),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Visitor Arrival Analysis',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Year selector
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: years.map((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    'Year $year',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onYearChanged,
                            ),
                          ),
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

                // Statistics Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Total Visitors Card
                      _buildStatCard(
                        'Total Visitors',
                        _formatNumber(_stats!.totalVisitors),
                        Icons.people,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 12),

                      // Peak & Low Months Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Peak Month',
                              _stats!.peakMonth,
                              Icons.trending_up,
                              const Color(0xFFFF9800),
                              subtitle: _formatNumber(
                                _stats!.peakMonthVisitors,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Low Month',
                              _stats!.lowMonth,
                              Icons.trending_down,
                              const Color(0xFF2196F3),
                              subtitle: _formatNumber(_stats!.lowMonthVisitors),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total Revenue Card
                      _buildStatCard(
                        'Total Revenue',
                        'LKR ${_formatCurrency(_stats!.totalRevenue)}',
                        Icons.attach_money,
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Top Countries Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top Countries',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_stats!.topCountries.length > 10)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllCountries = !_showAllCountries;
                            });
                          },
                          icon: Icon(
                            _showAllCountries
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _showAllCountries
                                ? 'Show Top 10'
                                : 'View All (${_stats!.topCountries.length})',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Countries List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: displayCountries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final country = entry.value;
                      return _buildCountryCard(country, index + 1);
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Widget _buildCountryCard(CountryStats country, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CountryDetailScreen(
                country: country.country,
                dataManager: _dataManager,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3
                          ? const Color(0xFFFF8F00)
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Country flag emoji (you can enhance this with actual flag widgets)
              Text(
                _getCountryFlag(country.country),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              // Country info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.country,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatNumber(country.totalVisitors)} visitors',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${country.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}

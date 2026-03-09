import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'feedback_data.dart';
import 'visitor_arrival_data.dart';
import '../config/api_config.dart';

/// Unified Manager Dashboard
/// Combines past analytics (feedback + visitors) and future predictions
/// into a single cohesive view for manager convenience
class UnifiedManagerDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const UnifiedManagerDashboard({super.key, this.adminData});

  @override
  State<UnifiedManagerDashboard> createState() =>
      _UnifiedManagerDashboardState();
}

class _UnifiedManagerDashboardState extends State<UnifiedManagerDashboard> {
  // Data managers
  final FeedbackDataManager _feedbackManager = FeedbackDataManager();
  final VisitorArrivalDataManager _visitorManager =
      VisitorArrivalDataManager();

  // Loading states
  bool _isLoadingPast = true;
  bool _isLoadingFuture = true;

  // Past analytics data
  int _totalFeedback = 0;
  Map<String, int> _sentimentCounts = {};
  int _totalVisitorsLastYear = 0;
  List<String> _topThreeCountries = [];

  // Future prediction data
  List<dynamic> _weeklyForecast = [];
  Map<String, dynamic> _monthlyForecast = {};
  List<dynamic> _weatherData = [];
  int _facilityCapacity = 6000;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadPastAnalytics(),
      _loadFutureAnalytics(),
    ]);
  }

  /// Load Past Analytics: Feedback + Visitor Statistics
  Future<void> _loadPastAnalytics() async {
    setState(() => _isLoadingPast = true);

    try {
      // Load feedback data
      await _feedbackManager.loadData();
      _totalFeedback = _feedbackManager.getTotalFeedbackCount();

      // Calculate sentiment counts (positive, neutral, negative)
      final allFeedback = _feedbackManager.feedbacks;
      int positive = 0, neutral = 0, negative = 0;
      for (var feedback in allFeedback) {
        if (feedback.rating >= 4) {
          positive++;
        } else if (feedback.rating == 3) {
          neutral++;
        } else {
          negative++;
        }
      }
      _sentimentCounts = {
        'positive': positive,
        'neutral': neutral,
        'negative': negative
      };

      // Load visitor data
      await _visitorManager.loadData();
      final currentYear = DateTime.now().year - 1; // Last complete year
      final yearStats = _visitorManager.getYearlyStats(currentYear);
      _totalVisitorsLastYear = yearStats.totalVisitors;
      _topThreeCountries =
          yearStats.topCountries.take(3).map((c) => c.country).toList();
    } catch (e) {
      debugPrint('Error loading past analytics: $e');
    }

    setState(() => _isLoadingPast = false);
  }

  /// Load Future Analytics: Forecasts, Capacity, Alerts
  Future<void> _loadFutureAnalytics() async {
    setState(() => _isLoadingFuture = true);

    final apiBaseUrl = ApiConfig.baseUrl;
    final token = widget.adminData?['token'] ?? '';

    try {
      // Load daily forecast (7 days)
      try {
        final forecastResponse = await http
            .get(
              Uri.parse('$apiBaseUrl/admin/daily-analytics?limit=7'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (forecastResponse.statusCode == 200) {
          _weeklyForecast = json.decode(forecastResponse.body);
        }
      } catch (e) {
        debugPrint('Error loading forecast: $e');
      }

      // Load monthly forecast (XGBoost)
      try {
        final monthlyResponse = await http
            .get(
              Uri.parse('$apiBaseUrl/admin/monthly-analytics?year=2026'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (monthlyResponse.statusCode == 200) {
          final data = json.decode(monthlyResponse.body);
          if (data is Map) {
            _monthlyForecast = Map<String, dynamic>.from(data);
          }
        }
      } catch (e) {
        debugPrint('Error loading monthly forecast: $e');
      }

      // Load weather forecast
      try {
        final weatherResponse = await http
            .get(
              Uri.parse('$apiBaseUrl/admin/weather-forecast?days=7'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (weatherResponse.statusCode == 200) {
          _weatherData = json.decode(weatherResponse.body);
        }
      } catch (e) {
        debugPrint('Error loading weather: $e');
      }

      // Calculate capacity from forecast
      if (_monthlyForecast.isNotEmpty) {
        final values = _monthlyForecast.values.whereType<int>().toList();
        if (values.isNotEmpty) {
          final maxVisitors = values.reduce((a, b) => a > b ? a : b);
          _facilityCapacity = (maxVisitors * 1.1).toInt();
        }
      }

      // Generate alerts
      _generateAlerts();
    } catch (e) {
      debugPrint('Error loading future analytics: $e');
    }

    setState(() => _isLoadingFuture = false);
  }

  void _generateAlerts() {
    _alerts.clear();

    if (_weeklyForecast.isNotEmpty) {
      final todayData = _weeklyForecast.first;
      final visitors = todayData['crowd'] ?? 0;

      if (visitors > _facilityCapacity) {
        _alerts.add({
          'title': 'Capacity Alert',
          'message':
              'Expected visitors ($visitors) exceed capacity ($_facilityCapacity)',
          'severity': 'high',
          'icon': Icons.warning,
          'color': Colors.red,
        });
      } else if (visitors > _facilityCapacity * 0.8) {
        _alerts.add({
          'title': 'High Visitor Volume',
          'message': 'Expected visitors ($visitors) approaching capacity',
          'severity': 'medium',
          'icon': Icons.info,
          'color': Colors.orange,
        });
      }
    }

    if (_weatherData.isNotEmpty) {
      final todayWeather = _weatherData.first;
      final temp = todayWeather['temperature'] ?? 0;
      final rainfall = todayWeather['rainfall'] ?? 0;

      if (temp > 35) {
        _alerts.add({
          'title': 'Heat Warning',
          'message': 'High temperature (${temp.toStringAsFixed(1)}°C) expected',
          'severity': 'medium',
          'icon': Icons.thermostat,
          'color': Colors.red,
        });
      }

      if (rainfall > 10) {
        _alerts.add({
          'title': 'Rain Warning',
          'message': 'Heavy rainfall (${rainfall.toStringAsFixed(1)}mm) expected',
          'severity': 'medium',
          'icon': Icons.cloud,
          'color': Colors.blue,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Manager Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Overview Cards
                    _buildOverviewSection(),
                    const SizedBox(height: 24),

                    // Active Alerts
                    if (_alerts.isNotEmpty) ...[
                      _buildAlertsSection(),
                      const SizedBox(height: 24),
                    ],

                    // Past Analytics
                    _buildPastAnalyticsSection(),
                    const SizedBox(height: 24),

                    // Future Predictions
                    _buildFuturePredictionsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Overview Section: Key metrics at a glance
  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quick Overview', Icons.dashboard),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildOverviewCard(
              'Last Year Visitors',
              _formatNumber(_totalVisitorsLastYear),
              Icons.people,
              Colors.blue,
              isLoading: _isLoadingPast,
            ),
            _buildOverviewCard(
              'Feedback Count',
              _totalFeedback.toString(),
              Icons.comment,
              Colors.green,
              isLoading: _isLoadingPast,
            ),
            _buildOverviewCard(
              'Today\'s Forecast',
              _weeklyForecast.isNotEmpty
                  ? '${_weeklyForecast.first['crowd'] ?? 0}'
                  : '--',
              Icons.trending_up,
              Colors.orange,
              isLoading: _isLoadingFuture,
            ),
            _buildOverviewCard(
              'Facility Capacity',
              _formatNumber(_facilityCapacity),
              Icons.storage,
              Colors.purple,
              isLoading: _isLoadingFuture,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }

  /// Alerts Section
  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Active Alerts', Icons.notifications_active),
        const SizedBox(height: 12),
        ...List.generate(
          _alerts.length > 3 ? 3 : _alerts.length,
          (index) {
            final alert = _alerts[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (alert['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: (alert['color'] as Color).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: alert['color'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      alert['icon'],
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          alert['message'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Past Analytics Section
  Widget _buildPastAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Past Analytics', Icons.history),
        const SizedBox(height: 12),

        // Feedback Sentiment Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingPast
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sentiment_satisfied,
                                color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Feedback Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSentimentItem(
                            'Positive',
                            _sentimentCounts['positive'] ?? 0,
                            Colors.green,
                          ),
                          _buildSentimentItem(
                            'Neutral',
                            _sentimentCounts['neutral'] ?? 0,
                            Colors.orange,
                          ),
                          _buildSentimentItem(
                            'Negative',
                            _sentimentCounts['negative'] ?? 0,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Top Issues: ${issueTypes.take(3).map((t) => t.name).join(', ')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Visitor Statistics Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingPast
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.public, color: Colors.green),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Visitor Statistics',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                          'Last Year Total:', _formatNumber(_totalVisitorsLastYear)),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Top Countries:',
                        _topThreeCountries.isNotEmpty
                            ? _topThreeCountries.join(', ')
                            : 'Loading...',
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Future Predictions Section
  Widget _buildFuturePredictionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Future Predictions', Icons.trending_up),
        const SizedBox(height: 12),

        // Weekly Forecast Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingFuture
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart,
                                color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '7-Day Forecast',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _weeklyForecast.isEmpty
                            ? const Center(child: Text('No forecast data'))
                            : _build7DayChart(),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Monthly Forecast Summary
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingFuture
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month,
                                color: Colors.purple),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Monthly Forecast (XGBoost)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_monthlyForecast.isEmpty)
                        const Text('No monthly forecast data')
                      else
                        ..._buildMonthlyForecastItems(),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Weather & Capacity
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _weatherData.isNotEmpty
                            ? '${_weatherData.first['temperature'] ?? 0}°C'
                            : '--',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Today\'s Temp',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.storage, color: Colors.purple, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _facilityCapacity > 0
                            ? _getCapacityStatus()
                            : '--',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Capacity Status',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _build7DayChart() {
    if (_weeklyForecast.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _weeklyForecast.length && i < 7; i++) {
      final crowd = _weeklyForecast[i]['crowd'] ?? 0;
      spots.add(FlSpot(i.toDouble(), crowd.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() < days.length) {
                  return Text(days[value.toInt()],
                      style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthlyForecastItems() {
    final currentMonth = DateTime.now().month;
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final items = <Widget>[];
    for (int i = currentMonth - 1; i < 12 && items.length < 3; i++) {
      final monthName = monthNames[i];
      final value = _monthlyForecast[monthName];
      if (value != null) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(monthName, style: const TextStyle(fontSize: 14)),
                Text(
                  '~${_formatNumber(value)} visitors/day',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return items.isNotEmpty
        ? items
        : [const Text('No monthly data available')];
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSentimentItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = value is int ? value : (value is double ? value.toInt() : 0);
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toString();
  }

  String _getCapacityStatus() {
    if (_weeklyForecast.isEmpty) return 'Normal';
    final todayVisitors = _weeklyForecast.first['crowd'] ?? 0;
    final utilization = (todayVisitors / _facilityCapacity) * 100;

    if (utilization > 100) return 'Critical';
    if (utilization > 80) return 'High';
    if (utilization > 60) return 'Moderate';
    return 'Normal';
  }
}

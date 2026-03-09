// Models and data for visitor arrival analysis
// Data loaded from CSV file in assets

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

// Visitor arrival record model
class VisitorArrival {
  final int year;
  final String month;
  final String country;
  final int sriLankaArrivals;
  final int estimatedSigiriyaVisitors;

  VisitorArrival({
    required this.year,
    required this.month,
    required this.country,
    required this.sriLankaArrivals,
    required this.estimatedSigiriyaVisitors,
  });

  factory VisitorArrival.fromCsvRow(List<dynamic> row) {
    try {
      if (row.length < 5) {
        debugPrint('Warning: Visitor CSV row has only ${row.length} columns');
        return VisitorArrival(
          year: 0,
          month: 'Unknown',
          country: 'Unknown',
          sriLankaArrivals: 0,
          estimatedSigiriyaVisitors: 0,
        );
      }

      return VisitorArrival(
        year: int.tryParse(row[0].toString()) ?? 0,
        month: row[1].toString(),
        country: row[2].toString(),
        sriLankaArrivals: int.tryParse(row[3].toString()) ?? 0,
        estimatedSigiriyaVisitors: int.tryParse(row[4].toString()) ?? 0,
      );
    } catch (e) {
      debugPrint('Error parsing Visitor CSV row: $e');
      return VisitorArrival(
        year: 0,
        month: 'Unknown',
        country: 'Unknown',
        sriLankaArrivals: 0,
        estimatedSigiriyaVisitors: 0,
      );
    }
  }

  // Convert month names to numbers for sorting
  int get monthNumber {
    const monthMap = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return monthMap[month] ?? 0;
  }
}

// Yearly statistics model
class YearlyStats {
  final int year;
  final int totalVisitors;
  final String peakMonth;
  final int peakMonthVisitors;
  final String lowMonth;
  final int lowMonthVisitors;
  final double totalRevenue; // in LKR
  final List<CountryStats> topCountries;

  YearlyStats({
    required this.year,
    required this.totalVisitors,
    required this.peakMonth,
    required this.peakMonthVisitors,
    required this.lowMonth,
    required this.lowMonthVisitors,
    required this.totalRevenue,
    required this.topCountries,
  });
}

// Country statistics model
class CountryStats {
  final String country;
  final int totalVisitors;
  final double percentage;

  CountryStats({
    required this.country,
    required this.totalVisitors,
    required this.percentage,
  });
}

// Country detailed stats across years
class CountryDetailStats {
  final String country;
  final Map<int, int> yearlyVisitors; // year -> visitor count
  final int totalVisitors;
  final int bestYear;
  final int bestYearVisitors;
  final int totalRevenue;

  CountryDetailStats({
    required this.country,
    required this.yearlyVisitors,
    required this.totalVisitors,
    required this.bestYear,
    required this.bestYearVisitors,
    required this.totalRevenue,
  });
}

// Data manager class
class VisitorArrivalDataManager {
  static final VisitorArrivalDataManager _instance =
      VisitorArrivalDataManager._internal();
  factory VisitorArrivalDataManager() => _instance;
  VisitorArrivalDataManager._internal();

  List<VisitorArrival> _arrivals = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<VisitorArrival> get arrivals => _arrivals;

  // Entry fee in LKR (can be adjusted based on actual rates)
  static const double ENTRY_FEE_LKR = 5000.0; // Average entry fee

  Future<void> loadData({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      debugPrint('Visitor data already loaded, skipping...');
      return;
    }

    try {
      debugPrint('Loading visitor arrival data from CSV...');

      final csv = await rootBundle.loadString(
        'assets/data/sigiriya_visitor_arrival.csv',
      );
      debugPrint('Visitor CSV loaded, length: ${csv.length} characters');

      List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csv);
      debugPrint('CSV converted to ${rows.length} rows');

      // Skip header row
      _arrivals = rows
          .skip(1)
          .map((row) => VisitorArrival.fromCsvRow(row))
          .where((item) => item.year > 0) // Filter out invalid items
          .toList();

      debugPrint('Loaded ${_arrivals.length} visitor arrival records');

      // Debug: Show available years
      final years = getAvailableYears();
      debugPrint('Available years: $years');

      _isLoaded = true;
      debugPrint('Visitor data loading completed successfully');
    } catch (e, stackTrace) {
      debugPrint('Error loading visitor CSV data: $e');
      debugPrint('Stack trace: $stackTrace');
      _isLoaded = false;
    }
  }

  // Get list of available years
  List<int> getAvailableYears() {
    final years = _arrivals.map((a) => a.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a)); // Sort descending
    return years;
  }

  // Get yearly statistics
  YearlyStats getYearlyStats(int year) {
    final yearData = _arrivals.where((a) => a.year == year).toList();

    if (yearData.isEmpty) {
      return YearlyStats(
        year: year,
        totalVisitors: 0,
        peakMonth: 'N/A',
        peakMonthVisitors: 0,
        lowMonth: 'N/A',
        lowMonthVisitors: 0,
        totalRevenue: 0,
        topCountries: [],
      );
    }

    // Calculate total visitors
    final totalVisitors = yearData.fold<int>(
      0,
      (sum, item) => sum + item.estimatedSigiriyaVisitors,
    );

    // Find peak and low months
    final monthlyTotals = <String, int>{};
    for (var record in yearData) {
      monthlyTotals[record.month] =
          (monthlyTotals[record.month] ?? 0) + record.estimatedSigiriyaVisitors;
    }

    final sortedMonths = monthlyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final peakMonth = sortedMonths.first.key;
    final peakMonthVisitors = sortedMonths.first.value;
    final lowMonth = sortedMonths.last.key;
    final lowMonthVisitors = sortedMonths.last.value;

    // Calculate revenue
    final totalRevenue = totalVisitors * ENTRY_FEE_LKR;

    // Get top countries
    final countryTotals = <String, int>{};
    for (var record in yearData) {
      countryTotals[record.country] =
          (countryTotals[record.country] ?? 0) +
          record.estimatedSigiriyaVisitors;
    }

    final topCountries =
        countryTotals.entries
            .where(
              (e) => e.key.toLowerCase() != 'other',
            ) // Exclude 'Other' category
            .map(
              (e) => CountryStats(
                country: e.key,
                totalVisitors: e.value,
                percentage: (e.value / totalVisitors) * 100,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalVisitors.compareTo(a.totalVisitors));

    return YearlyStats(
      year: year,
      totalVisitors: totalVisitors,
      peakMonth: peakMonth,
      peakMonthVisitors: peakMonthVisitors,
      lowMonth: lowMonth,
      lowMonthVisitors: lowMonthVisitors,
      totalRevenue: totalRevenue,
      topCountries: topCountries,
    );
  }

  // Get all countries for a specific year
  List<CountryStats> getAllCountriesForYear(int year) {
    final stats = getYearlyStats(year);
    return stats.topCountries;
  }

  // Get country detailed statistics across all years
  CountryDetailStats getCountryDetailStats(String country) {
    final countryData = _arrivals
        .where((a) => a.country.toLowerCase() == country.toLowerCase())
        .toList();

    if (countryData.isEmpty) {
      return CountryDetailStats(
        country: country,
        yearlyVisitors: {},
        totalVisitors: 0,
        bestYear: 0,
        bestYearVisitors: 0,
        totalRevenue: 0,
      );
    }

    // Calculate yearly visitors
    final yearlyVisitors = <int, int>{};
    for (var record in countryData) {
      yearlyVisitors[record.year] =
          (yearlyVisitors[record.year] ?? 0) + record.estimatedSigiriyaVisitors;
    }

    // Find best year
    final sortedYears = yearlyVisitors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestYear = sortedYears.first.key;
    final bestYearVisitors = sortedYears.first.value;

    // Calculate totals
    final totalVisitors = yearlyVisitors.values.fold<int>(0, (a, b) => a + b);
    final totalRevenue = (totalVisitors * ENTRY_FEE_LKR).toInt();

    return CountryDetailStats(
      country: country,
      yearlyVisitors: yearlyVisitors,
      totalVisitors: totalVisitors,
      bestYear: bestYear,
      bestYearVisitors: bestYearVisitors,
      totalRevenue: totalRevenue,
    );
  }

  // Get monthly data for a specific year
  List<Map<String, dynamic>> getMonthlyDataForYear(int year) {
    final yearData = _arrivals.where((a) => a.year == year).toList();

    final monthlyData = <String, int>{};
    for (var record in yearData) {
      monthlyData[record.month] =
          (monthlyData[record.month] ?? 0) + record.estimatedSigiriyaVisitors;
    }

    return monthlyData.entries
        .map((e) => {'month': e.key, 'visitors': e.value})
        .toList()
      ..sort((a, b) {
        const monthOrder = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return monthOrder
            .indexOf(a['month'] as String)
            .compareTo(monthOrder.indexOf(b['month'] as String));
      });
  }
}

// Models and data for feedback sentiment analysis dashboard
// Data loaded from CSV files in assets

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

// Issue type model with icon and color
class IssueType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  int feedbackCount;

  IssueType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.feedbackCount = 0,
  });
}

// Feedback model from CSV
class FeedbackItem {
  final int reviewId;
  final String reviewText;
  final int rating;
  final String date;
  final String category;
  final double confidence;

  FeedbackItem({
    required this.reviewId,
    required this.reviewText,
    required this.rating,
    required this.date,
    required this.category,
    required this.confidence,
  });

  factory FeedbackItem.fromCsvRow(List<dynamic> row) {
    return FeedbackItem(
      reviewId: int.tryParse(row[0].toString()) ?? 0,
      reviewText: row[1].toString(),
      rating: int.tryParse(row[2].toString()) ?? 3,
      date: row[3].toString(),
      category: row[4].toString(),
      confidence: double.tryParse(row[5].toString()) ?? 0.0,
    );
  }
}

// Solution model from CSV
class Solution {
  final String country;
  final String touristSite;
  final String issueType;
  final String problem;
  final String solution;
  final String solutionDescription;

  Solution({
    required this.country,
    required this.touristSite,
    required this.issueType,
    required this.problem,
    required this.solution,
    required this.solutionDescription,
  });

  factory Solution.fromCsvRow(List<dynamic> row) {
    return Solution(
      country: row[0].toString(),
      touristSite: row[1].toString(),
      issueType: row[2].toString(),
      problem: row[3].toString(),
      solution: row[4].toString(),
      solutionDescription: row[5].toString(),
    );
  }
}

// 8 Issue Types based on zero-shot aspect classification
final List<IssueType> issueTypes = [
  IssueType(
    id: 'Crowding',
    name: 'Crowding',
    description: 'Long wait times, overcrowded areas, and crowd management issues',
    icon: Icons.groups,
    color: const Color(0xFF2196F3),
  ),
  IssueType(
    id: 'Difficult Climb',
    name: 'Difficult Climb',
    description: 'Challenges with stairs, physical exertion, and accessibility during climb',
    icon: Icons.terrain,
    color: const Color(0xFFFF9800),
  ),
  IssueType(
    id: 'Heat and Weather Issues',
    name: 'Heat & Weather',
    description: 'Problems with heat, sun exposure, rain, and weather conditions',
    icon: Icons.wb_sunny,
    color: const Color(0xFFE53935),
  ),
  IssueType(
    id: 'High Entry Fee',
    name: 'High Entry Fee',
    description: 'Concerns about ticket prices, foreigner pricing, and value for money',
    icon: Icons.attach_money,
    color: const Color(0xFF9C27B0),
  ),
  IssueType(
    id: 'Other Complaints',
    name: 'Other Complaints',
    description: 'Miscellaneous issues and general complaints',
    icon: Icons.report_problem,
    color: const Color(0xFF607D8B),
  ),
  IssueType(
    id: 'Overrated',
    name: 'Overrated',
    description: 'Disappointment with experience not meeting expectations',
    icon: Icons.star_border,
    color: const Color(0xFF795548),
  ),
  IssueType(
    id: 'Poor Staff Service',
    name: 'Poor Staff Service',
    description: 'Issues with guides, staff behavior, and customer service',
    icon: Icons.person_off,
    color: const Color(0xFFFF5722),
  ),
  IssueType(
    id: 'Safety Concerns',
    name: 'Safety Concerns',
    description: 'Worries about physical safety, railings, and security',
    icon: Icons.health_and_safety,
    color: const Color(0xFF4CAF50),
  ),
];

// Data manager class
class FeedbackDataManager {
  static final FeedbackDataManager _instance = FeedbackDataManager._internal();
  factory FeedbackDataManager() => _instance;
  FeedbackDataManager._internal();

  List<FeedbackItem> _feedbacks = [];
  List<Solution> _solutions = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<FeedbackItem> get feedbacks => _feedbacks;
  List<Solution> get solutions => _solutions;

  Future<void> loadData() async {
    if (_isLoaded) return;

    try {
      // Load feedbacks CSV
      final feedbacksCsv = await rootBundle.loadString('assets/data/sigiriya_smart_categorized_reviews.csv');
      List<List<dynamic>> feedbackRows = const CsvToListConverter().convert(feedbacksCsv);
      
      // Skip header row
      _feedbacks = feedbackRows.skip(1).map((row) => FeedbackItem.fromCsvRow(row)).toList();

      // Load solutions CSV
      final solutionsCsv = await rootBundle.loadString('assets/data/global_tourism_problem_solution_dataset.csv');
      List<List<dynamic>> solutionRows = const CsvToListConverter().convert(solutionsCsv);
      
      // Skip header row
      _solutions = solutionRows.skip(1).map((row) => Solution.fromCsvRow(row)).toList();

      // Update feedback counts for each issue type
      for (var issueType in issueTypes) {
        issueType.feedbackCount = _feedbacks.where((f) => f.category == issueType.id).length;
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading CSV data: $e');
      // Use sample data if CSV loading fails
      _loadSampleData();
    }
  }

  void _loadSampleData() {
    // Sample data in case CSV loading fails
    _feedbacks = [
      FeedbackItem(reviewId: 1, reviewText: "Unfortunately, it's far too crowded.", rating: 3, date: "2026-01-27", category: "Crowding", confidence: 0.87),
      FeedbackItem(reviewId: 2, reviewText: "Not worth the 35 dollars. Rude unhelpful staff at the front desk.", rating: 1, date: "2026-01-22", category: "Poor Staff Service", confidence: 0.52),
      FeedbackItem(reviewId: 3, reviewText: "The entrance fee is very high at \$30 per person.", rating: 3, date: "2026-01-04", category: "High Entry Fee", confidence: 0.79),
      FeedbackItem(reviewId: 4, reviewText: "The climb is quite strenuous for elderly visitors.", rating: 2, date: "2025-12-15", category: "Difficult Climb", confidence: 0.85),
      FeedbackItem(reviewId: 5, reviewText: "No shade structures along the path. The sun was unbearable.", rating: 2, date: "2025-11-20", category: "Heat and Weather Issues", confidence: 0.78),
      FeedbackItem(reviewId: 6, reviewText: "This place is overrated. Not worth the hype.", rating: 2, date: "2025-10-18", category: "Overrated", confidence: 0.80),
      FeedbackItem(reviewId: 7, reviewText: "The stairs felt slippery and unsafe.", rating: 1, date: "2025-10-05", category: "Safety Concerns", confidence: 0.75),
      FeedbackItem(reviewId: 8, reviewText: "General disappointment with the facilities.", rating: 2, date: "2025-09-28", category: "Other Complaints", confidence: 0.45),
    ];

    for (var issueType in issueTypes) {
      issueType.feedbackCount = _feedbacks.where((f) => f.category == issueType.id).length;
    }

    _isLoaded = true;
  }

  List<FeedbackItem> getFeedbacksByCategory(String category) {
    return _feedbacks.where((f) => f.category == category).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  List<Solution> getSolutionsByIssueType(String issueType) {
    return _solutions.where((s) => s.issueType == issueType).toList();
  }

  IssueType? getIssueTypeById(String id) {
    try {
      return issueTypes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  int getTotalFeedbackCount() {
    return _feedbacks.length;
  }

  String getMostCommonIssue() {
    if (_feedbacks.isEmpty) return 'N/A';
    
    Map<String, int> counts = {};
    for (var f in _feedbacks) {
      counts[f.category] = (counts[f.category] ?? 0) + 1;
    }
    
    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

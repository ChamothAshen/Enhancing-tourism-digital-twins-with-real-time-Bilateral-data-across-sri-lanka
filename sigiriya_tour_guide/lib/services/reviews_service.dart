import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/review_model.dart';

class ReviewsService {
  // Replace with your actual backend API endpoint
  static const String reviewsJsonUrl =
      'http://192.168.1.100:8000/api/reviews'; // Update to your API
  static const String _assetAnalyzedPath = 'assets/data/reviews_analyzed.json';
  static const String _assetRecommendationsPath =
      'assets/data/reviews_with_recommendations.json';

  static const String _fallbackReviewsJson = '''
[
  {
    "id": "fallback-1",
    "rating": 2,
    "text": "The entrance fee was high and the queue took too long.",
    "author": "Fallback User",
    "time": "Recently",
    "sentiment": "negative",
    "sentiment_confidence": 0.91,
    "issues": [
      {"issue": "ticketing delays and booking problems", "confidence": 0.92},
      {"issue": "overcrowding and long queues", "confidence": 0.88}
    ],
    "cases_used": [
      {
        "country": "Multiple sources",
        "site": "Web research",
        "problem": "Ticketing delays and overcrowding",
        "solution": "Use timed entry slots, digital ticketing, and queue management to reduce congestion.",
        "source": "fallback"
      }
    ]
  },
  {
    "id": "fallback-2",
    "rating": 5,
    "text": "Beautiful views and a very memorable experience.",
    "author": "Fallback User",
    "time": "Recently",
    "sentiment": "positive",
    "sentiment_confidence": 0.97,
    "issues": [],
    "cases_used": []
  },
  {
    "id": "fallback-3",
    "rating": 3,
    "text": "Good location, but signage and accessibility could be improved.",
    "author": "Fallback User",
    "time": "Recently",
    "sentiment": "negative",
    "sentiment_confidence": 0.82,
    "issues": [
      {"issue": "poor accessibility and infrastructure", "confidence": 0.86}
    ],
    "cases_used": [
      {
        "country": "Ireland",
        "site": "Accessibility best practice",
        "problem": "Accessibility gaps at heritage sites",
        "solution": "Add clearer wayfinding, ramps, and visitor-friendly routes for universal access.",
        "source": "fallback"
      }
    ]
  }
]
''';

  static Future<List<ReviewData>> fetchReviews() async {
    try {
      final assetReviews = await _loadBundledReviews();
      if (assetReviews.isNotEmpty) {
        return assetReviews;
      }

      final response = await http.get(Uri.parse(reviewsJsonUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => ReviewData.fromJson(json)).toList();
      } else {
        return _loadFallbackReviews(
          'Failed to load reviews: ${response.statusCode}',
        );
      }
    } catch (e) {
      return _loadFallbackReviews('Error fetching reviews: $e');
    }
  }

  static Future<List<ReviewData>> _loadBundledReviews() async {
    try {
      final analyzedJson = await rootBundle.loadString(_assetAnalyzedPath);
      final recommendationsJson = await rootBundle
          .loadString(_assetRecommendationsPath)
          .catchError((_) => '[]');

      final analyzedDecoded = json.decode(analyzedJson);
      if (analyzedDecoded is! List) {
        return [];
      }

      final recommendationDecoded = json.decode(recommendationsJson);
      final recommendationMap = <String, Map<String, dynamic>>{};

      if (recommendationDecoded is List) {
        for (final entry in recommendationDecoded) {
          if (entry is Map<String, dynamic>) {
            final id = entry['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              recommendationMap[id] = {
                'cases_used': entry['cases_used'] as List<dynamic>? ?? [],
                'recommendation': entry['recommendation'] as String? ?? '',
              };
            }
          }
        }
      }

      final mergedReviews = analyzedDecoded.map<Map<String, dynamic>>((item) {
        final review = Map<String, dynamic>.from(item as Map);
        final id = review['id']?.toString() ?? '';
        final recData = recommendationMap[id];
        if (recData != null) {
          final cases = recData['cases_used'] as List<dynamic>?;
          final recommendation = recData['recommendation'] as String?;
          
          if (cases != null && cases.isNotEmpty) {
            review['cases_used'] = cases;
          }
          if (recommendation != null && recommendation.isNotEmpty) {
            review['recommendation'] = recommendation;
          }
        }
        return review;
      }).toList();

      final reviews = mergedReviews
          .map<ReviewData>((json) => ReviewData.fromJson(json))
          .toList();
      debugPrint('Loaded ${reviews.length} bundled reviews.');
      return reviews;
    } catch (e) {
      debugPrint('Unable to load bundled reviews assets: $e');
      return [];
    }
  }

  static List<ReviewData> _loadFallbackReviews(String reason) {
    debugPrint('Using fallback review data: $reason');
    final List<dynamic> jsonList = json.decode(_fallbackReviewsJson);
    return jsonList.map((json) => ReviewData.fromJson(json)).toList();
  }

  // Get reviews by sentiment
  static List<ReviewData> getReviewsBySentiment(
      List<ReviewData> reviews, String sentiment) {
    return reviews.where((r) => r.sentiment == sentiment).toList();
  }

  // Get unique issues from reviews
  static Map<String, List<ReviewData>> getReviewsByIssueType(
      List<ReviewData> reviews) {
    final Map<String, List<ReviewData>> issueMap = {};

    for (var review in reviews) {
      if (review.sentiment == 'negative') {
        for (var issue in review.issues) {
          if (!issueMap.containsKey(issue.issue)) {
            issueMap[issue.issue] = [];
          }
          if (!issueMap[issue.issue]!.contains(review)) {
            issueMap[issue.issue]!.add(review);
          }
        }
      }
    }

    return issueMap;
  }

  // Get stats
  static Map<String, dynamic> getReviewStats(List<ReviewData> reviews) {
    int positiveCount = 0;
    int negativeCount = 0;

    for (var review in reviews) {
      if (review.sentiment == 'positive') {
        positiveCount++;
      } else if (review.sentiment == 'negative') {
        negativeCount++;
      }
    }

    return {
      'total': reviews.length,
      'positive': positiveCount,
      'negative': negativeCount,
      'positivePercentage': reviews.isNotEmpty
          ? ((positiveCount / reviews.length) * 100).toStringAsFixed(1)
          : '0',
      'negativePercentage': reviews.isNotEmpty
          ? ((negativeCount / reviews.length) * 100).toStringAsFixed(1)
          : '0',
    };
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/review_model.dart';

class ReviewsService {
  // Replace with your actual backend API endpoint
  static const String reviewsJsonUrl =
      'http://192.168.1.100:8000/api/reviews'; // Update to your API

  static Future<List<ReviewData>> fetchReviews() async {
    try {
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
        throw Exception('Failed to load reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching reviews: $e');
    }
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

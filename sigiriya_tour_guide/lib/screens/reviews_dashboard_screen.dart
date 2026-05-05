import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import 'issue_detail_screen.dart';

class ReviewsDashboardScreen extends StatefulWidget {
  const ReviewsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReviewsDashboardScreen> createState() => _ReviewsDashboardScreenState();
}

class _ReviewsDashboardScreenState extends State<ReviewsDashboardScreen> {
  late Future<List<ReviewData>> _reviewsFuture;
  List<ReviewData> _allReviews = [];
  Map<String, dynamic> _stats = {};
  Map<String, List<ReviewData>> _issueMap = {};

  @override
  void initState() {
    super.initState();
    _reviewsFuture = ReviewsService.fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sigiriya Review Analysis'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF8B4513),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning, color: Color(0xFFE53935)),
            tooltip: 'Show Negative Reviews & Solutions',
            onPressed: () {
              Navigator.pushNamed(context, '/negative-reviews');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ReviewData>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _reviewsFuture = ReviewsService.fetchReviews();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No reviews found'),
            );
          }

          _allReviews = snapshot.data!;
          _stats = ReviewsService.getReviewStats(_allReviews);
          _issueMap = ReviewsService.getReviewsByIssueType(_allReviews);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reviewsFuture = ReviewsService.fetchReviews();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Section
                    _buildStatisticsSection(),
                    const SizedBox(height: 24),

                    // Issues Category Section
                    Text(
                      'Issues by Category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildIssuesGrid(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      children: [
        // Total and Sentiment Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Reviews',
                value: _stats['total'].toString(),
                icon: Icons.comment,
                color: const Color(0xFF673AB7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Positive',
                value: _stats['positive'].toString(),
                subtitle: '${_stats['positivePercentage']}%',
                icon: Icons.thumb_up,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Negative',
                value: _stats['negative'].toString(),
                subtitle: '${_stats['negativePercentage']}%',
                icon: Icons.thumb_down,
                color: const Color(0xFFE53935),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesGrid() {
    return Column(
      children: _issueMap.entries.map((entry) {
        final issueName = entry.key;
        final issueReviews = entry.value;
        final percentage =
            (issueReviews.length / _stats['negative'] * 100).toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IssueDetailScreen(
                    issueType: issueName,
                    reviews: issueReviews,
                    totalNegativeReviews: _stats['negative'],
                  ),
                ),
              );
            },
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: _getIssueColor(issueName),
                      width: 4,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issueName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${issueReviews.length} reviews',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getIssueColor(issueName).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getIssueColor(issueName),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: issueReviews.length / _stats['negative'],
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getIssueColor(issueName),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getIssueColor(String issue) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFFF57C00),
      const Color(0xFFFBC02D),
      const Color(0xFF7CB342),
      const Color(0xFF0288D1),
      const Color(0xFF512DA8),
    ];

    return colors[issue.hashCode % colors.length];
  }
}

import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import 'issue_detail_screen.dart';

// ── Theme colours matching the admin dashboard ────────────────────────────────
const _navy   = Color(0xFF0D2039);
const _teal   = Color(0xFF3D4E5C);
const _green  = Color(0xFF4CAF50);
const _red    = Color(0xFFE53935);
const _amber  = Color(0xFFFBC02D);
const _white  = Colors.white;

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
    return FutureBuilder<List<ReviewData>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: _red),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(
                      () => _reviewsFuture = ReviewsService.fetchReviews()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No reviews found'));
        }

        _allReviews = snapshot.data!;
        _stats   = ReviewsService.getReviewStats(_allReviews);
        _issueMap = ReviewsService.getReviewsByIssueType(_allReviews);

        return RefreshIndicator(
          onRefresh: () async => setState(
              () => _reviewsFuture = ReviewsService.fetchReviews()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(),
                      const SizedBox(height: 28),
                      _buildSectionTitle('Issues by Category'),
                      const SizedBox(height: 12),
                      _buildIssueList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _teal],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'AI ANALYSIS',
                  style: TextStyle(
                      fontSize: 10,
                      color: _white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent),
                tooltip: 'Negative Reviews',
                onPressed: () =>
                    Navigator.pushNamed(context, '/negative-reviews'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Visitor Review\nAnalysis',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _white,
                height: 1.2,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Sigiriya Rock Fortress — AI powered insights',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.75),
                height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── STAT CARDS ─────────────────────────────────────────────────────────────
  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total',
            value: '${_stats['total'] ?? 0}',
            icon: Icons.rate_review_outlined,
            color: _teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Positive',
            value: '${_stats['positive'] ?? 0}',
            sub: '${_stats['positivePercentage'] ?? 0}%',
            icon: Icons.thumb_up_outlined,
            color: _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Negative',
            value: '${_stats['negative'] ?? 0}',
            sub: '${_stats['negativePercentage'] ?? 0}%',
            icon: Icons.thumb_down_outlined,
            color: _red,
          ),
        ),
      ],
    );
  }

  // ── SECTION TITLE ──────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
      ],
    );
  }

  // ── ISSUE LIST ─────────────────────────────────────────────────────────────
  Widget _buildIssueList() {
    final entries = _issueMap.entries.toList();
    final negCount = (_stats['negative'] as int?) ?? 1;

    return Column(
      children: entries.map((entry) {
        final name     = entry.key;
        final reviews  = entry.value;
        final pct      = (reviews.length / negCount * 100).toStringAsFixed(1);
        final ratio    = reviews.length / negCount;
        final color    = _issueColor(name);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IssueDetailScreen(
                issueType: name,
                reviews: reviews,
                totalNegativeReviews: negCount,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 3),
                          Text('${reviews.length} reviews',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$pct%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // cycle through a palette that matches the app
  Color _issueColor(String issue) {
    const palette = [
      Color(0xFF3D4E5C),
      Color(0xFF5B8A9F),
      Color(0xFFF57C00),
      Color(0xFF4CAF50),
      Color(0xFF7D6B91),
      Color(0xFFE53935),
    ];
    return palette[issue.hashCode.abs() % palette.length];
  }
}

// ── STAT CARD ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          if (sub != null)
            Text(sub!,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
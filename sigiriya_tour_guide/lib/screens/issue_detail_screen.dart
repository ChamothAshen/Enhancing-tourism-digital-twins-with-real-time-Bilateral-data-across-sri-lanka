import 'package:flutter/material.dart';
import '../models/review_model.dart';
import 'review_detail_screen.dart';

class IssueDetailScreen extends StatefulWidget {
  final String issueType;
  final List<ReviewData> reviews;
  final int totalNegativeReviews;

  const IssueDetailScreen({
    Key? key,
    required this.issueType,
    required this.reviews,
    required this.totalNegativeReviews,
  }) : super(key: key);

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  late List<ReviewData> _filteredReviews;
  String _sortBy = 'recent'; // recent, rating, confidence

  @override
  void initState() {
    super.initState();
    _filteredReviews = List.from(widget.reviews);
    _sortReviews();
  }

  void _sortReviews() {
    switch (_sortBy) {
      case 'rating':
        _filteredReviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'confidence':
        // Sort by max confidence of issues
        _filteredReviews.sort((a, b) {
          double maxConfA = a.issues.isEmpty
              ? 0
              : a.issues.map((e) => e.confidence).reduce((x, y) => x > y ? x : y);
          double maxConfB = b.issues.isEmpty
              ? 0
              : b.issues.map((e) => e.confidence).reduce((x, y) => x > y ? x : y);
          return maxConfB.compareTo(maxConfA);
        });
        break;
      default:
        // Keep original order (recent)
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final percentage =
        (widget.reviews.length / widget.totalNegativeReviews * 100)
            .toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.issueType),
        backgroundColor: const Color(0xFF8B4513),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF8B4513),
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
                              'Affected Reviews',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.reviews.length.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'of all negative reviews',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Sort Options
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort by',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortButton('Recent', 'recent'),
                        const SizedBox(width: 8),
                        _buildSortButton('Rating', 'rating'),
                        const SizedBox(width: 8),
                        _buildSortButton('Confidence', 'confidence'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Reviews List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredReviews.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildReviewCard(context, _filteredReviews[index]);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _sortBy = value;
          _sortReviews();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF8B4513) : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildReviewCard(BuildContext context, ReviewData review) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailScreen(review: review),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getReviewBorderColor(review.rating),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author and Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.author,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review.time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: _getReviewBorderColor(review.rating),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${review.rating}/5',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getReviewBorderColor(review.rating),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Review Text
              Text(
                review.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Issues Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.issues.take(3).map((issue) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE53935).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      issue.issue,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // View Details Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ReviewDetailScreen(review: review),
                      ),
                    );
                  },
                  child: const Text('View Solutions →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getReviewBorderColor(int rating) {
    if (rating >= 4) return const Color(0xFF4CAF50);
    if (rating >= 3) return const Color(0xFFFBC02D);
    return const Color(0xFFE53935);
  }
}

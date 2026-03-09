import 'package:flutter/material.dart';
import 'feedback_data.dart';
import 'issue_detail_screen.dart';

class FeedbackDashboardScreen extends StatefulWidget {
  const FeedbackDashboardScreen({super.key});

  @override
  State<FeedbackDashboardScreen> createState() =>
      _FeedbackDashboardScreenState();
}

class _FeedbackDashboardScreenState extends State<FeedbackDashboardScreen> {
  final FeedbackDataManager _dataManager = FeedbackDataManager();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _dataManager.loadData();
    if (mounted) {
      setState(() => _isLoading = false);
      debugPrint('=== Feedback Dashboard Stats ===');
      debugPrint(
        'Total feedbacks loaded: ${_dataManager.getTotalFeedbackCount()}',
      );
      for (var issueType in issueTypes) {
        debugPrint('${issueType.name}: ${issueType.feedbackCount} feedbacks');
      }
      debugPrint('================================');
    }
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
              Text('Loading feedback data...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Summary stats row
            Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withAlpha(180),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Feedback Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCard(
                          'Total Reviews',
                          _dataManager.getTotalFeedbackCount().toString(),
                          Icons.comment,
                        ),
                        SizedBox(width: 16),
                        _buildStatCard(
                          'Categories',
                          issueTypes.length.toString(),
                          Icons.category,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Section title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sentiment_dissatisfied,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tap a category to view feedbacks & solutions',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Issue type grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate grid height based on number of items
                  const crossAxisCount = 2;
                  const mainAxisSpacing = 12.0;
                  const crossAxisSpacing = 12.0;
                  const childAspectRatio = 0.95;

                  final itemWidth =
                      (constraints.maxWidth -
                          crossAxisSpacing * (crossAxisCount - 1)) /
                      crossAxisCount;
                  final itemHeight = itemWidth / childAspectRatio;
                  final rows = (issueTypes.length / crossAxisCount).ceil();
                  final gridHeight =
                      (itemHeight * rows) + (mainAxisSpacing * (rows - 1));

                  return SizedBox(
                    height: gridHeight,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: mainAxisSpacing,
                            crossAxisSpacing: crossAxisSpacing,
                            childAspectRatio: childAspectRatio,
                          ),
                      itemCount: issueTypes.length,
                      itemBuilder: (context, index) {
                        final issueType = issueTypes[index];
                        return _IssueTypeCard(
                          issueType: issueType,
                          dataManager: _dataManager,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _getShortName(String name) {
    if (name.length > 10) {
      return '${name.substring(0, 8)}...';
    }
    return name;
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueTypeCard extends StatelessWidget {
  final IssueType issueType;
  final FeedbackDataManager dataManager;

  const _IssueTypeCard({required this.issueType, required this.dataManager});

  @override
  Widget build(BuildContext context) {
    final feedbackList = dataManager.getFeedbacksByCategory(issueType.id);
    final top3 = feedbackList.take(3).toList();

    // Debug logging
    debugPrint(
      'Card: ${issueType.name} - ${issueType.feedbackCount} total, ${feedbackList.length} retrieved',
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPreviewDialog(context, top3, feedbackList.length),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and count badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: issueType.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      issueType.icon,
                      color: issueType.color,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: issueType.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${issueType.feedbackCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(
                issueType.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description
              Text(
                issueType.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Tap hint
              Row(
                children: [
                  Icon(Icons.touch_app, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to preview',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreviewDialog(
    BuildContext context,
    List<FeedbackItem> top3,
    int totalCount,
  ) {
    final hasMore = totalCount > 3;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: issueType.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(issueType.icon, color: issueType.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issueType.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Top ${top3.length} Recent Feedbacks',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Feedback list
                Expanded(
                  child: top3.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No feedbacks in this category',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: top3.length,
                          itemBuilder: (context, index) {
                            final feedback = top3[index];
                            return _FeedbackPreviewCard(
                              feedback: feedback,
                              index: index + 1,
                              color: issueType.color,
                            );
                          },
                        ),
                ),
                // Action button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IssueDetailScreen(
                              issueType: issueType,
                              dataManager: dataManager,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: Text(
                        hasMore ? 'View All ($totalCount)' : 'View All',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FeedbackPreviewCard extends StatelessWidget {
  final FeedbackItem feedback;
  final int index;
  final Color color;

  const _FeedbackPreviewCard({
    required this.feedback,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(
                  '#$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Rating stars
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < feedback.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  );
                }),
              ),
              const Spacer(),
              Text(
                _formatDate(feedback.date),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            feedback.reviewText,
            style: const TextStyle(fontSize: 13),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Confidence indicator
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: _getConfidenceColor(feedback.confidence),
              ),
              const SizedBox(width: 4),
              Text(
                'Confidence: ${(feedback.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.split(' ')[0]);
      const months = [
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
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

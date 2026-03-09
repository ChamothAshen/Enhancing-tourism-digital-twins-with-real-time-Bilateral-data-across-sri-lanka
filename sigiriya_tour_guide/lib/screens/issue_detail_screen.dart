import 'package:flutter/material.dart';
import 'feedback_data.dart';

class IssueDetailScreen extends StatefulWidget {
  final IssueType issueType;
  final FeedbackDataManager dataManager;

  const IssueDetailScreen({
    super.key,
    required this.issueType,
    required this.dataManager,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackList = widget.dataManager.getFeedbacksByCategory(widget.issueType.id);
    final solutionList = widget.dataManager.getSolutionsByIssueType(widget.issueType.id);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: widget.issueType.color,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.issueType.color,
                        widget.issueType.color.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 16, 16, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.issueType.icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.issueType.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${feedbackList.length} feedbacks • ${solutionList.length} solutions',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.comment, size: 20),
                    text: 'Feedbacks (${feedbackList.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.lightbulb, size: 20),
                    text: 'Solutions (${solutionList.length})',
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _FeedbackListTab(
              feedbacks: feedbackList,
              color: widget.issueType.color,
            ),
            _SolutionsTab(
              solutions: solutionList,
              color: widget.issueType.color,
              issueType: widget.issueType,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackListTab extends StatelessWidget {
  final List<FeedbackItem> feedbacks;
  final Color color;

  const _FeedbackListTab({
    required this.feedbacks,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (feedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No feedbacks found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: feedbacks.length,
      itemBuilder: (context, index) {
        final feedback = feedbacks[index];
        return _FeedbackCard(
          feedback: feedback,
          index: index + 1,
          color: color,
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackItem feedback;
  final int index;
  final Color color;

  const _FeedbackCard({
    required this.feedback,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Rating stars
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRatingColor(feedback.rating).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < feedback.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: _getRatingColor(feedback.rating),
                        );
                      }),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(feedback.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Comment
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: color,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                '"${feedback.reviewText}"',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Confidence bar
            Row(
              children: [
                _ConfidenceIndicator(confidence: feedback.confidence),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showFeedbackDetails(context),
                  icon: const Icon(Icons.more_horiz, size: 18),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating <= 1) return Colors.red;
    if (rating == 2) return Colors.orange;
    if (rating == 3) return Colors.amber;
    if (rating == 4) return Colors.lightGreen;
    return Colors.green;
  }

  void _showFeedbackDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: color),
            const SizedBox(width: 8),
            const Text('Feedback Analysis'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                label: 'Review ID',
                value: '#${feedback.reviewId}',
                icon: Icons.tag,
              ),
              _DetailRow(
                label: 'Rating',
                value: '${feedback.rating}/5 stars',
                icon: Icons.star,
              ),
              _DetailRow(
                label: 'Date',
                value: _formatDate(feedback.date),
                icon: Icons.calendar_today,
              ),
              _DetailRow(
                label: 'Category',
                value: feedback.category,
                icon: Icons.category,
              ),
              _DetailRow(
                label: 'Confidence',
                value: '${(feedback.confidence * 100).toStringAsFixed(1)}%',
                icon: Icons.psychology,
              ),
              const SizedBox(height: 12),
              const Text(
                'Full Review:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(feedback.reviewText),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.split(' ')[0]);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const _ConfidenceIndicator({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.red;
    
    final label = confidence >= 0.7
        ? 'High'
        : confidence >= 0.4
            ? 'Medium'
            : 'Low';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.psychology, size: 20, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label (${(confidence * 100).toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SolutionsTab extends StatelessWidget {
  final List<Solution> solutions;
  final Color color;
  final IssueType issueType;

  const _SolutionsTab({
    required this.solutions,
    required this.color,
    required this.issueType,
  });

  @override
  Widget build(BuildContext context) {
    if (solutions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No solutions available yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Global solutions database being updated',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tips_and_updates,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Global Best Practices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Solutions from ${_getUniqueSites(solutions)} world heritage sites',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Solutions list
        ...solutions.asMap().entries.map((entry) {
          return _SolutionCard(
            solution: entry.value,
            index: entry.key + 1,
            color: color,
          );
        }),
      ],
    );
  }

  int _getUniqueSites(List<Solution> solutions) {
    return solutions.map((s) => s.touristSite).toSet().length;
  }
}

class _SolutionCard extends StatelessWidget {
  final Solution solution;
  final int index;
  final Color color;

  const _SolutionCard({
    required this.solution,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Location badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        solution.touristSite,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Country flag placeholder
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    solution.country,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Solution title
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      solution.solution,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Solution description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Colors.green[400]!,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Implementation Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    solution.solutionDescription,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

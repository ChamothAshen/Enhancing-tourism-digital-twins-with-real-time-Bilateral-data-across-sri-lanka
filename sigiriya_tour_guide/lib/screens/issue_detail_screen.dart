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
    final feedbackList =
        widget.dataManager.getFeedbacksByCategory(widget.issueType.id);
    final solutionList =
        widget.dataManager.getSolutionsByIssueType(widget.issueType.id);

    // Group solutions by description
    final Map<String, List<Solution>> groupedSolutions = {};
    for (var s in solutionList) {
      final key = s.solutionDescription.trim();
      groupedSolutions.putIfAbsent(key, () => []).add(s);
    }

    final uniqueSolutions = groupedSolutions.values.toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: widget.issueType.color,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.issueType.color,
                      widget.issueType.color.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.issueType.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.issueType.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${feedbackList.length} feedbacks',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
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
                  text: 'Solutions (${uniqueSolutions.length})',
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FeedbackListTab(
              feedbacks: feedbackList,
              color: widget.issueType.color,
            ),
            _SolutionsTab(
              groupedSolutions: groupedSolutions,
              color: widget.issueType.color,
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------
/// Feedback Tab
/// -----------------------------------
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
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    '$index',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < feedback.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: color,
                        );
                      }),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  feedback.date.split(' ')[0],
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              feedback.reviewText,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------
/// Solutions Tab
/// -----------------------------------
class _SolutionsTab extends StatelessWidget {
  final Map<String, List<Solution>> groupedSolutions;
  final Color color;

  const _SolutionsTab({
    required this.groupedSolutions,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueSolutions = groupedSolutions.values.toList();

    if (uniqueSolutions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No solutions available',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: uniqueSolutions.length,
      itemBuilder: (context, index) {
        final solList = uniqueSolutions[index];
        final solution = solList[0];
        final countries = solList.map((s) => s.country).toSet();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.08), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lightbulb, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(solution.solution,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                /// Countries
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: countries.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(c,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                /// Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: Colors.green, width: 3),
                    ),
                  ),
                  child: Text(solution.solutionDescription,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(Icons.travel_explore, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text("${countries.length} countries implemented this",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
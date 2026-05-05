import 'package:flutter/material.dart';
import '../models/review_model.dart';

class ReviewDetailScreen extends StatefulWidget {
  final ReviewData review;

  const ReviewDetailScreen({
    Key? key,
    required this.review,
  }) : super(key: key);

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Details'),
        backgroundColor: const Color(0xFF8B4513),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReviewHeaderCard(),
            _buildTabNavigation(),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFF8B4513)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.review.author,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(widget.review.time,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getSentimentColor(widget.review.sentiment)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _getSentimentColor(widget.review.sentiment)),
                ),
                child: Row(
                  children: [
                    Icon(_getSentimentIcon(widget.review.sentiment),
                        color: _getSentimentColor(widget.review.sentiment),
                        size: 16),
                    const SizedBox(width: 4),
                    Text(widget.review.sentiment.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                _getSentimentColor(widget.review.sentiment))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < widget.review.rating ? Icons.star : Icons.star_outline,
                color: Colors.amber,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${widget.review.rating} out of 5',
              style:
                  const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _tab('Review', 0),
          _tab('Issues', 1),
          _tab('Solutions', 2),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? const Color(0xFF8B4513)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF8B4513)
                      : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildReviewTab();
      case 1:
        return _buildIssuesTab();
      case 2:
        return _buildSolutionsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildReviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Full Review',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(widget.review.text,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333333),
                    height: 1.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identified Issues (${widget.review.issues.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333))),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.review.issues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildIssueCard(widget.review.issues[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Issue issue) {
    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(issue.issue,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(issue.confidence)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      '${(issue.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              _getConfidenceColor(issue.confidence))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: issue.confidence,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                    _getConfidenceColor(issue.confidence)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Confidence Level',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── SOLUTIONS TAB — shows parsed recommendation ───────────────────────────
  Widget _buildSolutionsTab() {
    final rec = widget.review.recommendation ?? '';

    if (rec.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('No action plan available',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final problem  = _extract('🔴 PROBLEM', rec);
    final global   = _extract('🌍 WHAT OTHER COUNTRIES DID', rec);
    final week     = _bullets(_extract('THIS WEEK', rec));
    final month    = _bullets(_extract('THIS MONTH', rec));
    final months3  = _bullets(_extract('IN 3 MONTHS', rec));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // PROBLEM
          if (problem.isNotEmpty) ...[
            _InfoBlock(
              color: const Color(0xFFE53935),
              emoji: '🔴',
              title: 'PROBLEM',
              text: problem,
            ),
            const SizedBox(height: 12),
          ],

          // GLOBAL EXAMPLE
          if (global.isNotEmpty) ...[
            _InfoBlock(
              color: const Color(0xFFF57C00),
              emoji: '🌍',
              title: 'WHAT OTHER COUNTRIES DID',
              text: global,
            ),
            const SizedBox(height: 20),
          ],

          // TIMELINE TITLE
          const Text('WHAT SIGIRIYA SHOULD DO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),

          // THIS WEEK
          _TimelineCard(
            label: 'THIS WEEK',
            sublabel: 'Immediate',
            color: const Color(0xFF4CAF50),
            icon: Icons.flash_on_rounded,
            bullets: week,
          ),

          // THIS MONTH
          _TimelineCard(
            label: 'THIS MONTH',
            sublabel: '30 days',
            color: const Color(0xFF2196F3),
            icon: Icons.calendar_month_rounded,
            bullets: month,
          ),

          // IN 3 MONTHS
          _TimelineCard(
            label: 'IN 3 MONTHS',
            sublabel: 'Strategic',
            color: const Color(0xFF9C27B0),
            icon: Icons.rocket_launch_rounded,
            bullets: months3,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _extract(String key, String rec) {
    try {
      final start = rec.indexOf(key);
      if (start == -1) return '';
      var after = rec.substring(start + key.length);
      after = after.replaceFirst(RegExp(r'^:?\s*'), '');
      const stops = ['🔴', '🌍', '✅', 'THIS WEEK', 'THIS MONTH',
                     'IN 3 MONTHS', 'SRI LANKA IMPLEMENTATION'];
      int end = after.length;
      for (final s in stops) {
        final idx = after.indexOf(s);
        if (idx > 0 && idx < end) end = idx;
      }
      return after.substring(0, end).trim();
    } catch (_) {
      return '';
    }
  }

  List<String> _bullets(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => l.replaceFirst(RegExp(r'^[-•]\s*'), ''))
      .where((l) => l.isNotEmpty)
      .toList();

  Color _getSentimentColor(String s) {
    if (s == 'positive') return const Color(0xFF4CAF50);
    if (s == 'negative') return const Color(0xFFE53935);
    return const Color(0xFFFBC02D);
  }

  IconData _getSentimentIcon(String s) {
    if (s == 'positive') return Icons.thumb_up;
    if (s == 'negative') return Icons.thumb_down;
    return Icons.help_outline;
  }

  Color _getConfidenceColor(double c) {
    if (c >= 0.8) return const Color(0xFF4CAF50);
    if (c >= 0.6) return const Color(0xFFFBC02D);
    return const Color(0xFFE53935);
  }
}

// ── INFO BLOCK ────────────────────────────────────────────────────────────────
class _InfoBlock extends StatelessWidget {
  final Color color;
  final String emoji;
  final String title;
  final String text;
  const _InfoBlock(
      {required this.color,
      required this.emoji,
      required this.title,
      required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF333333), height: 1.6)),
        ],
      ),
    );
  }
}

// ── TIMELINE CARD ─────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final List<String> bullets;
  final bool isLast;
  const _TimelineCard(
      {required this.label,
      required this.sublabel,
      required this.color,
      required this.icon,
      required this.bullets,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // spine
          SizedBox(
            width: 44,
            child: Column(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey[300],
                  ),
                ),
              if (isLast) const SizedBox(height: 16),
            ]),
          ),
          const SizedBox(width: 10),
          // card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(sublabel,
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (bullets.isEmpty)
                      Text('No actions listed.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic))
                    else
                      ...bullets.map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(b,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF444444),
                                          height: 1.55)),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
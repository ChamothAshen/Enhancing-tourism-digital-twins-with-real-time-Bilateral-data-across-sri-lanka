import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import 'solution_detail_screen.dart';

const _bg = Color(0xFF0F0F13);
const _surface = Color(0xFF1A1A22);
const _accent = Color(0xFFFF6B35);
const _accentSoft = Color(0x33FF6B35);
const _gold = Color(0xFFFFB547);
const _green = Color(0xFF4ECDC4);
const _textPrimary = Color(0xFFF0EBE3);
const _textSecondary = Color(0xFF9090A8);
const _divider = Color(0xFF2A2A36);

class NegativeReviewsScreen extends StatefulWidget {
  const NegativeReviewsScreen({Key? key}) : super(key: key);

  @override
  State<NegativeReviewsScreen> createState() => _NegativeReviewsScreenState();
}

class _NegativeReviewsScreenState extends State<NegativeReviewsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ReviewData>> _future;
  late AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<List<ReviewData>> _load() async {
    final all = await ReviewsService.fetchReviews();
    return all
        .where((r) =>
            r.sentiment == 'negative' &&
            r.recommendation != null &&
            r.recommendation!.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<ReviewData>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: _textSecondary)));
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return const Center(
                child: Text('No negative reviews.',
                    style: TextStyle(color: _textPrimary)));
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _headerAnim, curve: Curves.easeOut),
                  child: _Header(count: reviews.length),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _AnimatedCard(
                      delay: Duration(milliseconds: 50 * i),
                      child: _ReviewCard(review: reviews[i], index: i + 1),
                    ),
                    childCount: reviews.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0E08), Color(0xFF0F0F13)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: _accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('AI ANALYSIS',
                  style: TextStyle(
                      fontSize: 10, color: _accent,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Visitor\nComplaints',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: _textPrimary, height: 1.15, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('$count negative reviews · tap any card to see AI action plan',
              style: const TextStyle(
                  fontSize: 13, color: _textSecondary, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            _Pill(icon: Icons.flag_outlined, label: '$count reviews', color: _accent),
            const SizedBox(width: 8),
            _Pill(icon: Icons.public, label: 'Global examples', color: _gold),
            const SizedBox(width: 8),
            _Pill(icon: Icons.checklist_rounded, label: 'Action plans', color: _green),
          ]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── ANIMATED WRAPPER ──────────────────────────────────────────────────────────
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedCard({required this.child, required this.delay});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
}

// ── REVIEW CARD ───────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final ReviewData review;
  final int index;
  const _ReviewCard({required this.review, required this.index});

  Color _starColor(int r) {
    if (r <= 1) return const Color(0xFFE53935);
    if (r <= 2) return _accent;
    return _gold;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP ROW ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index badge
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_accent, Color(0xFFFF4500)]),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text('$index',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.author.isNotEmpty ? review.author : 'Anonymous',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(review.time,
                          style: const TextStyle(
                              fontSize: 11, color: _textSecondary)),
                    ],
                  ),
                ),
                // Star rating
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 13,
                      color: i < review.rating
                          ? _starColor(review.rating)
                          : _textSecondary.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── REVIEW TEXT ───────────────────────────────────────────────
            Text(
              review.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: _textSecondary, height: 1.55),
            ),
            const SizedBox(height: 10),

            // ── ISSUE CHIPS ───────────────────────────────────────────────
            if (review.issues.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: review.issues.take(3).map((iss) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      '${iss.issue}  ${(iss.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10,
                          color: _accent,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),
            Divider(height: 1, color: _divider),
            const SizedBox(height: 10),

            // ── VIEW SOLUTIONS BUTTON ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SolutionDetailScreen(review: review),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: _accentSoft,
                  foregroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('View AI Solutions',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../models/review_model.dart';

const _bg = Color(0xFF0F0F13);
const _surface = Color(0xFF1A1A22);
const _accent = Color(0xFFFF6B35);
const _gold = Color(0xFFFFB547);
const _green = Color(0xFF4ECDC4);
const _blue = Color(0xFF6C9EFF);
const _purple = Color(0xFFBB86FC);
const _textPrimary = Color(0xFFF0EBE3);
const _textSecondary = Color(0xFF9090A8);
const _divider = Color(0xFF2A2A36);

class SolutionDetailScreen extends StatelessWidget {
  final ReviewData review;
  const SolutionDetailScreen({Key? key, required this.review}) : super(key: key);

  String _extract(String startKey, String rec) {
    try {
      final start = rec.indexOf(startKey);
      if (start == -1) return '';
      final after = rec.substring(start + startKey.length).trim();
      // Find next section marker
      final markers = ['🔴', '🌍', '✅', 'THIS WEEK', 'THIS MONTH', 'IN 3 MONTHS', 'SRI LANKA IMPLEMENTATION'];
      int end = after.length;
      for (final m in markers) {
        final idx = after.indexOf(m);
        if (idx > 0 && idx < end) end = idx;
      }
      return after.substring(0, end).trim();
    } catch (_) {
      return '';
    }
  }

  List<String> _bullets(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.replaceFirst(RegExp(r'^[-•]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final rec = review.recommendation ?? '';
    final problem = _extract('🔴 PROBLEM', rec).replaceFirst(RegExp(r'^:?\s*'), '');
    final global = _extract('🌍 WHAT OTHER COUNTRIES DID', rec).replaceFirst(RegExp(r'^:?\s*'), '');
    final week = _bullets(_extract('THIS WEEK', rec).replaceFirst(RegExp(r'^:?\s*'), ''));
    final month = _bullets(_extract('THIS MONTH', rec).replaceFirst(RegExp(r'^:?\s*'), ''));
    final months3 = _bullets(_extract('IN 3 MONTHS', rec).replaceFirst(RegExp(r'^:?\s*'), ''));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Action Plan',
            style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── PROBLEM ──────────────────────────────────────────────────
            if (problem.isNotEmpty) ...[
              _Block(
                emoji: '🔴',
                title: 'PROBLEM',
                color: _accent,
                child: Text(problem,
                    style: const TextStyle(
                        fontSize: 14, color: _textPrimary, height: 1.6)),
              ),
              const SizedBox(height: 12),
            ],

            // ── GLOBAL EXAMPLE ───────────────────────────────────────────
            if (global.isNotEmpty) ...[
              _Block(
                emoji: '🌍',
                title: 'WHAT OTHER COUNTRIES DID',
                color: _gold,
                child: Text(global,
                    style: const TextStyle(
                        fontSize: 14, color: _textPrimary, height: 1.6)),
              ),
              const SizedBox(height: 20),
            ],

            // ── TIMELINE LABEL ───────────────────────────────────────────
            const Text('WHAT SIGIRIYA SHOULD DO',
                style: TextStyle(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),

            // ── THIS WEEK ────────────────────────────────────────────────
            _TimelineCard(
              label: 'THIS WEEK',
              sublabel: 'Immediate',
              icon: Icons.flash_on_rounded,
              color: _green,
              bullets: week,
            ),

            // ── THIS MONTH ───────────────────────────────────────────────
            _TimelineCard(
              label: 'THIS MONTH',
              sublabel: '30 days',
              icon: Icons.calendar_month_rounded,
              color: _blue,
              bullets: month,
            ),

            // ── IN 3 MONTHS ──────────────────────────────────────────────
            _TimelineCard(
              label: 'IN 3 MONTHS',
              sublabel: 'Strategic',
              icon: Icons.rocket_launch_rounded,
              color: _purple,
              bullets: months3,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── BLOCK (problem / global) ──────────────────────────────────────────────────
class _Block extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;
  final Widget child;
  const _Block({required this.emoji, required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── TIMELINE CARD ─────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final List<String> bullets;
  final bool isLast;
  const _TimelineCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.bullets,
    this.isLast = false,
  });

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
                  color: color.withOpacity(0.12),
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
                    color: _divider,
                  ),
                ),
              if (isLast) const SizedBox(height: 16),
            ]),
          ),
          const SizedBox(width: 10),
          // content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(sublabel,
                            style: TextStyle(
                                fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (bullets.isEmpty)
                      Text('No actions listed.',
                          style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary.withOpacity(0.5),
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
                                      color: color.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(b,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _textSecondary,
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
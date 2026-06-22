// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../widgets/weekly_review_chart_painter.dart';
import '../services/supabase_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _isRankingTab = true; // Tab toggle: Ranking vs Insight

  // Stats Data
  int _evalsCount = 0;
  List<dynamic> _earlySupportedPosts = [];
  dynamic _topReview;
  List<double> _chartValues = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  double _percentChange = 0.0;
  List<Map<String, dynamic>> _topSupportedTags = [];

  // Leaderboard Rankings
  List<dynamic> _rankings = [];
  bool _isLoadingRankings = true;
  String _selectedRankType = 'early_discoverer'; // early_discoverer | supporter | creator

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchRankings();
  }

  Future<void> _fetchStats() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Weekly evaluations count & percentage change (compare last 7 days vs 7-14 days ago)
      final nowTime = DateTime.now();
      final weekAgo = nowTime.subtract(const Duration(days: 7));
      final twoWeeksAgo = nowTime.subtract(const Duration(days: 14));

      final evalsList = await SupabaseService.getEvaluationsSince(uid, twoWeeksAgo);

      int thisWeekCount = 0;
      int lastWeekCount = 0;

      final List<double> chartValues = List.filled(7, 0.0);
      final counts = List.filled(7, 0);

      for (final item in evalsList) {
        try {
          final dt = DateTime.parse(item['created_at']).toLocal();
          if (dt.isAfter(weekAgo)) {
            thisWeekCount++;
            final idx = dt.weekday - 1; // 0 = Mon, 6 = Sun
            if (idx >= 0 && idx < 7) {
              counts[idx]++;
            }
          } else {
            lastWeekCount++;
          }
        } catch (_) {}
      }

      final maxCount = counts.reduce((a, b) => a > b ? a : b);
      if (maxCount > 0) {
        for (int i = 0; i < 7; i++) {
          chartValues[i] = counts[i] / maxCount;
        }
      }

      double percentChange = 0.0;
      if (lastWeekCount > 0) {
        percentChange = ((thisWeekCount - lastWeekCount) / lastWeekCount) * 100;
      } else if (thisWeekCount > 0) {
        percentChange = 100.0;
      }

      // 2. Early supported posts
      final earlyEvals = await SupabaseService.getEarlySupportedPosts(uid);

      // 3. Top review
      final comments = await SupabaseService.getTopReviews();

      // 4. Frequently supported themes/tags
      final tagStatsResponse = await SupabaseService.getSupportedTagsForUser(uid);

      final Map<String, int> tagCounts = {};
      for (final item in tagStatsResponse) {
        final post = item['posts'];
        if (post != null) {
          final postTags = post['post_tags'] as List?;
          if (postTags != null) {
            for (final pt in postTags) {
              final tag = pt['tags'];
              if (tag != null) {
                final title = tag['title'] as String?;
                if (title != null) {
                  tagCounts[title] = (tagCounts[title] ?? 0) + 1;
                }
              }
            }
          }
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topSupportedTags = sortedTags
          .take(4)
          .map((e) => {'title': e.key, 'count': e.value})
          .toList();

      if (mounted) {
        setState(() {
          _evalsCount = thisWeekCount;
          _percentChange = percentChange;
          _chartValues = chartValues;
          _earlySupportedPosts = earlyEvals;
          _topSupportedTags = topSupportedTags;
          if (comments.isNotEmpty) {
            _topReview = comments.first;
          } else {
            _topReview = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting stats data: $e');
    }
  }

  Future<void> _fetchRankings() async {
    if (!mounted) return;
    setState(() => _isLoadingRankings = true);
    try {
      final data = await SupabaseService.getRankings(_selectedRankType);

      if (mounted) {
        setState(() {
          _rankings = data;
          _isLoadingRankings = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting rankings: $e');
      if (mounted) setState(() => _isLoadingRankings = false);
    }
  }

  String _getAgoString(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays >= 1) return '${diff.inDays}日前';
      return '今日';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: null, // Custom Header inside body
      body: SafeArea(
        child: Column(
          children: [
            // 1. Custom Header
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate back to Home tab conceptually if needed
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.centerLeft,
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.text),
                    ),
                  ),
                  Text(
                    'フィードバック',
                    style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text),
                  ),
                  const SizedBox(width: 38), // placeholder to balance back arrow
                ],
              ),
            ),

            // 2. Custom Segmented Tab Widget
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.uiGrey,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRankingTab = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          gradient: _isRankingTab
                              ? const LinearGradient(
                                  colors: [Color(0xFF0C7D78), Color(0xFF024750)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _isRankingTab ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isRankingTab
                              ? [BoxShadow(color: const Color(0xFF005F63).withOpacity(0.16), blurRadius: 9, offset: const Offset(0, 3))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'ランキング',
                          style: AppTheme.getNotoSansJP(
                            fontSize: 13,
                            fontWeight: _isRankingTab ? FontWeight.w700 : FontWeight.w600,
                            color: _isRankingTab ? Colors.white : AppTheme.sub,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRankingTab = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          gradient: !_isRankingTab
                              ? const LinearGradient(
                                  colors: [Color(0xFF0C7D78), Color(0xFF024750)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: !_isRankingTab ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isRankingTab
                              ? [BoxShadow(color: const Color(0xFF005F63).withOpacity(0.16), blurRadius: 9, offset: const Offset(0, 3))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'インサイト',
                          style: AppTheme.getNotoSansJP(
                            fontSize: 13,
                            fontWeight: !_isRankingTab ? FontWeight.w700 : FontWeight.w600,
                            color: !_isRankingTab ? Colors.white : AppTheme.sub,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Tab contents
            Expanded(
              child: _isRankingTab ? _buildRankingTabContent() : _buildInsightTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================ RANKING TAB ============================
  Widget _buildRankingTabContent() {
    return ListView(
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 112),
      children: [
        // Category selection chip row
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRankFilterChip('早期発掘者', 'early_discoverer'),
              _buildRankFilterChip('熱心な支持者', 'supporter'),
              _buildRankFilterChip('アイデア提案者', 'creator'),
            ],
          ),
        ),

        // 1. Leaderboard Ranking Container
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E22).withOpacity(0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '早期発掘者ランキング',
                    style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('今週', style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.sub)),
                        const Icon(Icons.keyboard_arrow_down, size: 12, color: AppTheme.sub),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _isLoadingRankings
                  ? const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(color: AppTheme.teal),
                    ))
                  : _rankings.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('現在ランキング情報はありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub))),
                        )
                      : Column(
                          children: List.generate(_rankings.length, (idx) {
                            final r = _rankings[idx];
                            final prof = r['profiles'];
                            final rankNum = r['rank'] ?? (idx + 1);

                            Widget rankBadge;
                            if (rankNum == 1) {
                              rankBadge = SvgPicture.string(
                                '''
                                <svg width="22" height="22" viewBox="0 0 24 24" fill="#cda86a">
                                  <path d="M2 8l4.5 3L12 4l5.5 7L22 8l-2 11H4L2 8z"/>
                                  <circle cx="4" cy="6" r="1.6"/>
                                  <circle cx="12" cy="2.6" r="1.6"/>
                                  <circle cx="20" cy="6" r="1.6"/>
                                </svg>
                                ''',
                                width: 22,
                                height: 22,
                              );
                            } else if (rankNum == 2 || rankNum == 3) {
                              rankBadge = Text(
                                '$rankNum',
                                style: AppTheme.getManrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: rankNum == 2 ? const Color(0xFF0D8F88) : const Color(0xFFC9783C),
                                ).copyWith(fontStyle: FontStyle.italic),
                              );
                            } else {
                              rankBadge = Text('$rankNum', style: AppTheme.getManrope(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.sub));
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 26,
                                    child: Center(child: rankBadge),
                                  ),
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: AppTheme.uiGrey,
                                    backgroundImage: prof?['avatar_url'] != null
                                        ? NetworkImage(prof['avatar_url'])
                                        : null,
                                    child: prof?['avatar_url'] == null
                                        ? const Icon(Icons.person, color: AppTheme.sub, size: 14)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prof?['display_name'] ?? '市民サポーター',
                                          style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                                        ),
                                        Text(
                                          '発掘 ${r['discoveries'] ?? (8 - idx)}件',
                                          style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${(r['score'] as num).toStringAsFixed(0)} ',
                                    style: AppTheme.getManrope(fontWeight: FontWeight.w800, color: AppTheme.text, fontSize: 14),
                                  ),
                                  Text(
                                    'pt',
                                    style: AppTheme.getNotoSansJP(fontWeight: FontWeight.w700, color: AppTheme.sub, fontSize: 10),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border, width: 1.5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ランキングをもっと見る',
                    style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),

        // 2. Adopted candidates early finders
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E22).withOpacity(0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '採用候補を早く見つけた人',
                style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
              ),
              const SizedBox(height: 11),
              _earlySupportedPosts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          '対象の投稿はまだありません。',
                          style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: _earlySupportedPosts.map((eval) {
                        final post = eval['posts'];
                        final prof = post?['profiles'];
                        final mediaList = post?['post_media'] as List?;
                        final mediaUrl = (mediaList != null && mediaList.isNotEmpty) ? mediaList.first['url'] : '';
                        final name = prof?['display_name'] ?? '市民サポーター';
                        final avatarUrl = prof?['avatar_url'];
                        final ago = _getAgoString(eval['created_at']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: AppTheme.uiGrey,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person, color: AppTheme.sub, size: 16) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                                    ),
                                    Text(
                                      ago,
                                      style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                                    ),
                                  ],
                                ),
                              ),
                              // Visual Thumbnail with NEW overlay badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: mediaUrl.isNotEmpty
                                        ? Image.network(
                                            mediaUrl,
                                            width: 72,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const SizedBox(
                                                width: 72,
                                                height: 50,
                                                child: Center(
                                                  child: CircularProgressIndicator(color: AppTheme.teal, strokeWidth: 2),
                                                ),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) => const SizedBox(
                                              width: 72,
                                              height: 50,
                                              child: Center(
                                                child: Icon(Icons.broken_image, color: Colors.white24, size: 16),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 72,
                                            height: 50,
                                            color: AppTheme.uiGrey,
                                            child: const Icon(Icons.image_not_supported, color: AppTheme.sub, size: 16),
                                          ),
                                  ),
                                  Positioned(
                                    top: -7,
                                    right: -7,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.teal,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(color: AppTheme.tealDark.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.04),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border, width: 1.5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'すべて見る',
                    style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),

        // 3. Weekly Top review post
        _topReview == null
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F1E22).withOpacity(0.04),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '今週のレビューはまだありません。',
                  style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F1E22).withOpacity(0.04),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '今週の注目レビュー',
                          style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEEE9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '🔥 反響大',
                            style: TextStyle(color: Color(0xFFC9783C), fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.uiGrey,
                          backgroundImage: _topReview['profiles']?['avatar_url'] != null
                              ? NetworkImage(_topReview['profiles']['avatar_url'])
                              : null,
                          child: _topReview['profiles']?['avatar_url'] == null
                              ? const Icon(Icons.person, color: AppTheme.sub, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _topReview['profiles']?['display_name'] ?? '市民サポーター',
                                    style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                                  ),
                                  if (_topReview['profiles']?['area_name'] != null)
                                    Text(
                                      ' ・${_topReview['profiles']['area_name']}',
                                      style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub, fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '「${_topReview['body'] ?? ''}」',
                                style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub, height: 1.6),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.favorite, color: AppTheme.teal, size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_topReview['posts']?['post_metrics']?['support_count'] ?? 0}人が同意',
                                    style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.teal, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E22).withOpacity(0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今週のレビュー数',
                style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.sub),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_evalsCount',
                    style: AppTheme.getManrope(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1, letterSpacing: -0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '件',
                    style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.sub),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _percentChange >= 0
                          ? const Color(0xFFE3EFED)
                          : const Color(0xFFFCE8E6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _percentChange >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 11,
                          color: _percentChange >= 0
                              ? AppTheme.teal
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _percentChange >= 0
                              ? '+${_percentChange.toStringAsFixed(0)}%'
                              : '${_percentChange.toStringAsFixed(0)}%',
                          style: AppTheme.getManrope(
                            color: _percentChange >= 0
                                ? AppTheme.teal
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // CustomPaint Vertical Bar Chart
              SizedBox(
                height: 70,
                width: double.infinity,
                child: CustomPaint(
                  painter: WeeklyReviewChartPainter(
                    values: _chartValues,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Mon-Sun labels row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const ['月', '火', '水', '木', '金', '土', '日']
                    .map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(color: AppTheme.sub, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankFilterChip(String label, String rankType) {
    final bool isSel = _selectedRankType == rankType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRankType = rankType;
          _fetchRankings();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppTheme.teal : AppTheme.border, width: 1),
        ),
        child: Text(
          label,
          style: AppTheme.getNotoSansJP(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
            color: isSel ? Colors.white : AppTheme.sub,
          ),
        ),
      ),
    );
  }

  // ============================ INSIGHT TAB ============================
  Widget _buildInsightTabContent() {
    return ListView(
      padding: const EdgeInsets.only(left: 18, right: 18, bottom: 112),
      children: [
        // 1. 3 Metric Cards Layout
        Row(
          children: [
            _buildSmallMetricCard('今週の評価数', '$_evalsCount', AppTheme.teal),
            const SizedBox(width: 10),
            _buildSmallMetricCard('早期発掘した投稿', '${_earlySupportedPosts.length}', AppTheme.gold),
            const SizedBox(width: 10),
            _buildSmallMetricCard('シーズンpt', '${_evalsCount * 10 + _earlySupportedPosts.length * 30}', AppTheme.text),
          ],
        ),
        const SizedBox(height: 13),

        // 3. Theme stats
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E22).withOpacity(0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'よく応援したテーマ',
                style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
              ),
              const SizedBox(height: 13),
              _topSupportedTags.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          '応援したテーマはまだありません。',
                          style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 12),
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(_topSupportedTags.length, (idx) {
                        final tag = _topSupportedTags[idx];
                        final String title = tag['title'];
                        final int count = tag['count'];
                        final int maxCount = _topSupportedTags.first['count'];
                        final double fraction = maxCount > 0 ? count / maxCount : 0.0;
                        return Padding(
                          padding: EdgeInsets.only(bottom: idx == _topSupportedTags.length - 1 ? 0 : 14),
                          child: _buildThemeBarRow(title, count, fraction),
                        );
                      }),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 13),

        // 4. Early supported posts list
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0C181C).withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E22).withOpacity(0.04),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '早期に応援した投稿',
                style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
              ),
              const SizedBox(height: 11),
              _earlySupportedPosts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'フリック画面で、まだ応援の少ない投稿を\nいちはやく応援すると表示されます',
                          style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 12, height: 1.7),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: _earlySupportedPosts.map((eval) {
                        final post = eval['posts'];
                        final media = post?['post_media'] as List?;
                        final primaryImg = media != null && media.isNotEmpty ? media.first['url'] : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  primaryImg,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: AppTheme.uiGrey, width: 56, height: 56),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post?['title'] ?? '無題',
                                      style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text, height: 1.4),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '🌱 みんなより早く応援しました',
                                      style: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMetricCard(String title, String val, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0D2230).withOpacity(0.06), blurRadius: 18),
          ],
        ),
        child: Column(
          children: [
            Text(
              val,
              style: AppTheme.getManrope(fontSize: 23, fontWeight: FontWeight.w900, color: valColor),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.sub, height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeBarRow(String label, int count, double fraction) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
            ),
            Text(
              '$count件',
              style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.sub),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.uiGrey,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



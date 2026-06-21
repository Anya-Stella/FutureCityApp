// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final supabase = Supabase.instance.client;
  bool _isRankingTab = true; // Tab toggle: Ranking vs Insight

  // Stats Data
  int _evalsCount = 0;
  List<dynamic> _earlySupportedPosts = [];

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
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Weekly evaluations count
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final evalsResponse = await supabase
          .from('evaluations')
          .select('id, action')
          .eq('user_id', uid)
          .gte('created_at', weekAgo);

      final evalsList = evalsResponse as List;
      final totalEvals = evalsList.length;
      final supports = evalsList.where((e) => e['action'] == 'support').length;
      final rate = totalEvals > 0 ? (supports / totalEvals) * 100 : 0.0;

      // 2. Early supported posts
      final earlyEvals = await supabase
          .from('evaluations')
          .select('*, posts(*, post_media(*), post_metrics(*))')
          .eq('user_id', uid)
          .eq('action', 'support')
          .lte('support_count_at_evaluation', 5)
          .limit(3);

      if (mounted) {
        setState(() {
          _evalsCount = totalEvals;
          _earlySupportedPosts = earlyEvals;
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
      final data = await supabase
          .from('rankings')
          .select('*, profiles(display_name, avatar_url)')
          .eq('ranking_type', _selectedRankType)
          .order('rank', ascending: true)
          .limit(5); // Show top 5 for cleaner mockup layout

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
                          color: _isRankingTab ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isRankingTab
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'ランキング',
                          style: AppTheme.getNotoSansJP(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isRankingTab ? AppTheme.text : AppTheme.sub,
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
                          color: !_isRankingTab ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isRankingTab
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'インサイト',
                          style: AppTheme.getNotoSansJP(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !_isRankingTab ? AppTheme.text : AppTheme.sub,
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

                            Widget rankBadge = Text('$rankNum', style: AppTheme.getManrope(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.sub));
                            if (rankNum == 1) rankBadge = const Text('👑', style: TextStyle(fontSize: 16));
                            if (rankNum == 2) rankBadge = const Text('🥈', style: TextStyle(fontSize: 16));
                            if (rankNum == 3) rankBadge = const Text('🥉', style: TextStyle(fontSize: 16));

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
              Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.uiGrey,
                    child: Icon(Icons.person, color: AppTheme.sub, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'たなか さとる',
                          style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                        ),
                        Text(
                          '10分前に発掘',
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
                        child: Image.network(
                          'https://images.unsplash.com/photo-1596701062351-df1f8d368a85?q=80&w=150',
                          width: 72,
                          height: 50,
                          fit: BoxFit.cover,
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
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.uiGrey,
                    child: Icon(Icons.person, color: AppTheme.sub, size: 18),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'やまざき なおこ',
                              style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                            ),
                            Text(
                              ' ・大宮区',
                              style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '「大宮駅東口の広場、車線が減るだけでこんなに歩きやすくなるんですね。ぜひ実現してほしい！」',
                          style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub, height: 1.6),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: AppTheme.teal, size: 12),
                            const SizedBox(width: 5),
                            Text(
                              '34人が同意',
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

        // 2. Weekly review vertical bar chart
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
                      color: const Color(0xFFE3EFED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward, size: 11, color: AppTheme.teal),
                        const SizedBox(width: 3),
                        Text(
                          '+12%',
                          style: AppTheme.getManrope(color: AppTheme.teal, fontSize: 12, fontWeight: FontWeight.w800),
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
                    values: const [0.2, 0.55, 0.4, 0.85, 0.35, 0.25, 0.95], // Normalized mock daily evaluations heights
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
              _buildThemeBarRow('歩道拡幅', 6, 0.8),
              const SizedBox(height: 14),
              _buildThemeBarRow('緑化', 4, 0.5),
              const SizedBox(height: 14),
              _buildThemeBarRow('ベンチ', 3, 0.4),
              const SizedBox(height: 14),
              _buildThemeBarRow('照明', 2, 0.25),
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

// ============================ CUSTOM PAINTER CHART ============================
class WeeklyReviewChartPainter extends CustomPainter {
  final List<double> values; // normalized values between 0.0 and 1.0
  WeeklyReviewChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBar = Paint()
      ..color = AppTheme.teal
      ..style = PaintingStyle.fill;

    final paintBg = Paint()
      ..color = AppTheme.uiGrey
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;
    final int count = values.length;
    final double spacing = 20.0;
    final double barWidth = (width - (spacing * (count - 1))) / count;

    for (int i = 0; i < count; i++) {
      final double x = i * (barWidth + spacing);
      final double val = values[i];
      final double barHeight = height * val;

      // Draw background bar track
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, height),
        const Radius.circular(999),
      );
      canvas.drawRRect(bgRect, paintBg);

      // Draw active fill bar
      if (barHeight > 0) {
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, height - barHeight, barWidth, barHeight),
          const Radius.circular(999),
        );
        canvas.drawRRect(fillRect, paintBar);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  // Stats Data
  int _evalsCount = 0;
  double _supportRate = 0.0;
  List<dynamic> _earlySupportedPosts = [];
  bool _isLoadingStats = true;

  // Leaderboard Rankings
  List<dynamic> _rankings = [];
  bool _isLoadingRankings = true;
  String _selectedRankType = 'early_discoverer'; // early_discoverer | supporter | creator

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStats();
    _fetchRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      // 2. Early supported posts (support_count_at_evaluation <= 5)
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
          _supportRate = rate;
          _earlySupportedPosts = earlyEvals;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting stats data: $e');
      if (mounted) setState(() => _isLoadingStats = false);
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
          .limit(10);

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
      appBar: AppBar(
        title: Text(
          '市民フィードバック',
          style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.teal,
          labelColor: AppTheme.teal,
          unselectedLabelColor: AppTheme.sub,
          tabs: const [
            Tab(text: '診断・統計'),
            Tab(text: 'ランキング'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildRankingsTab(),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.teal));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cards grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '今週の評価数',
                value: '$_evalsCount 件',
                icon: Icons.check_circle_outline,
                color: AppTheme.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: '応援支持率',
                value: '${_supportRate.toStringAsFixed(0)}%',
                icon: Icons.favorite_border,
                color: AppTheme.heart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom Paint Chart (Evaluations Activity)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '曜日別の評価傾向',
                  style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: ActivityChartPainter(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['月', '火', '水', '木', '金', '土', '日']
                      .map((day) => Text(day, style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.muted)))
                      .toList(),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Early discovery section
        Text(
          'あなたの早期応援アイデア',
          style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '支持者数が5人未満の段階で、あなたが支持した都市構想のリストです。早期に価値を見出した証明になります。',
          style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub, height: 1.4),
        ),
        const SizedBox(height: 12),
        _earlySupportedPosts.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Text('まだ該当するアイデアはありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13)),
                ),
              )
            : Column(
                children: _earlySupportedPosts.map((eval) {
                  final post = eval['posts'];
                  final media = post?['post_media'] as List?;
                  final imgUrl = media != null && media.isNotEmpty ? media.first['url'] : '';
                  final supportSnap = eval['support_count_at_evaluation'];

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(imgUrl, width: 50, height: 50, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.uiGrey, width: 50, height: 50),
                        ),
                      ),
                      title: Text(
                        post?['title'] ?? '無題',
                        style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'あなたの応援時点で $supportSnap 件目の支持',
                        style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.teal),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildRankingsTab() {
    return Column(
      children: [
        // Dropdown filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'カテゴリー別ランキング',
                style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              DropdownButton<String>(
                value: _selectedRankType,
                underline: const SizedBox(),
                style: AppTheme.getNotoSansJP(color: AppTheme.teal, fontWeight: FontWeight.bold, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'early_discoverer', child: Text('早期発掘者')),
                  DropdownMenuItem(value: 'supporter', child: Text('熱心な支持者')),
                  DropdownMenuItem(value: 'creator', child: Text('アイデア提案者')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRankType = val;
                      _fetchRankings();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(),
        // Leaderboard List
        Expanded(
          child: _isLoadingRankings
              ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
              : _rankings.isEmpty
                  ? Center(child: Text('現在ランキング情報はありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _rankings.length,
                      separatorBuilder: (_, __) => const Divider(indent: 70),
                      itemBuilder: (context, idx) {
                        final r = _rankings[idx];
                        final prof = r['profiles'];
                        final displayRank = r['rank'] ?? (idx + 1);

                        return ListTile(
                          leading: SizedBox(
                            width: 60,
                            child: Row(
                              children: [
                                Text(
                                  '#$displayRank',
                                  style: AppTheme.getManrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: displayRank == 1 ? AppTheme.gold : AppTheme.sub,
                                  ),
                                ),
                                const Spacer(),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.uiGrey,
                                  backgroundImage: prof?['avatar_url'] != null
                                      ? NetworkImage(prof['avatar_url'])
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          title: Text(
                            prof?['display_name'] ?? '市民サポーター',
                            style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            '${(r['score'] as num).toStringAsFixed(0)} P',
                            style: AppTheme.getManrope(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 13),
                          ),
                        );
                      },
                    ),
        )
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title, style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: AppTheme.getManrope(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text)),
          ],
        ),
      ),
    );
  }
}

class ActivityChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.teal
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.fill;

    final paintBg = Paint()
      ..color = AppTheme.border.withOpacity(0.4)
      ..strokeWidth = 1.0;

    // Drawing baseline grid
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paintBg);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paintBg);

    // Mock points for Mon-Sun activity
    final List<Offset> points = [
      Offset(size.width * 0.05, size.height * 0.8),  // Mon
      Offset(size.width * 0.20, size.height * 0.45), // Tue
      Offset(size.width * 0.35, size.height * 0.6),  // Wed
      Offset(size.width * 0.50, size.height * 0.2),  // Thu
      Offset(size.width * 0.65, size.height * 0.55), // Fri
      Offset(size.width * 0.80, size.height * 0.75), // Sat
      Offset(size.width * 0.95, size.height * 0.1),  // Sun
    ];

    // Draw line connecting points
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paintLine);

    // Draw points indicator dots
    for (var pt in points) {
      canvas.drawCircle(pt, 5.0, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// lib/screens/eval_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import '../services/supabase_service.dart';

class EvalScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const EvalScreen({super.key, this.onBack});

  @override
  State<EvalScreen> createState() => _EvalScreenState();
}

class _EvalScreenState extends State<EvalScreen> {
  List<dynamic> _unevaluatedPosts = [];
  bool _isLoading = true;
  final Stopwatch _dwellStopwatch = Stopwatch();
  bool _openedDetail = false;
  int _sessionEvalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSwipeFeed();
  }

  Future<void> _fetchSwipeFeed() async {
    setState(() {
      _isLoading = true;
      _sessionEvalCount = 0;
    });
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      final filtered = await SupabaseService.getUnevaluatedPosts(uid);

      if (mounted) {
        setState(() {
          _unevaluatedPosts = filtered;
          _isLoading = false;
        });
        _resetTimer();
      }
    } catch (e) {
      debugPrint('Error getting evaluation feed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetTimer() {
    _dwellStopwatch.reset();
    _dwellStopwatch.start();
    _openedDetail = false;
  }

  Future<void> _handleSwipe(String action) async {
    if (_unevaluatedPosts.isEmpty) return;

    _dwellStopwatch.stop();
    final dwellMs = _dwellStopwatch.elapsedMilliseconds;
    final activePost = _unevaluatedPosts.first;
    final uid = SupabaseService.currentUser?.id;

    if (uid == null) return;

    final metrics = activePost['post_metrics'];
    final currentSupportCount = metrics?['support_count'] ?? 0;
    final currentSupportRate = double.tryParse(metrics?['support_rate']?.toString() ?? '0') ?? 0.0;

    try {
      // Write evaluation
      await SupabaseService.insertEvaluation(
        userId: uid,
        postId: activePost['id'],
        projectId: activePost['project_id'],
        action: action,
        dwellMs: dwellMs,
        openedDetail: _openedDetail,
        supportCountAtEvaluation: currentSupportCount,
        supportRateAtEvaluation: currentSupportRate,
      );

      // Slide locally to next item
      if (mounted) {
        setState(() {
          _unevaluatedPosts.removeAt(0);
          _sessionEvalCount++;
        });
        _resetTimer();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('評価の保存に失敗しました: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openDetailScreen() {
    if (_unevaluatedPosts.isEmpty) return;
    _openedDetail = true;
    final post = _unevaluatedPosts.first;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.16),
            radius: 1.25,
            colors: [
              Color(0xFF0D2230),
              Color(0xFF07141D),
              Color(0xFF030A10),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
              : _unevaluatedPosts.isEmpty
                  ? _buildEmptyFeedPlaceholder()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Column(
                        children: [
                          // 1. Custom Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.onBack != null) {
                                        widget.onBack!();
                                      }
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.arrow_back_ios_new, size: 12, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    'みんなの投稿',
                                    style: AppTheme.getNotoSansJP(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withOpacity(0.06),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.filter_list, size: 12, color: Colors.white.withOpacity(0.7)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'フィルター',
                                      style: AppTheme.getNotoSansJP(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.78),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 2. Progress Indicator Bar
                          _buildProgressBar(),
                          const SizedBox(height: 12),

                          // 3. Card Stack
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Permanently visible rotated guide stamps
                                Positioned(
                                  left: -6,
                                  top: 140,
                                  child: Transform.rotate(
                                    angle: -0.26, // -15 degrees
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE1556F), width: 3),
                                        borderRadius: BorderRadius.circular(9),
                                        color: const Color(0xFF06121B).withOpacity(0.35),
                                      ),
                                      child: const Text(
                                        'NOPE',
                                        style: TextStyle(
                                          color: Color(0xFFE1556F),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -6,
                                  top: 140,
                                  child: Transform.rotate(
                                    angle: 0.26, // 15 degrees
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.accent, width: 3),
                                        borderRadius: BorderRadius.circular(9),
                                        color: const Color(0xFF06121B).withOpacity(0.35),
                                      ),
                                      child: const Text(
                                        'LIKE',
                                        style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Stacked Back card 2
                                if (_unevaluatedPosts.length > 2)
                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    top: 10,
                                    bottom: -8,
                                    child: Transform.scale(
                                      scale: 0.92,
                                      child: Opacity(
                                        opacity: 0.5,
                                        child: _buildMockCard(),
                                      ),
                                    ),
                                  ),

                                // Stacked Back card 1
                                if (_unevaluatedPosts.length > 1)
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    top: 5,
                                    bottom: -4,
                                    child: Transform.scale(
                                      scale: 0.96,
                                      child: Opacity(
                                        opacity: 0.8,
                                        child: _buildMockCard(),
                                      ),
                                    ),
                                  ),

                                // Foreground card (Active)
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: _openDetailScreen,
                                    child: _buildSwipeCard(_unevaluatedPosts.first),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 4. Circular action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _handleSwipe('skip'),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBFBFA),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.close, color: Color(0xFF3A4248), size: 28),
                                    ),
                                    const SizedBox(width: 13),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '左にスワイプ',
                                          style: AppTheme.getNotoSansJP(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          '見送る',
                                          style: AppTheme.getNotoSansJP(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _handleSwipe('support'),
                                child: Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '右にスワイプ',
                                          style: AppTheme.getNotoSansJP(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          '応援する',
                                          style: AppTheme.getNotoSansJP(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 13),
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        gradient: const RadialGradient(
                                          center: Alignment(0, -0.24),
                                          radius: 0.5,
                                          colors: [
                                            Color(0xFF0E9A92),
                                            Color(0xFF06595E),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.accent.withOpacity(0.7), width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.accent.withOpacity(0.5),
                                            blurRadius: 26,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.45),
                                            blurRadius: 22,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.favorite_rounded, color: Color(0xFFBFF6F2), size: 25),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 5. Card support rate progress overlay
                          _buildSupportRateOverlay(_unevaluatedPosts.first),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final double pct = (_sessionEvalCount / 10.0).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_sessionEvalCount ',
              style: AppTheme.getNotoSansJP(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Text(
              '/ 10',
              style: AppTheme.getNotoSansJP(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 190,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMockCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D2230).withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
    );
  }

  Widget _buildSwipeCard(dynamic post) {
    final mediaList = post['post_media'] as List?;
    final primaryImg = mediaList != null && mediaList.isNotEmpty
        ? mediaList.firstWhere((m) => m['media_type'] == 'generated', orElse: () => mediaList.first)['url']
        : '';
    final author = post['profiles'];
    final metrics = post['post_metrics'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D2230).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppTheme.uiGrey,
                  backgroundImage: author?['avatar_url'] != null
                      ? NetworkImage(author['avatar_url'])
                      : null,
                  child: author?['avatar_url'] == null
                      ? const Icon(Icons.person, color: AppTheme.sub, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author?['display_name'] ?? '市民メンバー',
                        style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      Text(
                        author?['area_name'] ?? '未登録エリア',
                        style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Title & body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] ?? '無題のアイデア',
                  style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1.35),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  post['body'] ?? '',
                  style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Image visual
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: primaryImg.isNotEmpty
                          ? Image.network(
                              primaryImg,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(color: AppTheme.teal),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: AppTheme.sub, size: 30),
                              ),
                            )
                          : Container(color: AppTheme.border),
                    ),
                    // Fresh badge
                    if (metrics?['support_count'] != null && metrics?['support_count'] < 5)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xECcda86a),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '🌱 応援が少ない',
                            style: AppTheme.getNotoSansJP(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF3A2C0E)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Tags row
          () {
            final ptList = post['post_tags'] as List?;
            final tagsList = ptList?.map((pt) => pt['tags']?['title'] as String?).whereType<String>().toList() ?? [];
            if (tagsList.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 11),
              child: Wrap(
                spacing: 6,
                children: tagsList.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$tag',
                    style: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.sub),
                  ),
                )).toList(),
              ),
            );
          }(),

          // Bottom Stats
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 11, bottom: 14),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_border, size: 14, color: AppTheme.sub),
                    const SizedBox(width: 5),
                    Text('${metrics?['support_count'] ?? 0}', style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub)),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14, color: AppTheme.sub),
                    const SizedBox(width: 5),
                    Text('${metrics?['comment_count'] ?? 0}', style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub)),
                  ],
                ),
                const Spacer(),
                Text(_getAgoString(post['published_at'] ?? post['created_at']), style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSupportRateOverlay(dynamic post) {
    final metrics = post['post_metrics'];
    final double rate = metrics?['support_rate'] != null
        ? (double.tryParse(metrics['support_rate'].toString()) ?? 0.0)
        : 0.64;

    final ptList = post['post_tags'] as List?;
    final firstTag = ptList != null && ptList.isNotEmpty ? (ptList.first['tags']?['title'] ?? '提案') : '提案';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(color: AppTheme.accent.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${firstTag}案への支持 ',
                style: AppTheme.getNotoSansJP(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: AppTheme.getManrope(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 9,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: rate.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '現在の集計データに基づく',
            style: AppTheme.getNotoSansJP(fontSize: 11, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeedPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 38),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2230).withOpacity(0.12),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3EFED),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, size: 34, color: AppTheme.teal),
              ),
              const SizedBox(height: 18),
              Text(
                '今日の評価、完了！',
                style: AppTheme.getNotoSansJP(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.text),
              ),
              const SizedBox(height: 10),
              Text(
                '$_sessionEvalCount件の評価ありがとうございます。\nあなたの声がまちづくりに届きます。',
                style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.sub, height: 1.7),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _sessionEvalCount >= 10
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF0E2BF)),
                      ),
                      child: const Text(
                        '🎉 ＋30 まちポイント獲得！',
                        style: TextStyle(color: Color(0xFF9A7B2E), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                      ),
                      child: Text(
                        '目標クリアでポイント獲得！ ($_sessionEvalCount/10)',
                        style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ホームに戻る',
                    style: AppTheme.getNotoSansJP(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchSwipeFeed,
                child: Text(
                  'もう一度チェックする →',
                  style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.teal, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

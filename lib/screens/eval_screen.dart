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
    final currentSupportRate =
        double.tryParse(metrics?['support_rate']?.toString() ?? '0') ?? 0.0;

    try {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: _unevaluatedPosts.first),
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

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
        child: Column(
          children: [
            // ── メインコンテンツ ──────────────────────────────
            Expanded(
              child: SafeArea(
                bottom: false,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.teal))
                    : _unevaluatedPosts.isEmpty
                        ? _buildEmptyFeedPlaceholder()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                            child: Column(
                              children: [
                                // 1. ヘッダー
                                _buildHeader(),
                                const SizedBox(height: 12),
                                // 2. プログレスバー
                                _buildProgressBar(),
                                const SizedBox(height: 12),
                                // 3. カードスタック
                                Expanded(child: _buildCardStack()),
                                const SizedBox(height: 20),
                                // 4. アクションボタン
                                _buildActionButtons(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
              ),
            ),

            // ── 支持率パネル（ボトムナビ位置） ──────────────────
            if (!_isLoading && _unevaluatedPosts.isNotEmpty)
              _buildSupportRatePanel(_unevaluatedPosts.first, bottomPad),
          ],
        ),
      ),
    );
  }

  // ── ヘッダー ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => widget.onBack?.call(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.16), width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'みんなの評価',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list,
                  size: 12, color: AppTheme.text.withOpacity(0.7)),
              const SizedBox(width: 5),
              Text(
                'フィルター',
                style: AppTheme.getNotoSansJP(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── プログレスバー ────────────────────────────────────────────
  Widget _buildProgressBar() {
    final int total = _unevaluatedPosts.length + _sessionEvalCount;
    final double pct =
        total > 0 ? (_sessionEvalCount / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$_sessionEvalCount ',
                style: AppTheme.getNotoSansJP(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text('/ $total',
                style: AppTheme.getNotoSansJP(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 190,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── カードスタック ────────────────────────────────────────────
  Widget _buildCardStack() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // NOPE スタンプ
        Positioned(
          left: -6,
          top: 140,
          child: Transform.rotate(
            angle: -0.26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1556F), width: 3),
                borderRadius: BorderRadius.circular(9),
                color: const Color(0xFF06121B).withOpacity(0.35),
              ),
              child: const Text('NOPE',
                  style: TextStyle(
                      color: Color(0xFFE1556F),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ),
          ),
        ),
        // LIKE スタンプ
        Positioned(
          right: -6,
          top: 140,
          child: Transform.rotate(
            angle: 0.26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 3),
                borderRadius: BorderRadius.circular(9),
                color: const Color(0xFF06121B).withOpacity(0.35),
              ),
              child: const Text('LIKE',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ),
          ),
        ),
        // 背景カード2
        if (_unevaluatedPosts.length > 2)
          Positioned(
            left: 14, right: 14, top: 10, bottom: -8,
            child: Transform.scale(
              scale: 0.92,
              child: Opacity(opacity: 0.5, child: _buildMockCard()),
            ),
          ),
        // 背景カード1
        if (_unevaluatedPosts.length > 1)
          Positioned(
            left: 8, right: 8, top: 5, bottom: -4,
            child: Transform.scale(
              scale: 0.96,
              child: Opacity(opacity: 0.8, child: _buildMockCard()),
            ),
          ),
        // フロントカード
        Positioned.fill(
          child: GestureDetector(
            onTap: _openDetailScreen,
            child: _buildSwipeCard(_unevaluatedPosts.first),
          ),
        ),
      ],
    );
  }

  // ── アクションボタン ──────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 見送る
        GestureDetector(
          onTap: () => _handleSwipe('skip'),
          child: Row(
            children: [
              Container(
                width: 58, height: 58,
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
                child: const Icon(Icons.close,
                    color: Color(0xFF3A4248), size: 28),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('左にスワイプ',
                      style: AppTheme.getNotoSansJP(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  Text('見送る',
                      style: AppTheme.getNotoSansJP(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        // 応援する
        GestureDetector(
          onTap: () => _handleSwipe('support'),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('右にスワイプ',
                      style: AppTheme.getNotoSansJP(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  Text('応援する',
                      style: AppTheme.getNotoSansJP(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 13),
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3DDDD6),
                      Color(0xFF0FA89F),
                      Color(0xFF03585C),
                      Color(0xFF022E32),
                    ],
                    stops: [0.0, 0.35, 0.72, 1.0],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF1ECECA).withOpacity(0.5),
                        blurRadius: 22,
                        spreadRadius: 1),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 7)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite_border,
                    color: Colors.white, size: 25),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 支持率パネル ──────────────────────────────────────────────
  Widget _buildSupportRatePanel(dynamic post, [double bottomPad = 0]) {
    final metrics = post['post_metrics'];
    final double rate = metrics?['support_rate'] != null
        ? (double.tryParse(metrics['support_rate'].toString()) ?? 0.0)
        : 0.0;

    final ptList = post['post_tags'] as List?;
    final firstTag = ptList != null && ptList.isNotEmpty
        ? (ptList.first['tags']?['title'] ?? '提案')
        : '提案';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: const Color(0xFF02141C),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
          left: BorderSide(color: Colors.white.withOpacity(0.08)),
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 艶ライン（上部ハイライト）
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.30),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // タイトル＋% 1行・中央
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${firstTag}案への支持  ',
                    style: AppTheme.getNotoSansJP(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  TextSpan(
                    text: '${(rate * 100).round()}%',
                    style: AppTheme.getManrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 進捗バー（teal グロー）
          LayoutBuilder(
            builder: (context, constraints) {
              final double fillW =
                  (constraints.maxWidth * rate.clamp(0.0, 1.0))
                      .clamp(3.0, constraints.maxWidth);
              return Stack(
                children: [
                  Container(
                    height: 5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    height: 5,
                    width: fillW,
                    decoration: BoxDecoration(
                      color: const Color(0xFF29D8D3),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF29D8D3).withOpacity(0.7),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 7),
          // キャプション（中央）
          Center(
            child: Text(
              '現在の集計データに基づく',
              style: AppTheme.getNotoSansJP(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.45)),
            ),
          ),
        ],
      ),
    );
  }

  // ── モックカード（背景用） ─────────────────────────────────────
  Widget _buildMockCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0D2230).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
    );
  }

  // ── スワイプカード ────────────────────────────────────────────
  Widget _buildSwipeCard(dynamic post) {
    final mediaList = post['post_media'] as List?;
    final primaryImg = mediaList != null && mediaList.isNotEmpty
        ? mediaList.firstWhere((m) => m['media_type'] == 'generated',
            orElse: () => mediaList.first)['url']
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
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 著者
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14, top: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8E8E8),
                  backgroundImage: author?['avatar_url'] != null
                      ? NetworkImage(author['avatar_url'])
                      : null,
                  child: author?['avatar_url'] == null
                      ? const Icon(Icons.person,
                          color: AppTheme.sub, size: 16)
                      : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author?['display_name'] ?? '市民メンバー',
                          style: AppTheme.getNotoSansJP(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text)),
                      Text(author?['area_name'] ?? '未登録エリア',
                          style: AppTheme.getNotoSansJP(
                              fontSize: 11, color: AppTheme.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // タイトル・本文
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] ?? '無題のアイデア',
                  style: AppTheme.getNotoSansJP(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.text,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  post['body'] ?? '',
                  style: AppTheme.getNotoSansJP(
                      fontSize: 12, color: AppTheme.sub, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 画像
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: SizedBox(
                height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: primaryImg.isNotEmpty
                          ? Image.network(primaryImg,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.teal));
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image,
                                        color: AppTheme.sub, size: 30),
                                  ))
                          : Container(color: AppTheme.border),
                    ),
                    if (metrics?['support_count'] != null &&
                        metrics?['support_count'] < 5)
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xECcda86a),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('🌱 応援が少ない',
                              style: AppTheme.getNotoSansJP(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF3A2C0E))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // タグ（ない場合も固定スペース確保）
          () {
            final ptList = post['post_tags'] as List?;
            final tagsList = ptList
                    ?.map((pt) => pt['tags']?['title'] as String?)
                    .whereType<String>()
                    .toList() ??
                [];
            if (tagsList.isEmpty) return const SizedBox(height: 48);
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tagsList
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(tag,
                              style: AppTheme.getNotoSansJP(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF555555))),
                        ))
                    .toList(),
              ),
            );
          }(),
          const Spacer(),
          // 統計（常にカード最下部）
          Padding(
            padding: const EdgeInsets.only(
                left: 14, right: 14, top: 8, bottom: 14),
            child: Row(
              children: [
                const Icon(Icons.favorite_border,
                    size: 16, color: AppTheme.sub),
                const SizedBox(width: 5),
                Text('${metrics?['support_count'] ?? 0}',
                    style: AppTheme.getNotoSansJP(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.sub)),
                const SizedBox(width: 18),
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: AppTheme.sub),
                const SizedBox(width: 5),
                Text('${metrics?['comment_count'] ?? 0}',
                    style: AppTheme.getNotoSansJP(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.sub)),
                const Spacer(),
                Text(
                    _getAgoString(
                        post['published_at'] ?? post['created_at']),
                    style: AppTheme.getNotoSansJP(
                        fontSize: 13, color: AppTheme.sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 空状態 ────────────────────────────────────────────────────
  Widget _buildEmptyFeedPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26.0),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 38),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF0D2230).withOpacity(0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 14)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                    color: Color(0xFFE3EFED), shape: BoxShape.circle),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.check, size: 34, color: AppTheme.teal),
              ),
              const SizedBox(height: 18),
              Text('今日の評価、完了！',
                  style: AppTheme.getNotoSansJP(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.text)),
              const SizedBox(height: 10),
              Text(
                '$_sessionEvalCount件の評価ありがとうございます。\nあなたの声がまちづくりに届きます。',
                style: AppTheme.getNotoSansJP(
                    fontSize: 13, color: AppTheme.sub, height: 1.7),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _sessionEvalCount >= 10
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: const Color(0xFFF0E2BF)),
                      ),
                      child: const Text('🎉 ＋30 まちポイント獲得！',
                          style: TextStyle(
                              color: Color(0xFF9A7B2E),
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.1)),
                      ),
                      child: Text(
                        '目標クリアでポイント獲得！ ($_sessionEvalCount/10)',
                        style: AppTheme.getNotoSansJP(
                            color: AppTheme.sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text('ホームに戻る',
                      style: AppTheme.getNotoSansJP(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchSwipeFeed,
                child: Text('もう一度チェックする →',
                    style: AppTheme.getNotoSansJP(
                        fontSize: 13,
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

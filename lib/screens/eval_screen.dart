// lib/screens/eval_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class EvalScreen extends StatefulWidget {
  const EvalScreen({super.key});

  @override
  State<EvalScreen> createState() => _EvalScreenState();
}

class _EvalScreenState extends State<EvalScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _unevaluatedPosts = [];
  bool _isLoading = true;
  final Stopwatch _dwellStopwatch = Stopwatch();
  bool _openedDetail = false;

  @override
  void initState() {
    super.initState();
    _fetchSwipeFeed();
  }

  Future<void> _fetchSwipeFeed() async {
    setState(() => _isLoading = true);
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Fetch posts and join evaluations to filter out already evaluated ones in Dart
      final response = await supabase
          .from('posts')
          .select('*, post_media(*), post_metrics(*), profiles(display_name, area_name), evaluations(user_id)')
          .eq('status', 'published');

      final list = response as List;
      final filtered = list.where((post) {
        final evals = post['evaluations'] as List?;
        if (evals == null || evals.isEmpty) return true;
        return !evals.any((e) => e['user_id'] == uid);
      }).toList();

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
    final uid = supabase.auth.currentUser?.id;

    if (uid == null) return;

    final metrics = activePost['post_metrics'];
    final currentSupportCount = metrics?['support_count'] ?? 0;
    final currentSupportRate = double.tryParse(metrics?['support_rate']?.toString() ?? '0') ?? 0.0;

    try {
      // Write evaluation
      await supabase.from('evaluations').insert({
        'user_id': uid,
        'post_id': activePost['id'],
        'project_id': activePost['project_id'],
        'action': action,
        'dwell_ms': dwellMs,
        'opened_detail': _openedDetail,
        'source': 'swipe',
        'support_count_at_evaluation': currentSupportCount,
        'support_rate_at_evaluation': currentSupportRate,
      });

      // Slide locally to next item
      if (mounted) {
        setState(() {
          _unevaluatedPosts.removeAt(0);
        });
        _resetTimer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('評価の保存に失敗しました: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openDetailSheet() {
    if (_unevaluatedPosts.isEmpty) return;
    _openedDetail = true;
    final post = _unevaluatedPosts.first;
    
    // Open modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PostSwipeDetailSheet(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          'フリック評価',
          style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.sub),
            onPressed: () {},
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
          : _unevaluatedPosts.isEmpty
              ? _buildEmptyFeedPlaceholder()
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        // Stack Card Representation
                        Expanded(
                          child: GestureDetector(
                            onTap: _openDetailSheet,
                            child: _buildSwipeCard(_unevaluatedPosts.first),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Actions row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Skip button
                            _buildActionButton(
                              icon: Icons.close,
                              color: AppTheme.sub,
                              bgColor: Colors.white,
                              label: 'スキップ (左)',
                              onTap: () => _handleSwipe('skip'),
                            ),
                            // Support button
                            _buildActionButton(
                              icon: Icons.favorite,
                              color: Colors.white,
                              bgColor: AppTheme.teal,
                              label: '応援する (右)',
                              onTap: () => _handleSwipe('support'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSwipeCard(dynamic post) {
    final mediaList = post['post_media'] as List?;
    final primaryImg = mediaList != null && mediaList.isNotEmpty
        ? mediaList.firstWhere((m) => m['media_type'] == 'generated', orElse: () => mediaList.first)['url']
        : '';
    final author = post['profiles'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    primaryImg,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppTheme.uiGrey,
                      child: const Icon(Icons.image, size: 50, color: AppTheme.sub),
                    ),
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                      ),
                    ),
                  ),
                ),
                // Author tag overlay
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 12, color: AppTheme.text),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${author?['display_name'] ?? "市民メンバー"} @ ${author?['area_name'] ?? "未設定"}',
                        style: AppTheme.getNotoSansJP(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'] ?? '無題のアイデア',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      post['body'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.sub, height: 1.5),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '詳細を表示するにはカードをタップ',
                        style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w500),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.muted),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyFeedPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.teal.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded, size: 60, color: AppTheme.teal),
            ),
            const SizedBox(height: 24),
            Text(
              '今日の評価は完了しました！',
              style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '新しいアイデアが投稿されるのをお待ちください。明後日、再びフリック評価で市民サポートを行いましょう！',
              style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.sub, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchSwipeFeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('もう一度チェックする', style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: bgColor == Colors.white ? 1.5 : 0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.sub),
        ),
      ],
    );
  }
}

// Minimal Detail viewer for evaluated swipe detail sheet
class PostSwipeDetailSheet extends StatelessWidget {
  final dynamic post;
  const PostSwipeDetailSheet({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final media = post['post_media'] as List?;
    final beforeImg = media?.firstWhere((m) => m['media_type'] == 'before', orElse: () => {'url': ''})['url'] ?? '';
    final afterImg = media?.firstWhere((m) => m['media_type'] == 'generated', orElse: () => {'url': ''})['url'] ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (beforeImg.isNotEmpty) ...[
                  Text('元の風景 (BEFORE)', style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.sub)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(beforeImg, fit: BoxFit.cover, height: 160),
                  ),
                  const SizedBox(height: 16),
                ],
                if (afterImg.isNotEmpty) ...[
                  Text('生成後の未来予想図 (AFTER)', style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.teal)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(afterImg, fit: BoxFit.cover, height: 160),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  post['title'] ?? '',
                  style: AppTheme.getNotoSansJP(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  post['body'] ?? '',
                  style: AppTheme.getNotoSansJP(fontSize: 14, color: AppTheme.text, height: 1.6),
                ),
                const SizedBox(height: 40),
              ],
            ),
          )
        ],
      ),
    );
  }
}

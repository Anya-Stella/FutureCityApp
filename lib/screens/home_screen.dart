// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/challenge_card.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _projects = [];
  List<dynamic> _popularPosts = [];
  List<dynamic> _newPosts = [];
  bool _isLoadingProjects = true;
  bool _isLoadingPosts = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchProjects(),
      _fetchPosts(),
    ]);
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await SupabaseService.getActiveProjects();
      if (mounted) {
        setState(() {
          _projects = data;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _fetchPosts() async {
    if (!mounted) return;
    setState(() => _isLoadingPosts = true);
    try {
      final data = await SupabaseService.getPublishedPosts();

      // Sort popular: Sort by support_count/score descending
      final popularData = List<dynamic>.from(data);
      popularData.sort((a, b) {
        final scoreA = (a['post_metrics']?['support_count'] ?? 0) as num;
        final scoreB = (b['post_metrics']?['support_count'] ?? 0) as num;
        return scoreB.compareTo(scoreA);
      });

      // Sort new: Sort by published_at or created_at descending
      final newData = List<dynamic>.from(data);
      newData.sort((a, b) {
        final timeA = DateTime.parse(a['published_at'] ?? a['created_at']);
        final timeB = DateTime.parse(b['published_at'] ?? b['created_at']);
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _popularPosts = popularData.take(2).toList();
          _newPosts = newData.take(4).toList();
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  String _getAgoString(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) {
        return '${date.month}/${date.day}';
      } else if (diff.inDays >= 1) {
        return '${diff.inDays}日前';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours}時間前';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes}分前';
      } else {
        return 'たった今';
      }
    } catch (_) {
      return '';
    }
  }

  void _openPostDetail(dynamic post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: null, // Custom header inside body instead of AppBar
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.teal,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 112),
            children: [
              // 1. Custom Header
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 22, top: 12, bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ホーム',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: AppTheme.text,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D2230).withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_outlined, size: 19, color: AppTheme.text),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Active Challenges (Single Large Card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '注目のチャレンジ',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.01,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      'すべて見る',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.teal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingProjects
                  ? const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.teal)),
                    )
                  : _projects.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.bgSoft),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D2230).withOpacity(0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_flags_outlined, size: 36, color: AppTheme.sub),
                                const SizedBox(height: 12),
                                Text(
                                  '現在、開催中のチャレンジはありません。',
                                  style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: ChallengeCard(
                            title: _projects.first['title'] ?? '無題',
                            description: _projects.first['description'] ?? 'みんなで、緑のある\n歩きたくなる駅前へ。',
                            imageUrl: _projects.first['cover_image_url'] ?? '',
                            deadline: _projects.first['ends_at'] != null
                                ? '${DateTime.parse(_projects.first['ends_at']).toLocal().month}/${DateTime.parse(_projects.first['ends_at']).toLocal().day}'
                                : '7/31',
                            onTap: () {},
                          ),
                        ),

              // 3. Popular Posts (Grid Layout)
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 22, top: 34, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '人気の投稿',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.01,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      'すべて見る',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.teal,
                      ),
                    ),
                  ],
                ),
              ),
              _isLoadingPosts
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                  : _popularPosts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.bgSoft),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '投稿されたアイデアはまだありません。',
                              style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.74,
                          ),
                          itemCount: _popularPosts.length,
                          itemBuilder: (context, idx) {
                            final post = _popularPosts[idx];
                        final media = post['post_media'] as List?;
                        final primaryImg = media != null && media.isNotEmpty
                            ? media.firstWhere((m) => m['media_type'] == 'generated', orElse: () => media.first)['url']
                            : '';
                        final metrics = post['post_metrics'];
                        final authorProfile = post['profiles'];

                        return PostCard(
                          title: post['title'] ?? '無題のアイデア',
                          imageUrl: primaryImg,
                          likes: metrics?['support_count'] ?? 0,
                          comments: metrics?['comment_count'] ?? 0,
                          author: authorProfile?['display_name'] ?? 'ゲスト市民',
                          area: authorProfile?['area_name'] ?? '未設定',
                          onTap: () => _openPostDetail(post),
                        );
                      },
                    ),

              // 4. New Posts (Vertical List Layout)
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 22, top: 34, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '新着の投稿',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.01,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      'すべて見る',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.teal,
                      ),
                    ),
                  ],
                ),
              ),
              _isLoadingPosts
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                  : _newPosts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.bgSoft),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '最新の投稿はまだありません。',
                              style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          itemCount: _newPosts.length,
                          itemBuilder: (context, idx) {
                            final post = _newPosts[idx];
                        final media = post['post_media'] as List?;
                        final primaryImg = media != null && media.isNotEmpty
                            ? media.firstWhere((m) => m['media_type'] == 'generated', orElse: () => media.first)['url']
                            : '';
                        final metrics = post['post_metrics'];
                        final authorProfile = post['profiles'];

                        return GestureDetector(
                          onTap: () => _openPostDetail(post),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0C1920).withOpacity(0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 74,
                                    height: 74,
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
                                              child: Icon(Icons.broken_image, color: Colors.white24, size: 24),
                                            ),
                                          )
                                        : Container(color: AppTheme.uiGrey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['title'] ?? '無題のアイデア',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.getNotoSansJP(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.text,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${authorProfile?['display_name'] ?? 'ゲスト'}・${authorProfile?['area_name'] ?? '未設定'}・${_getAgoString(post['published_at'] ?? post['created_at'])}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.getNotoSansJP(
                                          fontSize: 11,
                                          color: AppTheme.sub,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.favorite_border, size: 12, color: AppTheme.sub),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${metrics?['support_count'] ?? 0}',
                                                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 13),
                                          Row(
                                            children: [
                                              const Icon(Icons.chat_bubble_outline, size: 12, color: AppTheme.sub),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${metrics?['comment_count'] ?? 0}',
                                                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}


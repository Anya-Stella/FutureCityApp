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
          _popularPosts = popularData.take(6).toList();
          _newPosts = newData.take(6).toList();
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
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
              // 1. Custom Header matching mockup (plain 'Future City' + bell icon)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Future City',
                      style: AppTheme.getManrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none_outlined, size: 24, color: Colors.black),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 2. Active Challenges (Single Large Card, padded with 16)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        color: const Color(0xFF333333),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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

              // 3. Popular Ideas (Horizontally scrollable list of PostCards)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 34, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '人気のアイデア',
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
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              _isLoadingPosts
                  ? const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.teal)),
                    )
                  : _popularPosts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      : SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _popularPosts.length,
                            itemBuilder: (context, idx) {
                              final post = _popularPosts[idx];
                              final media = post['post_media'] as List?;
                              final primaryImg = media != null && media.isNotEmpty
                                  ? media.firstWhere((m) => m['media_type'] == 'generated', orElse: () => media.first)['url']
                                  : '';
                              final metrics = post['post_metrics'];
                              final authorProfile = post['profiles'];

                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                child: PostCard(
                                  title: post['title'] ?? '無題のアイデア',
                                  imageUrl: primaryImg,
                                  likes: metrics?['support_count'] ?? 0,
                                  comments: metrics?['comment_count'] ?? 0,
                                  author: authorProfile?['display_name'] ?? 'ゲスト市民',
                                  onTap: () => _openPostDetail(post),
                                ),
                              );
                            },
                          ),
                        ),

              // 4. New Ideas (Horizontally scrollable list of PostCards matching mockup)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 34, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '新着のアイデア',
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
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              _isLoadingPosts
                  ? const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.teal)),
                    )
                  : _newPosts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      : SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _newPosts.length,
                            itemBuilder: (context, idx) {
                              final post = _newPosts[idx];
                              final media = post['post_media'] as List?;
                              final primaryImg = media != null && media.isNotEmpty
                                  ? media.firstWhere((m) => m['media_type'] == 'generated', orElse: () => media.first)['url']
                                  : '';
                              final metrics = post['post_metrics'];
                              final authorProfile = post['profiles'];

                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                child: PostCard(
                                  title: post['title'] ?? '無題のアイデア',
                                  imageUrl: primaryImg,
                                  likes: metrics?['support_count'] ?? 0,
                                  comments: metrics?['comment_count'] ?? 0,
                                  author: authorProfile?['display_name'] ?? 'ゲスト市民',
                                  onTap: () => _openPostDetail(post),
                                ),
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}

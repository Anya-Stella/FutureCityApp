// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/challenge_card.dart';
import '../widgets/post_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
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
      final data = await supabase
          .from('projects')
          .select('*')
          .eq('status', 'active')
          .order('ends_at', ascending: true);
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
      final query = supabase
          .from('posts')
          .select('*, profiles(*), post_media(*), post_metrics(*)')
          .eq('status', 'published');

      final data = await query;

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PostDetailSheet(post: post),
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
                          child: ChallengeCard(
                            title: '大宮駅東口歩行者空間化',
                            description: 'みんなで、緑のある\n歩きたくなる駅前へ。',
                            imageUrl: 'assets/challenge-cover.png',
                            deadline: '7/31',
                            onTap: () {},
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
                                        ? (primaryImg.startsWith('assets/') || primaryImg.startsWith('src/assets/')
                                            ? Image.asset(primaryImg.startsWith('src/') ? primaryImg.replaceFirst('src/', '') : primaryImg, fit: BoxFit.cover)
                                            : Image.network(primaryImg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/street-before.png', fit: BoxFit.cover)))
                                        : Image.asset('assets/street-before.png', fit: BoxFit.cover),
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

// -----------------------------------------------------------------------------
// POST DETAIL SHEET WITH TOGGLE IMAGE COMPARISON AND CUSTOM HEADERS
// -----------------------------------------------------------------------------
class PostDetailSheet extends StatefulWidget {
  final dynamic post;
  const PostDetailSheet({super.key, required this.post});

  @override
  State<PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<PostDetailSheet> {
  final supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  bool _isSaved = false;
  bool _showAfter = true; // Toggle state for before/after comparison

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _checkSavedState();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles(display_name, avatar_url)')
          .eq('post_id', widget.post['id'])
          .eq('status', 'published')
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _comments = data;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting comments: $e');
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _checkSavedState() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await supabase
          .from('saved_posts')
          .select('*')
          .eq('user_id', uid)
          .eq('post_id', widget.post['id'])
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isSaved = res != null;
        });
      }
    } catch (e) {
      debugPrint('Error checking saved state: $e');
    }
  }

  Future<void> _toggleSave() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      if (_isSaved) {
        await supabase
            .from('saved_posts')
            .delete()
            .eq('user_id', uid)
            .eq('post_id', widget.post['id']);
      } else {
        await supabase.from('saved_posts').insert({
          'user_id': uid,
          'post_id': widget.post['id'],
        });
      }
      setState(() => _isSaved = !_isSaved);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await supabase.from('comments').insert({
        'user_id': uid,
        'post_id': widget.post['id'],
        'body': text,
        'status': 'published',
      });
      _commentController.clear();
      _fetchComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コメント送信に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['profiles'];
    final metrics = post['post_metrics'];
    final mediaList = post['post_media'] as List?;

    // Identify Before / After media images
    String beforeImg = '';
    String afterImg = '';
    if (mediaList != null) {
      for (var media in mediaList) {
        if (media['media_type'] == 'before') {
          beforeImg = media['url'];
        } else if (media['media_type'] == 'generated') {
          afterImg = media['url'];
        }
      }
      if (beforeImg.isEmpty && mediaList.isNotEmpty) beforeImg = mediaList[0]['url'];
      if (afterImg.isEmpty && mediaList.isNotEmpty) afterImg = mediaList[0]['url'];
    }

    final double supportRate = metrics?['support_rate'] != null
        ? (double.tryParse(metrics['support_rate'].toString()) ?? 0.0)
        : 0.0;

    // Get time elapsed
    String timeAgo = '';
    final rawTime = post['published_at'] ?? post['created_at'];
    if (rawTime != null) {
      try {
        final date = DateTime.parse(rawTime).toLocal();
        final diff = DateTime.now().difference(date);
        if (diff.inDays > 7) {
          timeAgo = '${date.month}/${date.day}';
        } else if (diff.inDays >= 1) {
          timeAgo = '${diff.inDays}日前';
        } else if (diff.inHours >= 1) {
          timeAgo = '${diff.inHours}時間前';
        } else {
          timeAgo = '今日';
        }
      } catch (_) {}
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Custom Header
          Container(
            padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppTheme.text),
                  ),
                ),
                Text(
                  '投稿の詳細',
                  style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                ),
                GestureDetector(
                  onTap: _toggleSave,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 15,
                      color: _isSaved ? AppTheme.teal : AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // 1. Toggle Image Comparison
                if (beforeImg.isNotEmpty && afterImg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: AspectRatio(
                      aspectRatio: 16 / 11,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _showAfter
                                  ? (afterImg.startsWith('assets/') || afterImg.startsWith('src/assets/')
                                      ? Image.asset(afterImg.startsWith('src/') ? afterImg.replaceFirst('src/', '') : afterImg, fit: BoxFit.cover)
                                      : Image.network(afterImg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/street-before.png', fit: BoxFit.cover)))
                                  : (beforeImg.startsWith('assets/') || beforeImg.startsWith('src/assets/')
                                      ? Image.asset(beforeImg.startsWith('src/') ? beforeImg.replaceFirst('src/', '') : beforeImg, fit: BoxFit.cover)
                                      : Image.network(beforeImg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/street-before.png', fit: BoxFit.cover))),
                            ),
                            // Badge label
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _showAfter ? const Color(0xEC006C74) : const Color(0xB507141C),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _showAfter ? 'AFTER (AI生成)' : 'BEFORE',
                                  style: AppTheme.getNotoSansJP(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            // Toggle button overlay
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showAfter = !_showAfter;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_horiz, size: 14, color: AppTheme.teal),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Before / After',
                                        style: AppTheme.getManrope(
                                          color: AppTheme.teal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 2. Info details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] ?? '',
                        style: AppTheme.getNotoSansJP(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: AppTheme.uiGrey,
                            backgroundImage: author?['avatar_url'] != null
                                ? NetworkImage(author['avatar_url'])
                                : null,
                            child: author?['avatar_url'] == null
                                ? const Icon(Icons.person, color: AppTheme.sub, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author?['display_name'] ?? '市民メンバー',
                                style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${author?['area_name'] ?? '未登録エリア'}・$timeAgo',
                                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post['body'] ?? '',
                        style: AppTheme.getNotoSansJP(fontSize: 14, color: AppTheme.sub, height: 1.9),
                      ),
                      const SizedBox(height: 16),

                      // Tags Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3EFED),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#歩道拡幅',
                              style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.teal),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3EFED),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#景観向上',
                              style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.teal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Metrics summary row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.border, width: 1),
                            bottom: BorderSide(color: AppTheme.border, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.favorite, color: AppTheme.heart, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${metrics?['support_count'] ?? 0}',
                                  style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.sub),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, color: AppTheme.sub, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  '${metrics?['comment_count'] ?? 0}',
                                  style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.sub),
                                ),
                              ],
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleSave,
                              child: Row(
                                children: [
                                  Icon(
                                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    color: AppTheme.teal,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '保存',
                                    style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.teal),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Support Rate Progress Bar
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'この提案への支持',
                                  style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
                                ),
                                Text(
                                  '${(supportRate * 100).toStringAsFixed(0)}%',
                                  style: AppTheme.getManrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.teal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 9,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: supportRate.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.teal,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '現在の集計データに基づく',
                              style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                            ),
                          ],
                        ),
                      ),

                      // Comments
                      Text(
                        'コメント',
                        style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingComments
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                          : ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _comments.length,
                              itemBuilder: (context, idx) {
                                final comm = _comments[idx];
                                final commAuthor = comm['profiles'];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: AppTheme.uiGrey,
                                        backgroundImage: commAuthor?['avatar_url'] != null
                                            ? NetworkImage(commAuthor['avatar_url'])
                                            : null,
                                        child: commAuthor?['avatar_url'] == null
                                            ? const Icon(Icons.person, color: AppTheme.sub, size: 14)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0D2230).withOpacity(0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                commAuthor?['display_name'] ?? '市民サポーター',
                                                style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                comm['body'] ?? '',
                                                style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.sub, height: 1.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 10),

                      // Add comment input box
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: AppTheme.getNotoSansJP(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'あなたの建設的な意見を追加...',
                                hintStyle: AppTheme.getNotoSansJP(color: AppTheme.muted),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.teal),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppTheme.teal),
                            onPressed: _postComment,
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Map Container with Center Pin
                      Text(
                        '投稿場所',
                        style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                'https://tile.openstreetmap.org/15/29094/12711.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: AppTheme.border),
                              ),
                            ),
                            Center(
                              child: Container(
                                transform: Matrix4.translationValues(0, -14, 0),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: AppTheme.teal,
                                      size: 28,
                                    ),
                                    Positioned(
                                      top: 6,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8),
                                  ],
                                ),
                                child: Text(
                                  '周辺の投稿を見る',
                                  style: AppTheme.getNotoSansJP(
                                    color: AppTheme.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

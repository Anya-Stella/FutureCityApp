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
  List<dynamic> _posts = [];
  bool _isLoadingProjects = true;
  bool _isLoadingPosts = true;
  bool _isPopularSelected = true;

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
      
      // Sort in Dart to ensure maximum compatibility and stability
      if (_isPopularSelected) {
        data.sort((a, b) {
          final scoreA = (a['post_metrics']?['score'] ?? 0) as num;
          final scoreB = (b['post_metrics']?['score'] ?? 0) as num;
          return scoreB.compareTo(scoreA);
        });
      } else {
        data.sort((a, b) {
          final timeA = DateTime.parse(a['published_at'] ?? a['created_at']);
          final timeB = DateTime.parse(b['published_at'] ?? b['created_at']);
          return timeB.compareTo(timeA);
        });
      }

      if (mounted) {
        setState(() {
          _posts = data;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  void _openPostDetail(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: PostDetailSheet(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.tealDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'FUTURE CITY',
              style: AppTheme.getManrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppTheme.text),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.teal,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Active challenges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '注目のチャレンジ',
                style: AppTheme.getNotoSansJP(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingProjects
                ? const SizedBox(
                    height: 190,
                    child: Center(child: CircularProgressIndicator(color: AppTheme.teal)),
                  )
                : _projects.isEmpty
                    ? Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.uiGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '現在実施中のチャレンジはありません',
                            style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 195,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _projects.length,
                          itemBuilder: (context, idx) {
                            final proj = _projects[idx];
                            final ends = proj['ends_at'] != null 
                                ? DateTime.parse(proj['ends_at']).toLocal() 
                                : DateTime.now();
                            final deadlineStr = '${ends.month}/${ends.day}';

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: SizedBox(
                                width: 300,
                                child: ChallengeCard(
                                  title: proj['title'] ?? '無題',
                                  description: proj['description'] ?? '',
                                  imageUrl: proj['cover_image_url'] ?? '',
                                  deadline: deadlineStr,
                                  buttonText: '${proj['reward_points'] ?? 0} pts 獲得',
                                  onTap: () {
                                    // Handle clicking challenge card -> goes to details/create with proj_id
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 30),
            // Ideas section header + tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'まちのアイデア',
                    style: AppTheme.getNotoSansJP(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                  Row(
                    children: [
                      _buildTabButton('人気', _isPopularSelected, () {
                        setState(() {
                          _isPopularSelected = true;
                          _fetchPosts();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTabButton('新着', !_isPopularSelected, () {
                        setState(() {
                          _isPopularSelected = false;
                          _fetchPosts();
                        });
                      }),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingPosts
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(color: AppTheme.teal),
                  ))
                : _posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60.0),
                          child: Text(
                            '表示可能なアイデアはありません',
                            style: AppTheme.getNotoSansJP(color: AppTheme.sub),
                          ),
                        ),
                      )
                    : GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, idx) {
                          final post = _posts[idx];
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
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.teal : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.getNotoSansJP(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.sub,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// POST DETAIL SHEET WITH DRAG-TO-SLIDE BEFORE/AFTER COMPARISON
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
  double _sliderPos = 0.5; // Drag position (0.0 to 1.0)
  bool _isSaved = false;

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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // 1. Before/After Split Slider
                if (beforeImg.isNotEmpty && afterImg.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        return GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _sliderPos = (_sliderPos + details.primaryDelta! / w).clamp(0.0, 1.0);
                            });
                          },
                          child: Stack(
                            children: [
                              // Generated (After) image fills the background
                              Positioned.fill(
                                child: Image.network(afterImg, fit: BoxFit.cover),
                              ),
                              // ClipRect for original (Before) image
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: w * _sliderPos,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _sliderPos,
                                    child: SizedBox(
                                      width: w,
                                      height: h,
                                      child: Image.network(beforeImg, fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                              ),
                              // Vertical slider divider line
                              Positioned(
                                left: w * _sliderPos - 1,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: Colors.white,
                                ),
                              ),
                              // Centered Slider handle thumb
                              Positioned(
                                left: w * _sliderPos - 18,
                                top: h / 2 - 18,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Icon(Icons.swap_horiz, color: AppTheme.text, size: 20),
                                ),
                              ),
                              // Labels
                              Positioned(
                                left: 12,
                                top: 12,
                                child: _buildLabel('BEFORE', Colors.black45),
                              ),
                              Positioned(
                                right: 12,
                                top: 12,
                                child: _buildLabel('AFTER (AI)', AppTheme.tealDark),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // 2. Info details
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 18,
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
                                style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                author?['area_name'] ?? '未登録エリア',
                                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Save Action Button
                          IconButton(
                            icon: Icon(
                              _isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: _isSaved ? AppTheme.teal : AppTheme.sub,
                            ),
                            onPressed: _toggleSave,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        post['title'] ?? '',
                        style: AppTheme.getNotoSansJP(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        post['body'] ?? '',
                        style: AppTheme.getNotoSansJP(fontSize: 14, color: AppTheme.text, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      // Stats metrics row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('支持数', '${metrics?['support_count'] ?? 0} 人'),
                            _buildStatItem('支持率', '${((double.tryParse(metrics?['support_rate']?.toString() ?? '0') ?? 0.0) * 100).toStringAsFixed(0)}%'),
                            _buildStatItem('コメント', '${metrics?['comment_count'] ?? 0} 件'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Comments Section
                      Text(
                        '意見交換 (${_comments.length}件)',
                        style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingComments
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                          : ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => const Divider(height: 20),
                              itemBuilder: (context, idx) {
                                final comm = _comments[idx];
                                final commAuthor = comm['profiles'];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.uiGrey,
                                      backgroundImage: commAuthor?['avatar_url'] != null
                                          ? NetworkImage(commAuthor['avatar_url'])
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                commAuthor?['display_name'] ?? '市民サポーター',
                                                style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${DateTime.parse(comm['created_at']).toLocal().month}/${DateTime.parse(comm['created_at']).toLocal().day}',
                                                style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.muted),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comm['body'] ?? '',
                                            style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.text),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                );
                              },
                            ),
                      const SizedBox(height: 20),
                      // Add Comment Input Box
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
                      )
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

  Widget _buildLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.getManrope(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.getManrope(fontSize: 15, color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../widgets/desktop_device_wrapper.dart';

class PostDetailScreen extends StatefulWidget {
  final dynamic post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  bool _isSaved = false;
  bool _isSupported = false;
  int _supportCount = 0;

  @override
  void initState() {
    super.initState();
    _supportCount = widget.post['post_metrics']?['support_count'] ?? 0;
    _fetchComments();
    _checkSavedState();
    _checkSupportedState();

    // Set status bar text to dark for the white background screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopDeviceWrapper.useLightStatusBar.value = false;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await SupabaseService.getCommentsForPost(widget.post['id']);
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
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final saves = await SupabaseService.getSavedPosts(uid);
      if (mounted) {
        setState(() {
          _isSaved = saves.any((s) => s['post_id'] == widget.post['id']);
        });
      }
    } catch (e) {
      debugPrint('Error checking saved state: $e');
    }
  }

  Future<void> _checkSupportedState() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final response = await Supabase.instance.client
          .from('evaluations')
          .select('action')
          .eq('user_id', uid)
          .eq('post_id', widget.post['id'])
          .maybeSingle();
      if (mounted && response != null) {
        setState(() {
          _isSupported = response['action'] == 'support';
        });
      }
    } catch (e) {
      debugPrint('Error checking supported state: $e');
    }
  }

  Future<void> _toggleSave() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      if (_isSaved) {
        await SupabaseService.deleteSavedPost(userId: uid, postId: widget.post['id']);
      } else {
        await SupabaseService.insertSavedPost(userId: uid, postId: widget.post['id']);
      }
      setState(() => _isSaved = !_isSaved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _toggleSupport() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      if (_isSupported) {
        await Supabase.instance.client
            .from('evaluations')
            .delete()
            .eq('user_id', uid)
            .eq('post_id', widget.post['id']);
        setState(() {
          _isSupported = false;
          _supportCount = (_supportCount - 1).clamp(0, 999999);
        });
      } else {
        final metrics = widget.post['post_metrics'];
        final currentSupportCount = metrics?['support_count'] ?? 0;
        final currentSupportRate = double.tryParse(metrics?['support_rate']?.toString() ?? '0') ?? 0.0;

        await SupabaseService.insertEvaluation(
          userId: uid,
          postId: widget.post['id'],
          projectId: widget.post['project_id'],
          action: 'support',
          dwellMs: 0,
          openedDetail: true,
          supportCountAtEvaluation: currentSupportCount,
          supportRateAtEvaluation: currentSupportRate,
        );
        setState(() {
          _isSupported = true;
          _supportCount = _supportCount + 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      await SupabaseService.insertComment(
        postId: widget.post['id'],
        userId: uid,
        body: text,
      );
      _commentController.clear();
      _fetchComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コメント送信に失敗しました: $e')),
      );
    }
  }

  Widget _buildImageCard({required String imageUrl, required String badgeText}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFF9F9F9),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.teal),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                  ),
                ),
              ),
            ),
            // Badge Overlay
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: AppTheme.getNotoSansJP(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['profiles'];
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

    // Get formatted publish date (e.g. 2025/05/18)
    String timeAgo = '2026/06/23';
    final rawTime = post['published_at'] ?? post['created_at'];
    if (rawTime != null) {
      try {
        final date = DateTime.parse(rawTime).toLocal();
        timeAgo = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final initialCommentCount = widget.post['post_metrics']?['comment_count'] ?? 0;
    final commentCount = _isLoadingComments ? initialCommentCount : _comments.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header matching mockup (no title, back on left, dots on right)
            Container(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black87),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: const Icon(Icons.more_horiz, size: 22, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Author profile section
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF1F1F1),
                        backgroundImage: author?['avatar_url'] != null
                            ? NetworkImage(author['avatar_url'])
                            : null,
                        child: author?['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.grey, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author?['display_name'] ?? '市民メンバー',
                              style: AppTheme.getNotoSansJP(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeAgo,
                              style: AppTheme.getNotoSansJP(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 24,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Post Title
                  Text(
                    post['title'] ?? '',
                    style: AppTheme.getNotoSansJP(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tag badges (pill-shaped, light grey background, dark text, no # prefix)
                  () {
                    final ptList = post['post_tags'] as List?;
                    final tagsList = ptList?.map((pt) => pt['tags']?['title'] as String?).whereType<String>().toList() ?? [];
                    if (tagsList.isEmpty) return const SizedBox.shrink();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagsList.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.getNotoSansJP(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      )).toList(),
                    );
                  }(),
                  const SizedBox(height: 16),

                  // Stacked Images (AI Generation at top, before image at bottom)
                  if (afterImg.isNotEmpty)
                    _buildImageCard(
                      imageUrl: afterImg,
                      badgeText: '未来のイメージ',
                    ),
                  if (beforeImg.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildImageCard(
                      imageUrl: beforeImg,
                      badgeText: '元のイメージ',
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Post Body Description
                  Text(
                    post['body'] ?? '',
                    style: AppTheme.getNotoSansJP(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Heart, Comment, Share Row
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.black, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$_supportCount',
                        style: AppTheme.getManrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 19),
                      const SizedBox(width: 6),
                      Text(
                        '$commentCount',
                        style: AppTheme.getManrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.ios_share, color: Colors.black, size: 19),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFECECEC), height: 1),
                  const SizedBox(height: 16),

                  // Comments header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'コメント $commentCount',
                        style: AppTheme.getNotoSansJP(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'すべて見る',
                        style: AppTheme.getNotoSansJP(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Comment Input
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF1F1F1),
                        backgroundImage: author?['avatar_url'] != null
                            ? NetworkImage(author['avatar_url'])
                            : null,
                        child: author?['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.grey, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _commentController,
                            style: AppTheme.getNotoSansJP(fontSize: 13, color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'コメントを入力...',
                              hintStyle: AppTheme.getNotoSansJP(color: Colors.black45, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _postComment(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.teal, size: 18),
                        onPressed: _postComment,
                      ),
                    ],
                  ),

                  // Comment list
                  if (_comments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _comments.length > 3 ? 3 : _comments.length,
                      itemBuilder: (context, idx) {
                        final comm = _comments[idx];
                        final commAuthor = comm['profiles'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFF1F1F1),
                                backgroundImage: commAuthor?['avatar_url'] != null
                                    ? NetworkImage(commAuthor['avatar_url'])
                                    : null,
                                child: commAuthor?['avatar_url'] == null
                                    ? const Icon(Icons.person, color: Colors.grey, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      commAuthor?['display_name'] ?? '市民サポーター',
                                      style: AppTheme.getNotoSansJP(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      comm['body'] ?? '',
                                      style: AppTheme.getNotoSansJP(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Map Container with Center Pin
                  const SizedBox(height: 20),
                  Text(
                    '投稿場所',
                    style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            'https://tile.openstreetmap.org/15/29094/12711.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F1F1)),
                          ),
                        ),
                        Center(
                          child: Container(
                            transform: Matrix4.translationValues(0, -14, 0),
                            child: const Icon(
                              Icons.location_on,
                              color: AppTheme.teal,
                              size: 28,
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
                              post['address_text'] ?? '周辺の投稿を見る',
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          border: const Border(
            top: BorderSide(color: Color(0xFFECECEC), width: 1),
          ),
        ),
        child: Row(
          children: [
            // "応援する" button
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _toggleSupport,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF006C74),
                        Color(0xFF0C2030),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '応援する',
                        style: AppTheme.getNotoSansJP(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isSupported ? Icons.favorite : Icons.favorite_border,
                        color: _isSupported ? Colors.redAccent : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_supportCount',
                        style: AppTheme.getManrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // "保存する" button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _toggleSave,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFFECECEC),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: _isSaved ? const Color(0xFF006C74) : Colors.black87,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSaved ? '保存済み' : '保存する',
                        style: AppTheme.getNotoSansJP(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _isSaved ? const Color(0xFF006C74) : Colors.black87,
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
    );
  }
}

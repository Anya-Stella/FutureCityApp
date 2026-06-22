import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 10),
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
                    style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
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
                                    ? Image.network(
                                        afterImg,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(color: AppTheme.teal),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white24, size: 30),
                                        ),
                                      )
                                    : Image.network(
                                        beforeImg,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(color: AppTheme.teal),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white24, size: 30),
                                        ),
                                      ),
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
                        () {
                          final ptList = post['post_tags'] as List?;
                          final tagsList = ptList?.map((pt) => pt['tags']?['title'] as String?).whereType<String>().toList() ?? [];
                          if (tagsList.isEmpty) return const SizedBox.shrink();
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tagsList.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EFED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '#$tag',
                                style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.teal),
                              ),
                            )).toList(),
                          );
                        }(),
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
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

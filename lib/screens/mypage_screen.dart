// lib/screens/mypage_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final supabase = Supabase.instance.client;

  // Profile data
  dynamic _profile;
  List<dynamic> _myPosts = [];
  List<dynamic> _activityLedgers = [];
  List<dynamic> _earnedBadges = [];
  int _savedPostsCount = 0;
  int _earnedBadgesCount = 0;
  int _evalsCount = 0;
  int _commentsCount = 0;
  int _supportsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  Future<void> _loadAllProfileData() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch user profile join city type
      final prof = await supabase
          .from('profiles')
          .select('*, city_types(*)')
          .eq('id', uid)
          .maybeSingle();

      // 2. Fetch my submitted ideas
      final posts = await supabase
          .from('posts')
          .select('*, post_media(*), post_metrics(*)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      // 3. Fetch saved posts list join posts
      final saves = await supabase
          .from('saved_posts')
          .select('*, posts(*, post_media(*), post_metrics(*))')
          .eq('user_id', uid);

      // 4. Fetch earned badges
      final badges = await supabase
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', uid);

      // 5. Fetch point ledger
      final ledgers = await supabase
          .from('points_ledger')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      // 6. Fetch evaluations count
      final evalsCountRes = await supabase
          .from('evaluations')
          .select('id')
          .eq('user_id', uid);

      // 7. Fetch comments count
      final commentsCountRes = await supabase
          .from('comments')
          .select('id')
          .eq('user_id', uid);

      // 8. Fetch supports count
      final supportsCountRes = await supabase
          .from('evaluations')
          .select('id')
          .eq('user_id', uid)
          .eq('action', 'support');

      if (mounted) {
        setState(() {
          _profile = prof;
          _myPosts = posts;
          _savedPostsCount = saves.length;
          _earnedBadgesCount = badges.length;
          _earnedBadges = badges;
          _activityLedgers = ledgers;
          _evalsCount = (evalsCountRes as List).length;
          _commentsCount = (commentsCountRes as List).length;
          _supportsCount = (supportsCountRes as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting profile contents: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editProfileDialog() async {
    final nameController = TextEditingController(text: _profile?['display_name'] ?? '');
    final areaController = TextEditingController(text: _profile?['area_name'] ?? '');
    final residentController = TextEditingController(text: _profile?['resident_type'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プロフィール編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '表示名')),
            TextField(controller: areaController, decoration: const InputDecoration(labelText: '居住エリア')),
            TextField(controller: residentController, decoration: const InputDecoration(labelText: '居住形態 (例: 持ち家, 賃貸)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final uid = supabase.auth.currentUser?.id;
              if (uid == null) return;
              final navigator = Navigator.of(context);
              try {
                await supabase.from('profiles').update({
                  'display_name': nameController.text.trim(),
                  'area_name': areaController.text.trim(),
                  'resident_type': residentController.text.trim(),
                }).eq('id', uid);
                if (!mounted) return;
                navigator.pop();
                _loadAllProfileData();
              } catch (e) {
                debugPrint('Failed to update profile: $e');
              }
            },
            child: const Text('保存'),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  String _getActivityEmoji(String? reasonCode) {
    if (reasonCode == null) return '💰';
    switch (reasonCode) {
      case 'post_idea':
        return '📝';
      case 'evaluation':
      case 'support_post':
        return '💖';
      case 'comment':
        return '💬';
      case 'early_evaluation':
        return '🏆';
      default:
        return '🌱';
    }
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.teal)));
    }

    final int postsCount = _myPosts.length;
    final int supportsCount = _supportsCount;
    final int commentsCount = _commentsCount;
    final int evalsCount = _evalsCount;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: null, // Custom Header inside scroll body
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 112),
          children: [
            // 1. Custom Header
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 6, bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 38), // placeholder to balance right item
                  Text(
                    'マイページ',
                    style: AppTheme.getNotoSansJP(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.text),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _editProfileDialog,
                        child: const Icon(Icons.edit_note, size: 22, color: AppTheme.sub),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _logout,
                        child: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Profile Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D2230).withOpacity(0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.uiGrey,
                          backgroundImage: _profile?['avatar_url'] != null
                              ? NetworkImage(_profile['avatar_url'])
                              : null,
                          child: _profile?['avatar_url'] == null
                              ? const Icon(Icons.person, size: 30, color: AppTheme.sub)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?['display_name'] ?? 'ゲスト市民',
                                style: AppTheme.getNotoSansJP(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.text),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _profile?['area_name'] ?? '未設定エリア',
                                style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.sub),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 9),
                              // Sustainable member chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF6F2),
                                  border: Border.all(color: const Color(0xFFCFE6DC)),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.water_drop, size: 11, color: AppTheme.teal),
                                    const SizedBox(width: 5),
                                    Text(
                                      'サステナブル市民',
                                      style: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.teal),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Points indicator on right
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppTheme.teal,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'P',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_profile?['total_points'] ?? 0}',
                              style: AppTheme.getManrope(fontSize: 25, fontWeight: FontWeight.w900, color: AppTheme.text, height: 1),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'まちポイント',
                              style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.sub),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4 metrics boxes in a row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.bgSoft),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildMiniMetricBox('投稿', '$postsCount'),
                          _buildMiniMetricBox('応援', '${supportsCount + _savedPostsCount}', showBorder: true),
                          _buildMiniMetricBox('コメント', '$commentsCount', showBorder: true),
                          _buildMiniMetricBox('評価', '$evalsCount', showBorder: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 3. City Type Diagnosis result Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'あなたの街タイプ',
                    style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D2230).withOpacity(0.07),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _profile?['city_types']?['title'] != null
                                        ? Icons.water_drop
                                        : Icons.hourglass_empty,
                                    color: _profile?['city_types']?['title'] != null
                                        ? AppTheme.teal
                                        : AppTheme.sub,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _profile?['city_types']?['title'] ?? '計測中。。。',
                                      style: AppTheme.getNotoSansJP(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: _profile?['city_types']?['title'] != null
                                            ? AppTheme.teal
                                            : AppTheme.sub,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Text(
                                _profile?['city_types']?['description'] ?? 'スワイプ評価やアイデア投稿を続けると、あなたの街タイプが自動で計測・表示されます。',
                                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _profile?['city_types']?['image_url'] != null
                              ? Image.network(
                                  _profile['city_types']['image_url'],
                                  width: 96,
                                  height: 74,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 96,
                                      height: 74,
                                      child: Center(
                                        child: CircularProgressIndicator(color: AppTheme.teal),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 96,
                                    height: 74,
                                    child: Center(
                                      child: Icon(Icons.broken_image, color: AppTheme.sub, size: 28),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 96,
                                  height: 74,
                                  color: AppTheme.uiGrey,
                                  child: const Icon(Icons.analytics_outlined, color: AppTheme.sub, size: 28),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '獲得バッジ ($_earnedBadgesCount)',
                        style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      Text(
                        'すべて見る ›',
                        style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.teal, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _earnedBadges.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.bgSoft),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '獲得したバッジはまだありません。',
                            style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 13),
                          ),
                        )
                      : SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _earnedBadges.length,
                            itemBuilder: (context, index) {
                              final b = _earnedBadges[index]['badges'];
                              return _buildBadgeItem(
                                b?['icon_emoji'] ?? '🏅',
                                b?['name'] ?? 'バッジ',
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Recent activities
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最近の活動',
                        style: AppTheme.getNotoSansJP(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      Text(
                        'すべて見る ›',
                        style: AppTheme.getNotoSansJP(fontSize: 12, color: AppTheme.teal, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _activityLedgers.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text('活動履歴がありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)),
                        )
                      : Column(
                          children: _activityLedgers.take(3).map((ledger) {
                            final bool isAdd = ledger['amount'] >= 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0D2230).withOpacity(0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F8F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _getActivityEmoji(ledger['reason_code']),
                                      style: const TextStyle(fontSize: 19),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ledger['reason_label_snapshot'] ?? ledger['reason_code'] ?? 'ポイント獲得',
                                          style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text, height: 1.45),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _getAgoString(ledger['created_at']),
                                          style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isAdd ? "+" : ""}${ledger['amount']} pts',
                                    style: AppTheme.getManrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isAdd ? AppTheme.teal : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetricBox(String label, String value, {bool showBorder = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(left: BorderSide(color: AppTheme.bgSoft, width: 1))
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.sub),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: AppTheme.getNotoSansJP(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(String emoji, String title) {
    return Container(
      width: 75,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
              border: Border.all(color: AppTheme.border),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: AppTheme.getNotoSansJP(fontSize: 9, color: AppTheme.sub, fontWeight: FontWeight.w600, height: 1.3),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  // Profile data
  dynamic _profile;
  List<dynamic> _myPosts = [];
  List<dynamic> _savedPosts = [];
  List<dynamic> _earnedBadges = [];
  List<dynamic> _activityLedgers = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      if (mounted) {
        setState(() {
          _profile = prof;
          _myPosts = posts;
          _savedPosts = saves;
          _earnedBadges = badges;
          _activityLedgers = ledgers;
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
              try {
                await supabase.from('profiles').update({
                  'display_name': nameController.text.trim(),
                  'area_name': areaController.text.trim(),
                  'resident_type': residentController.text.trim(),
                }).eq('id', uid);
                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.teal)));
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('マイページ', style: AppTheme.getNotoSansJP(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: AppTheme.sub), onPressed: _editProfileDialog),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          // Header Profile section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.uiGrey,
                  backgroundImage: _profile?['avatar_url'] != null
                      ? NetworkImage(_profile['avatar_url'])
                      : null,
                  child: _profile?['avatar_url'] == null
                      ? const Icon(Icons.person, size: 36, color: AppTheme.sub)
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?['display_name'] ?? 'ゲスト市民',
                        style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.tealDark, borderRadius: BorderRadius.circular(4)),
                            child: Text('Level ${_profile?['level'] ?? 1}',
                                style: AppTheme.getManrope(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '診断結果: ${_profile?['city_types']?['title'] ?? '未受診'}',
                            style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '保有ポイント: ${_profile?['total_points'] ?? 0} pts',
                        style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.teal),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const Divider(),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.teal,
            labelColor: AppTheme.teal,
            unselectedLabelColor: AppTheme.sub,
            labelStyle: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'マイ投稿'),
              Tab(text: '保存済み'),
              Tab(text: 'バッジ'),
              Tab(text: '履歴'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyPostsTab(),
                _buildSavedPostsTab(),
                _buildBadgesTab(),
                _buildHistoryTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMyPostsTab() {
    if (_myPosts.isEmpty) {
      return Center(child: Text('まだ投稿がありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _myPosts.length,
      itemBuilder: (context, idx) {
        final post = _myPosts[idx];
        final media = post['post_media'] as List?;
        final imgUrl = media != null && media.isNotEmpty ? media.first['url'] : '';
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(imgUrl, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.uiGrey, width: 44, height: 44),
              ),
            ),
            title: Text(post['title'] ?? '無題', style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(post['body'] ?? '', style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(post['status'] == 'published' ? '公開中' : '保留', style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.teal)),
          ),
        );
      },
    );
  }

  Widget _buildSavedPostsTab() {
    if (_savedPosts.isEmpty) {
      return Center(child: Text('保存した投稿はありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _savedPosts.length,
      itemBuilder: (context, idx) {
        final save = _savedPosts[idx];
        final post = save['posts'];
        final media = post?['post_media'] as List?;
        final imgUrl = media != null && media.isNotEmpty ? media.first['url'] : '';
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(imgUrl, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.uiGrey, width: 44, height: 44),
              ),
            ),
            title: Text(post?['title'] ?? '無題', style: AppTheme.getNotoSansJP(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('保存日時: ${DateTime.parse(save['created_at']).toLocal().month}/${DateTime.parse(save['created_at']).toLocal().day}',
                style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.muted)),
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab() {
    if (_earnedBadges.isEmpty) {
      return Center(child: Text('獲得バッジはまだありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _earnedBadges.length,
      itemBuilder: (context, idx) {
        final badge = _earnedBadges[idx]['badges'];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: AppTheme.gold, size: 36),
              const SizedBox(height: 8),
              Text(
                badge?['title'] ?? '市民',
                style: AppTheme.getNotoSansJP(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  badge?['description'] ?? '',
                  style: AppTheme.getNotoSansJP(fontSize: 9, color: AppTheme.sub),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_activityLedgers.isEmpty) {
      return Center(child: Text('履歴はありません', style: AppTheme.getNotoSansJP(color: AppTheme.sub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activityLedgers.length,
      itemBuilder: (context, idx) {
        final ledger = _activityLedgers[idx];
        final isAdd = ledger['amount'] >= 0;
        final created = DateTime.parse(ledger['created_at']).toLocal();

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            dense: true,
            title: Text(ledger['reason_label_snapshot'] ?? ledger['reason_code'] ?? 'ポイント調整',
                style: AppTheme.getNotoSansJP(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text('${created.year}/${created.month}/${created.day} ${created.hour}:${created.minute}',
                style: AppTheme.getNotoSansJP(fontSize: 10, color: AppTheme.muted)),
            trailing: Text(
              '${isAdd ? "+" : ""}${ledger['amount']} pts',
              style: AppTheme.getManrope(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isAdd ? AppTheme.teal : Colors.redAccent,
              ),
            ),
          ),
        );
      },
    );
  }
}

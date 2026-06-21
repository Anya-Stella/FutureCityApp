// lib/screens/create_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  List<dynamic> _projects = [];
  String? _selectedProjectId;

  // Preset Mock images to bypass native photo uploads on desktop/restricted platforms
  final List<Map<String, String>> _presets = [
    {
      'name': '寂れた広場',
      'url': 'https://images.unsplash.com/photo-1549474843-ed83483f6ec6?q=80&w=600',
    },
    {
      'name': 'シャッター通り商店街',
      'url': 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?q=80&w=600',
    },
    {
      'name': 'コンクリートの空き地',
      'url': 'https://images.unsplash.com/photo-1596701062351-df1f8d368a85?q=80&w=600',
    }
  ];
  String? _selectedPresetUrl;

  // Tags list
  final List<String> _availableTags = ['歩道拡幅', '緑化', 'ベンチ', '照明', 'バリアフリー', 'アート'];
  final Set<String> _selectedTags = {'歩道拡幅'};

  // Job Flow
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String _stepLabel = '';

  @override
  void initState() {
    super.initState();
    _selectedPresetUrl = _presets[0]['url'];
    _fetchProjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await supabase.from('projects').select('*').eq('status', 'active');
      setState(() {
        _projects = data;
      });
    } catch (e) {
      debugPrint('Error getting projects: $e');
    }
  }

  Future<void> _triggerAIGeneration() async {
    if (_selectedPresetUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BEFORE画像（元の風景）を選択してください')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _stepLabel = 'AI生成ジョブを開始しています...';
    });

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Insert job to ai_generation_jobs
      final job = await supabase.from('ai_generation_jobs').insert({
        'user_id': uid,
        'status': 'queued',
        'prompt': 'A beautiful futuristic park with dense trees, clean walkpaths, modern white benches, and smart solar panel lights, warm daylight',
      }).select().single();

      final jobId = job['id'];

      // 2. Poll job status until succeeded or failed
      int checkCount = 0;
      Timer.periodic(const Duration(seconds: 2), (timer) async {
        checkCount++;

        if (checkCount > 8) { // Timeout safety fallback (shortened for better UX)
          timer.cancel();
          _finishJobWithFallback();
          return;
        }

        try {
          final currentJob = await supabase
              .from('ai_generation_jobs')
              .select('*')
              .eq('id', jobId)
              .single();

          final status = currentJob['status'] as String;

          if (mounted) {
            setState(() {
              if (status == 'queued') {
                _stepLabel = 'サーバーの空きを待っています...';
              } else if (status == 'running') {
                _stepLabel = 'AI画質レンダリングを処理しています... (50%)';
              }
            });
          }

          if (status == 'succeeded') {
            timer.cancel();
            setState(() {
              _isGenerating = false;
              _generatedImageUrl = currentJob['output_image_url'] ?? _presets[0]['url']; // fallback
            });
          } else if (status == 'failed') {
            timer.cancel();
            _finishJobWithFallback();
          }
        } catch (e) {
          debugPrint('Error polling job status: $e');
        }
      });

    } catch (e) {
      debugPrint('Error inserting job: $e');
      _finishJobWithFallback();
    }
  }

  void _finishJobWithFallback() {
    // Generate a fallback futuristic mock visual when OpenAI credentials aren't initialized
    setState(() {
      _isGenerating = false;
      _generatedImageUrl = 'https://images.unsplash.com/photo-1444724338557-eb0407a539d4?q=80&w=600'; // mock future park image
    });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPresetUrl == null || _generatedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像生成が完了していません')),
      );
      return;
    }

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Insert post
      final post = await supabase.from('posts').insert({
        'user_id': uid,
        'project_id': _selectedProjectId,
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'status': 'published',
        'address_text': '未来都市指定計画エリア 3工区',
      }).select().single();

      // 2. Insert media items
      await supabase.from('post_media').insert([
        {
          'post_id': post['id'],
          'media_type': 'before',
          'url': _selectedPresetUrl,
        },
        {
          'post_id': post['id'],
          'media_type': 'generated',
          'url': _generatedImageUrl,
        }
      ]);

      if (mounted) {
        Navigator.of(context).pop(); // Close create modal

        // Show celebratory success popup
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 投稿に成功しました！'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('あなたの素晴らしいアイデアが公開されました。'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+100 まちポイント獲得！',
                    style: AppTheme.getNotoSansJP(color: AppTheme.teal, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              )
            ],
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿の登録に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag indicator bar
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
            padding: const EdgeInsets.only(left: 18, right: 18, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.text),
                  ),
                ),
                Text(
                  'アイデアをつくる',
                  style: AppTheme.getNotoSansJP(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '?',
                    style: TextStyle(color: AppTheme.sub, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                children: [
                  // 1. Image upload container
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.teal, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '写真をアップロード',
                        style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),

                  // Image Container
                  Container(
                    height: 196,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0C1920).withOpacity(0.12),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _selectedPresetUrl != null
                              ? Image.network(_selectedPresetUrl!, fit: BoxFit.cover)
                              : Container(color: AppTheme.border),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF060F14).withOpacity(0.34),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Floating camera button
                        Positioned(
                          bottom: 14,
                          left: 14,
                          child: GestureDetector(
                            onTap: () {
                              // Cycle through presets as a demo upload action
                              final currentIndex = _presets.indexWhere((element) => element['url'] == _selectedPresetUrl);
                              final nextIndex = (currentIndex + 1) % _presets.length;
                              setState(() {
                                _selectedPresetUrl = _presets[nextIndex]['url'];
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF07121A).withOpacity(0.78),
                                border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 4)),
                                ],
                              ),
                              child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Preset Picker Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _presets.map((preset) {
                      final bool isSel = _selectedPresetUrl == preset['url'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPresetUrl = preset['url']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: isSel ? AppTheme.teal : AppTheme.border, width: isSel ? 2 : 1),
                            borderRadius: BorderRadius.circular(10),
                            color: isSel ? AppTheme.teal.withOpacity(0.05) : Colors.white,
                          ),
                          child: Text(
                            preset['name']!,
                            style: AppTheme.getNotoSansJP(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? AppTheme.teal : AppTheme.sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  // 2. Choose Theme Tag Chips
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.teal, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'テーマを選択',
                        style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '（複数選択可）',
                        style: AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _availableTags.map((tag) {
                      final bool isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.tealDark : AppTheme.uiGrey,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: AppTheme.getNotoSansJP(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  // 3. AI Predictive View Generation
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.teal, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, size: 10, color: AppTheme.teal),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'AIで未来景観を生成',
                        style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: const BoxDecoration(color: AppTheme.uiGrey, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('i', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.sub)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),

                  Container(
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0C1920).withOpacity(0.16),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Show mock background
                        Positioned.fill(
                          child: _generatedImageUrl != null
                              ? Image.network(_generatedImageUrl!, fit: BoxFit.cover)
                              : (_selectedPresetUrl != null
                                  ? ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withOpacity(0.4),
                                        BlendMode.multiply,
                                      ),
                                      child: Image.network(_selectedPresetUrl!, fit: BoxFit.cover),
                                    )
                                  : Container(color: AppTheme.border)),
                        ),

                        // Spinner overlay when generating
                        if (_isGenerating)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF050E14).withOpacity(0.62),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accent,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    _stepLabel.isNotEmpty ? _stepLabel : 'AIが未来の景観を生成中…',
                                    style: AppTheme.getNotoSansJP(
                                      color: const Color(0xFFDFF4F1),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Succeeded badge overlay
                        if (_generatedImageUrl != null && !_isGenerating)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xEC006C74),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'AFTER（AI生成）',
                                style: AppTheme.getNotoSansJP(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                        // Generate Button Overlay
                        if (_generatedImageUrl == null && !_isGenerating)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black12,
                              padding: const EdgeInsets.all(18),
                              alignment: Alignment.bottomCenter,
                              child: GestureDetector(
                                onTap: _triggerAIGeneration,
                                child: Container(
                                  height: 50,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.teal, AppTheme.tealDark],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.teal.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'AIで生成する',
                                        style: AppTheme.getNotoSansJP(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 4. Beautiful, Unobtrusive Text Form inputs (shown ONLY when AI Generation is complete)
                  if (_generatedImageUrl != null && !_isGenerating) ...[
                    const SizedBox(height: 24),
                    Text(
                      '3. アイデア詳細',
                      style: AppTheme.getNotoSansJP(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      hint: Text('紐づける行政チャレンジを選択（任意）', style: AppTheme.getNotoSansJP(fontSize: 13, color: AppTheme.sub)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      items: _projects.map((proj) {
                        return DropdownMenuItem<String>(
                          value: proj['id'],
                          child: Text(proj['title'] ?? '', style: AppTheme.getNotoSansJP(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProjectId = val),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      style: AppTheme.getNotoSansJP(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'タイトル',
                        hintText: '例: 緑豊かなスマートバス停の設置',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'タイトルを入力してください' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _bodyController,
                      style: AppTheme.getNotoSansJP(fontSize: 14),
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: '提案内容',
                        hintText: '現状の課題、AIで生成した画像の意図、もたらされる効果などを記入してください。',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? '内容を記入してください' : null,
                    ),
                    const SizedBox(height: 20),

                    // Submit Post Button
                    GestureDetector(
                      onTap: _submitPost,
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.teal.withOpacity(0.32),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'この景観でアイデアを投稿する',
                          style: AppTheme.getNotoSansJP(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _triggerAIGeneration,
                      child: Center(
                        child: Text(
                          'もう一度生成する',
                          style: AppTheme.getNotoSansJP(color: AppTheme.sub, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

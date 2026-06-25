// lib/screens/create_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class CreateScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CreateScreen({super.key, this.onBack});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _addressController = TextEditingController();
  final _promptController = TextEditingController();

  List<dynamic> _projects = [];
  String? _selectedProjectId;

  // Preset Mock images to bypass native photo uploads on desktop/restricted platforms
  final List<Map<String, String>> _presets = [
    {
      'name': '大宮駅東口（現状）',
      'url': 'assets/street-before.png',
    },
    {
      'name': '寂れた広場',
      'url': 'https://picsum.photos/seed/square/600/600',
    },
    {
      'name': 'シャッター通り商店街',
      'url': 'https://picsum.photos/seed/street/600/600',
    },
    {
      'name': 'コンクリートの空き地',
      'url': 'https://picsum.photos/seed/vacant/600/600',
    }
  ];
  String? _selectedPresetUrl;
  bool _isUploadingPhoto = false;
  // ローカル選択した画像（バイト列）。アップロードはAI生成時に行う
  Uint8List? _pickedImageBytes;
  String _pickedImageMime = 'image/jpeg';
  String? _uploadedBeforeUrl; // AI生成後に確定するbefore URL

  // Tags list
  final List<String> _fallbackTags = [
    '歩きにくい・危ない', '緑や自然が少ない', '休む場所がない',
    '暗い・治安が不安', 'にぎわいがない', '子ども・高齢者に不便',
    '人にやさしい街', '緑あふれる街', '安心・安全な街',
    'にぎわいのある街', '子どもが育つ街', '移動しやすい街',
  ];
  List<dynamic> _dbTags = [];
  final Set<String> _selectedTags = {};

  static const Map<String, String> _fallbackTagIds = {};

  List<String> get _displayTags => _dbTags.isNotEmpty
      ? _dbTags.map((t) => t['title'] as String).toList()
      : _fallbackTags;

  // Job Flow
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String _stepLabel = '';

  @override
  void initState() {
    super.initState();
    _selectedPresetUrl = _presets[0]['url'];
    _fetchProjects();
    _fetchTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _addressController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await SupabaseService.getActiveProjects();
      setState(() {
        _projects = data;
      });
    } catch (e) {
      debugPrint('Error getting projects: $e');
    }
  }

  Future<void> _fetchTags() async {
    try {
      final data = await SupabaseService.getTags();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _dbTags = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tags: $e');
    }
  }

  // Location is fixed to the Imperial Palace (皇居) for this MVP.
  static const String _fixedLocation = '皇居';

  Future<void> _triggerAIGeneration() async {
    // ローカル選択画像もプリセットURLもない場合はエラー
    if (_pickedImageBytes == null && _selectedPresetUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BEFORE画像（元の風景）を選択してください')),
      );
      return;
    }

    // Require at least a tag or a free prompt before starting generation.
    if (_selectedTags.isEmpty && _promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タグを選ぶか、AIへの指示を入力してください')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _stepLabel = 'AI生成ジョブを開始しています...';
    });

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      // Find tag IDs
      final List<String> selectedTagIds = [];
      for (final title in _selectedTags) {
        final dbTagIndex = _dbTags.indexWhere((t) => t['title'] == title);
        final dbTag = dbTagIndex >= 0 ? _dbTags[dbTagIndex] : null;
        if (dbTag != null) {
          selectedTagIds.add(dbTag['id'] as String);
        } else if (_fallbackTagIds.containsKey(title)) {
          selectedTagIds.add(_fallbackTagIds[title]!);
        }
      }

      final tagListString = _selectedTags.join(', ');
      final userPrompt = _promptController.text.trim();
      // Location is fixed to 皇居. The Edge Function does the final, weighted
      // prompt synthesis server-side; this string is the raw job input.
      final prompt = '場所: $_fixedLocation。'
          '${tagListString.isNotEmpty ? 'タグ: $tagListString。' : ''}'
          '${userPrompt.isNotEmpty ? '要望: $userPrompt' : ''}';

      // 1. ローカル画像があればここでアップロード
      String inputImageUrl = _selectedPresetUrl ?? '';
      if (_pickedImageBytes != null) {
        inputImageUrl = await SupabaseService.uploadBeforeImage(
          userId: uid,
          bytes: _pickedImageBytes!,
          mimeType: _pickedImageMime,
        );
        _uploadedBeforeUrl = inputImageUrl;
      }

      // 2. Insert job to ai_generation_jobs
      final job = await SupabaseService.insertAIGenerationJob(
        userId: uid,
        projectId: _selectedProjectId,
        inputImageUrl: inputImageUrl,
        selectedTagIds: selectedTagIds,
        prompt: prompt,
      );

      final jobId = job['id'];

      // 2. Trigger server-side processing (OpenAI runs server-side only).
      //    Fire-and-forget so polling starts immediately and observes
      //    queued/running/succeeded/failed through ai_generation_jobs.
      unawaited(
        SupabaseService.invokeProcessAIGeneration(jobId).catchError((e) {
          debugPrint('Error invoking process-ai-generation: $e');
        }),
      );

      // 3. Poll job status until succeeded or failed
      int checkCount = 0;
      Timer.periodic(const Duration(seconds: 2), (timer) async {
        checkCount++;

        if (checkCount > 40) { // Timeout safety fallback for image generation (about 80s)
          timer.cancel();
          _finishJobWithFallback();
          return;
        }

        try {
          final currentJob = await SupabaseService.getAIGenerationJob(jobId);

          final status = currentJob['status'] as String;

          if (!mounted) return;
          setState(() {
            if (status == 'queued') {
              _stepLabel = 'サーバーの空きを待っています...';
            } else if (status == 'running') {
              _stepLabel = 'AI画質レンダリングを処理しています... (50%)';
            }
          });

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
    // Generate a fallback futuristic mock visual depending on the selected tags
    final keywords = _selectedTags.isNotEmpty ? _selectedTags.join(',') : 'city,architecture';
    setState(() {
      _isGenerating = false;
      _generatedImageUrl = 'https://loremflickr.com/600/600/futuristic,$keywords';
    });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_selectedPresetUrl == null && _uploadedBeforeUrl == null) || _generatedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像生成が完了していません')),
      );
      return;
    }

    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    try {
      final String addressText = _addressController.text.trim();

      // 1. Insert post
      final post = await SupabaseService.insertPost(
        userId: uid,
        projectId: _selectedProjectId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        addressText: addressText,
      );

      // 2. Insert media items
      await SupabaseService.insertPostMedia([
        {
          'post_id': post['id'],
          'media_type': 'before',
          'url': _uploadedBeforeUrl ?? _selectedPresetUrl,
        },
        {
          'post_id': post['id'],
          'media_type': 'generated',
          'url': _generatedImageUrl,
        }
      ]);

      // 3. Insert post tags relation
      final List<String> tagIdsToInsert = [];
      for (final title in _selectedTags) {
        final dbTagIndex = _dbTags.indexWhere((t) => t['title'] == title);
        final dbTag = dbTagIndex >= 0 ? _dbTags[dbTagIndex] : null;
        if (dbTag != null) {
          tagIdsToInsert.add(dbTag['id'] as String);
        } else if (_fallbackTagIds.containsKey(title)) {
          tagIdsToInsert.add(_fallbackTagIds[title]!);
        }
      }

      if (tagIdsToInsert.isNotEmpty) {
        await SupabaseService.insertPostTags(
          tagIdsToInsert.map((tid) => {
            'post_id': post['id'],
            'tag_id': tid,
          }).toList(),
        );
      }

      if (!mounted) return;

      // 投稿完了後、すべての状態を初期化
      setState(() {
        _pickedImageBytes = null;
        _pickedImageMime = 'image/jpeg';
        _uploadedBeforeUrl = null;
        _selectedPresetUrl = _presets[0]['url'];
        _selectedTags.clear();
        _generatedImageUrl = null;
        _isGenerating = false;
        _stepLabel = '';
        _selectedProjectId = null;
        _titleController.clear();
        _bodyController.clear();
        _addressController.clear();
        _promptController.clear();
      });

      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.of(context).maybePop();
      }

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

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿の登録に失敗しました: $e')),
      );
    }
  }

  void _cyclePreset() {
    final currentIndex = _presets.indexWhere((e) => e['url'] == _selectedPresetUrl);
    final nextIndex = (currentIndex + 1) % _presets.length;
    setState(() => _selectedPresetUrl = _presets[nextIndex]['url']);
  }

  // Section 1: ローカルで画像を選ぶだけ。アップロードはAI生成時に行う
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1536,
      maxHeight: 1536,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageMime = mime;
      _selectedPresetUrl = null; // ローカル表示に切り替え
      _uploadedBeforeUrl = null;
    });
  }

  int get _currentStep {
    if (_generatedImageUrl != null && !_isGenerating) return 4;
    if (_isGenerating) return 3;
    return 1;
  }

  // ── ステップバー ─────────────────────────────────────────────
  Widget _buildStepBar() {
    final steps = ['撮る', 'タグ', '生成', '投稿'];
    final current = _currentStep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildStepItem(i + 1, steps[i], i + 1 == current, i + 1 < current),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text('→',
                  style: TextStyle(
                      color: AppTheme.sub.withOpacity(0.4), fontSize: 11)),
            ),
        ],
      ],
    );
  }

  Widget _buildStepItem(int num, String label, bool isActive, bool isDone) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(0.0, -0.75),
            radius: 1.1,
            colors: [
              Color(0xFF10756F),
              Color(0xFF0A5650),
              Color(0xFF064A52),
              Color(0xFF0A3540),
            ],
            stops: [0.0, 0.30, 0.62, 1.0],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            CustomPaint(
              painter: _CircleNumberPainter(
                number: '$num',
                circleColor: Colors.white,
                textColor: AppTheme.teal,
              ),
              size: const Size(18, 18),
            ),
            const SizedBox(width: 9),
            Text(label,
                style: AppTheme.getNotoSansJP(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      );
    }
    return Row(
      children: [
        CustomPaint(
          painter: _CircleNumberPainter(
            number: '$num',
            circleColor: isDone ? AppTheme.teal.withOpacity(0.12) : Colors.transparent,
            textColor: isDone ? AppTheme.teal : AppTheme.sub.withOpacity(0.55),
            hasBorder: true,
            borderColor: AppTheme.sub.withOpacity(0.3),
          ),
          size: const Size(18, 18),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: AppTheme.getNotoSansJP(
                fontSize: 13, color: AppTheme.sub.withOpacity(0.65))),
      ],
    );
  }

  // ── セクションヘッダー ───────────────────────────────────────
  Widget _buildSectionHeader(int num, String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration:
              const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.75),
                  radius: 1.1,
                  colors: [
                    Color(0xFF10756F),
                    Color(0xFF0A5650),
                    Color(0xFF064A52),
                    Color(0xFF0A3540),
                  ],
                  stops: [0.0, 0.30, 0.62, 1.0],
                ),
                shape: BoxShape.circle,
              ),
          alignment: Alignment.center,
          child: Text('$num',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 9),
        Text(title,
            style: AppTheme.getNotoSansJP(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        if (subtitle != null) ...[
          const SizedBox(width: 4),
          Text(subtitle,
              style:
                  AppTheme.getNotoSansJP(fontSize: 11, color: AppTheme.sub)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── ヘッダー ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppTheme.text),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '未来のアイデアをつくる',
                        style: AppTheme.getNotoSansJP(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── ステップバー ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildStepBar(),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8EAE6)),

            // ── スクロールコンテンツ ─────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  children: [
                    // ── Section 1: 写真アップロード ────────────────
                    _buildSectionHeader(1, '現在の写真をアップロード'),
                    const SizedBox(height: 13),

                    Container(
                      height: 200,
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
                            child: _pickedImageBytes != null
                                ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                                : _selectedPresetUrl != null
                                    ? AppTheme.buildImage(_selectedPresetUrl!)
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
                                    const Color(0xFF060F14).withOpacity(0.38),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // アップロード中オーバーレイ
                          if (_isUploadingPhoto)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.45),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              ),
                            ),
                          // 写真をアップロードボタン（右下）
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.upload_rounded, size: 14, color: AppTheme.text),
                                    const SizedBox(width: 5),
                                    Text('写真をアップロード',
                                        style: AppTheme.getNotoSansJP(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.text)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Section 2: タグ選択 ───────────────────────
                    _buildSectionHeader(2, 'アイデアのタグを選ぶ',
                        subtitle: '（複数選択可）'),
                    const SizedBox(height: 13),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _displayTags.map((tag) {
                        final bool isSelected = _selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const RadialGradient(
                                      center: Alignment(0.0, -0.75),
                                      radius: 1.1,
                                      colors: [
                                        Color(0xFF10756F),
                                        Color(0xFF0A5650),
                                        Color(0xFF064A52),
                                        Color(0xFF0A3540),
                                      ],
                                      stops: [0.0, 0.30, 0.62, 1.0],
                                    )
                                  : null,
                              color: isSelected ? null : AppTheme.uiGrey,
                              borderRadius: BorderRadius.circular(999),
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                      width: 1.0)
                                  : null,
                            ),
                            child: Text(
                              tag,
                              style: AppTheme.getNotoSansJP(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected ? Colors.white : AppTheme.sub,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // ── Section 3: AI生成 ────────────────────────
                    _buildSectionHeader(3, 'AIで未来の景観を生成'),
                    const SizedBox(height: 13),

                    // ── プロンプト入力 ────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border, width: 1.5),
                      ),
                      child: TextField(
                        controller: _promptController,
                        maxLines: 3,
                        style: AppTheme.getNotoSansJP(
                            fontSize: 14, color: AppTheme.text),
                        decoration: InputDecoration(
                          hintText: 'AIへの指示を入力（任意）\n例: 夜でも明るく、子どもが遊べる広場にしてほしい',
                          hintStyle: AppTheme.getNotoSansJP(
                              fontSize: 13, color: AppTheme.sub),
                          contentPadding: const EdgeInsets.all(14),
                          border: InputBorder.none,
                        ),
                      ),
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
                          Positioned.fill(
                            child: _generatedImageUrl != null
                                ? AppTheme.buildImage(_generatedImageUrl!)
                                : Image.asset('assets/generate-placeholder.png',
                                    fit: BoxFit.cover),
                          ),
                          // 生成中スピナー
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
                                          color: AppTheme.accent, strokeWidth: 3),
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                      _stepLabel.isNotEmpty
                                          ? _stepLabel
                                          : 'AIが未来の景観を生成中…',
                                      style: AppTheme.getNotoSansJP(
                                          color: const Color(0xFFDFF4F1),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // 生成済みバッジ
                          if (_generatedImageUrl != null && !_isGenerating)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xEC006C74),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('AFTER（AI生成）',
                                    style: AppTheme.getNotoSansJP(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 生成ボタン（画像の下）
                    if (_generatedImageUrl == null && !_isGenerating) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _triggerAIGeneration,
                        child: Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D7872).withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Stack(
                              children: [
                                // ベースグラデーション
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment(0.0, -0.8),
                                        radius: 1.4,
                                        colors: [
                                          Color(0xFF1A8F89),
                                          Color(0xFF0D6B65),
                                          Color(0xFF054A52),
                                          Color(0xFF011C24),
                                        ],
                                        stops: [0.0, 0.28, 0.60, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                // 上部光沢オーバーレイ
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.18),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // テキスト＋星
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'AIで生成する',
                                          style: AppTheme.getNotoSansJP(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(width: 10),
                                        // 星3つ（大・小・中）
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('✦', style: TextStyle(color: Colors.white, fontSize: 8, height: 1)),
                                            const SizedBox(height: 1),
                                            const Text('✦', style: TextStyle(color: Colors.white, fontSize: 13, height: 1)),
                                          ],
                                        ),
                                        const SizedBox(width: 3),
                                        const Text('✦', style: TextStyle(color: Colors.white, fontSize: 7, height: 1)),
                                      ],
                                    ),
                                  ),
                                ),
                                // 外枠（ガラス感）
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.18),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── 生成後フォーム ─────────────────────────────
                    if (_generatedImageUrl != null && !_isGenerating) ...[
                      const SizedBox(height: 28),
                      _buildSectionHeader(4, 'アイデア詳細を入力'),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _selectedProjectId,
                        hint: Text('紐づける行政チャレンジを選択（任意）',
                            style: AppTheme.getNotoSansJP(
                                fontSize: 13, color: AppTheme.sub)),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        items: _projects.map((proj) {
                          return DropdownMenuItem<String>(
                            value: proj['id'],
                            child: Text(proj['title'] ?? '',
                                style: AppTheme.getNotoSansJP(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedProjectId = val),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _addressController,
                        style: AppTheme.getNotoSansJP(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: '実施予定エリア・場所',
                          hintText: '例: 未来都市指定計画エリア 3工区',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'エリア・場所を入力してください'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _titleController,
                        style: AppTheme.getNotoSansJP(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'タイトル',
                          hintText: '例: 緑豊かなスマートバス停の設置',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'タイトルを入力してください'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _bodyController,
                        style: AppTheme.getNotoSansJP(fontSize: 14),
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: '提案内容',
                          hintText:
                              '現状の課題、AIで生成した画像の意図、もたらされる効果などを記入してください。',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.isEmpty)
                            ? '内容を記入してください'
                            : null,
                      ),
                      const SizedBox(height: 22),

                      GestureDetector(
                        onTap: _submitPost,
                        child: Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(
                              center: Alignment(0.0, -0.8),
                              radius: 1.4,
                              colors: [
                                Color(0xFF10756F),
                                Color(0xFF0A5650),
                                Color(0xFF064A52),
                                Color(0xFF0A3540),
                              ],
                              stops: [0.0, 0.28, 0.60, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0A5650).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text('この景観でアイデアを投稿する',
                              style: AppTheme.getNotoSansJP(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      GestureDetector(
                        onTap: _triggerAIGeneration,
                        child: Center(
                          child: Text('もう一度生成する',
                              style: AppTheme.getNotoSansJP(
                                  color: AppTheme.sub,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleNumberPainter extends CustomPainter {
  final String number;
  final Color circleColor;
  final Color textColor;
  final bool hasBorder;
  final Color? borderColor;

  const _CircleNumberPainter({
    required this.number,
    required this.circleColor,
    required this.textColor,
    this.hasBorder = false,
    this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()..color = circleColor;
    canvas.drawCircle(center, radius, circlePaint);

    if (hasBorder && borderColor != null) {
      final borderPaint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius - 0.5, borderPaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleNumberPainter old) =>
      old.number != number ||
      old.circleColor != circleColor ||
      old.textColor != textColor;
}

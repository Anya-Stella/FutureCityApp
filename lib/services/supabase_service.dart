import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final _supabase = Supabase.instance.client;

  // --- Auth Section ---
  static Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
  static User? get currentUser => _supabase.auth.currentUser;
  static Session? get currentSession => _supabase.auth.currentSession;

  static Future<AuthResponse> signUp({required String email, required String password}) {
    return _supabase.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signInWithPassword({required String email, required String password}) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  // --- Projects Section ---
  static Future<List<dynamic>> getActiveProjects() async {
    return await _supabase
        .from('projects')
        .select('*')
        .eq('status', 'active')
        .order('ends_at', ascending: true);
  }

  // --- Posts Section ---
  static Future<List<dynamic>> getPublishedPosts() async {
    return await _supabase
        .from('posts')
        .select('*, profiles:profiles!posts_user_id_fkey(*), post_media(*), post_metrics(*)')
        .eq('status', 'published');
  }

  static Future<List<dynamic>> getMyPosts(String userId) async {
    return await _supabase
        .from('posts')
        .select('*, post_media(*), post_metrics(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  static Future<List<dynamic>> getSavedPosts(String userId) async {
    return await _supabase
        .from('saved_posts')
        .select('*, posts(*, post_media(*), post_metrics(*))')
        .eq('user_id', userId);
  }

  static Future<Map<String, dynamic>> insertPost({
    required String userId,
    required String? projectId,
    required String title,
    required String body,
    required String addressText,
  }) async {
    return await _supabase.from('posts').insert({
      'user_id': userId,
      'project_id': projectId,
      'title': title,
      'body': body,
      'status': 'published',
      'address_text': addressText,
    }).select().single();
  }

  // --- Post Media ---
  static Future<void> insertPostMedia(List<Map<String, dynamic>> mediaItems) async {
    await _supabase.from('post_media').insert(mediaItems);
  }

  // --- Post Tags ---
  static Future<void> insertPostTags(List<Map<String, dynamic>> postTags) async {
    await _supabase.from('post_tags').insert(postTags);
  }

  // --- Tags Section ---
  static Future<List<dynamic>> getTags() async {
    return await _supabase.from('tags').select('*').order('title');
  }

  // --- Evaluations Section ---
  static Future<List<dynamic>> getUnevaluatedPosts(String userId) async {
    final response = await _supabase
        .from('posts')
        .select('*, post_media(*), post_metrics(*), post_tags(tags(*)), profiles:profiles!posts_user_id_fkey(display_name, avatar_url, area_name), evaluations(user_id)')
        .eq('status', 'published');
    final list = response as List;
    return list.where((post) {
      final evals = post['evaluations'] as List?;
      if (evals == null || evals.isEmpty) return true;
      return !evals.any((e) => e['user_id'] == userId);
    }).toList();
  }

  static Future<void> insertEvaluation({
    required String userId,
    required String postId,
    required String? projectId,
    required String action,
    required int dwellMs,
    required bool openedDetail,
    required int supportCountAtEvaluation,
    required double supportRateAtEvaluation,
  }) async {
    await _supabase.from('evaluations').insert({
      'user_id': userId,
      'post_id': postId,
      'project_id': projectId,
      'action': action,
      'dwell_ms': dwellMs,
      'opened_detail': openedDetail,
      'source': 'swipe',
      'support_count_at_evaluation': supportCountAtEvaluation,
      'support_rate_at_evaluation': supportRateAtEvaluation,
    });
  }

  static Future<List<dynamic>> getEvaluations(String userId) async {
    return await _supabase
        .from('evaluations')
        .select('id')
        .eq('user_id', userId);
  }

  static Future<List<dynamic>> getSupportEvaluations(String userId) async {
    return await _supabase
        .from('evaluations')
        .select('id')
        .eq('user_id', userId)
        .eq('action', 'support');
  }

  static Future<List<dynamic>> getEvaluationsSince(String userId, DateTime since) async {
    return await _supabase
        .from('evaluations')
        .select('id, action, created_at')
        .eq('user_id', userId)
        .gte('created_at', since.toUtc().toIso8601String());
  }

  static Future<List<dynamic>> getEarlySupportedPosts(String userId) async {
    return await _supabase
        .from('evaluations')
        .select('*, posts(*, profiles:profiles!posts_user_id_fkey(display_name, avatar_url), post_media(*), post_metrics(*))')
        .eq('user_id', userId)
        .eq('action', 'support')
        .lte('support_count_at_evaluation', 5)
        .limit(3);
  }

  // --- Comments Section ---
  static Future<List<dynamic>> getCommentsForPost(String postId) async {
    return await _supabase
        .from('comments')
        .select('*, profiles(display_name, avatar_url, area_name)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  static Future<void> insertComment({
    required String postId,
    required String userId,
    required String body,
  }) async {
    await _supabase.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'body': body,
    });
  }

  static Future<List<dynamic>> getCommentsCount(String userId) async {
    return await _supabase
        .from('comments')
        .select('id')
        .eq('user_id', userId);
  }

  static Future<List<dynamic>> getTopReviews() async {
    return await _supabase
        .from('comments')
        .select('*, profiles(display_name, area_name), posts(title, post_metrics(support_count))')
        .order('created_at', ascending: false)
        .limit(1);
  }

  // --- AI Generation Section ---
  static Future<Map<String, dynamic>> insertAIGenerationJob({
    required String userId,
    required String? projectId,
    required String inputImageUrl,
    required List<String> selectedTagIds,
    required String prompt,
  }) async {
    return await _supabase.from('ai_generation_jobs').insert({
      'user_id': userId,
      'project_id': projectId,
      'input_image_url': inputImageUrl,
      'selected_tag_ids': selectedTagIds,
      'status': 'queued',
      'prompt': prompt,
    }).select().single();
  }

  static Future<Map<String, dynamic>> getAIGenerationJob(String jobId) async {
    return await _supabase
        .from('ai_generation_jobs')
        .select('*')
        .eq('id', jobId)
        .single();
  }

  // Invoke the server-side Edge Function that processes a queued job.
  // The function performs all OpenAI work server-side and writes the result
  // back into ai_generation_jobs, which the polling loop then picks up.
  static Future<void> invokeProcessAIGeneration(String jobId) async {
    await _supabase.functions.invoke(
      'process-ai-generation',
      body: {'job_id': jobId},
    );
  }

  // --- Badges Section ---
  static Future<List<dynamic>> getUserBadges(String userId) async {
    return await _supabase
        .from('user_badges')
        .select('*, badges(*)')
        .eq('user_id', userId);
  }

  // --- Points Section ---
  static Future<List<dynamic>> getPointsLedger(String userId) async {
    return await _supabase
        .from('points_ledger')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  // --- Rankings Section ---
  static Future<List<dynamic>> getRankings(String rankingType) async {
    return await _supabase
        .from('rankings')
        .select('*, profiles(display_name, avatar_url)')
        .eq('ranking_type', rankingType)
        .order('rank', ascending: true)
        .limit(3);
  }

  // --- Profiles Section ---
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _supabase
        .from('profiles')
        .select('*, city_types(*)')
        .eq('id', userId)
        .maybeSingle();
  }

  static Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String areaName,
    required String residentType,
  }) async {
    await _supabase.from('profiles').update({
      'display_name': displayName,
      'area_name': areaName,
      'resident_type': residentType,
    }).eq('id', userId);
  }

  static Future<List<dynamic>> getSupportedTagsForUser(String userId) async {
    return await _supabase
        .from('evaluations')
        .select('posts(post_tags(tags(title)))')
        .eq('user_id', userId)
        .eq('action', 'support');
  }

  static Future<void> deleteSavedPost({required String userId, required String postId}) async {
    await _supabase.from('saved_posts').delete().eq('user_id', userId).eq('post_id', postId);
  }

  static Future<void> insertSavedPost({required String userId, required String postId}) async {
    await _supabase.from('saved_posts').insert({'user_id': userId, 'post_id': postId});
  }
}

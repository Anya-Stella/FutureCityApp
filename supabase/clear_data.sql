-- Supabaseのすべてのデータを完全に削除し、初期状態に戻すSQLスクリプト

-- 外部キー制約を考慮し、CASCADEを指定して全テーブルをトランケート（物理削除）します。
TRUNCATE TABLE
  public.audit_logs,
  public.moderation_queue,
  public.notifications,
  public.ai_generation_jobs,
  public.rankings,
  public.city_type_results,
  public.user_badges,
  public.badges,
  public.points_ledger,
  public.point_rules,
  public.point_reason_master,
  public.project_metrics,
  public.post_metrics,
  public.comments,
  public.saved_posts,
  public.reactions,
  public.evaluations,
  public.post_tags,
  public.tags,
  public.post_media,
  public.posts,
  public.project_areas,
  public.projects,
  public.user_settings,
  public.profiles,
  public.city_types
  RESTART IDENTITY
  CASCADE;

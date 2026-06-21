-- =============================================================================
-- 0007 : Row Level Security
-- 受け入れ条件:
--   ・ユーザーは自分のプロフィールだけ編集できる
--   ・公開投稿は誰でも読める
--   ・投稿作成者だけが自分の投稿を編集できる
--   ・評価は1ユーザー1投稿につき1回（unique制約 + insert専用）
--
-- 管理操作（行政採用・モデレーション等）は Next.js 管理画面から
-- service_role キーで実行する（service_role は RLS をバイパスする）。
-- =============================================================================

-- 補助: 管理者判定（app_metadata.is_admin = true のときのみ true）
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
    false
  );
$$;

-- RLS 有効化
alter table public.city_types          enable row level security;
alter table public.profiles            enable row level security;
alter table public.user_settings       enable row level security;
alter table public.projects            enable row level security;
alter table public.project_areas       enable row level security;
alter table public.posts               enable row level security;
alter table public.post_media          enable row level security;
alter table public.tags                enable row level security;
alter table public.post_tags           enable row level security;
alter table public.evaluations         enable row level security;
alter table public.reactions           enable row level security;
alter table public.saved_posts         enable row level security;
alter table public.comments            enable row level security;
alter table public.post_metrics        enable row level security;
alter table public.project_metrics     enable row level security;
alter table public.point_reason_master enable row level security;
alter table public.point_rules         enable row level security;
alter table public.points_ledger       enable row level security;
alter table public.badges              enable row level security;
alter table public.user_badges         enable row level security;
alter table public.city_type_results   enable row level security;
alter table public.rankings            enable row level security;
alter table public.ai_generation_jobs  enable row level security;
alter table public.notifications       enable row level security;
alter table public.moderation_queue    enable row level security;
alter table public.audit_logs          enable row level security;

-- -----------------------------------------------------------------------------
-- マスタ系：誰でも読める / 書き込みは admin(service_role) のみ
-- -----------------------------------------------------------------------------
create policy "tags_read"      on public.tags          for select to anon, authenticated using (is_active);
create policy "city_types_read" on public.city_types   for select to anon, authenticated using (true);
create policy "badges_read"    on public.badges        for select to anon, authenticated using (true);
create policy "reason_read"    on public.point_reason_master for select to anon, authenticated using (true);
create policy "rules_read"     on public.point_rules   for select to anon, authenticated using (true);
create policy "projects_read"  on public.projects      for select to anon, authenticated using (true);
create policy "project_areas_read" on public.project_areas for select to anon, authenticated using (true);
create policy "project_metrics_read" on public.project_metrics for select to anon, authenticated using (true);
create policy "rankings_read"  on public.rankings      for select to anon, authenticated using (true);
create policy "user_badges_read" on public.user_badges for select to anon, authenticated using (true);

-- -----------------------------------------------------------------------------
-- profiles : 公開プロフィール or 自分は読める / 編集は自分のみ
-- -----------------------------------------------------------------------------
create policy "profiles_read" on public.profiles
  for select to anon, authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.user_settings s
      where s.user_id = profiles.id and s.is_profile_public
    )
  );

create policy "profiles_insert_self" on public.profiles
  for insert to authenticated with check (id = auth.uid());

create policy "profiles_update_self" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- -----------------------------------------------------------------------------
-- user_settings : 自分のみ
-- -----------------------------------------------------------------------------
create policy "settings_read_self"   on public.user_settings
  for select to authenticated using (user_id = auth.uid());
create policy "settings_insert_self" on public.user_settings
  for insert to authenticated with check (user_id = auth.uid());
create policy "settings_update_self" on public.user_settings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- posts : 公開かつ published は誰でも読める / 自分の投稿は常に読める
--         作成・編集・削除は本人のみ
-- -----------------------------------------------------------------------------
create policy "posts_read" on public.posts
  for select to anon, authenticated
  using (
    (status = 'published' and visibility = 'public')
    or user_id = auth.uid()
  );

create policy "posts_insert_self" on public.posts
  for insert to authenticated with check (user_id = auth.uid());

create policy "posts_update_self" on public.posts
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "posts_delete_self" on public.posts
  for delete to authenticated using (user_id = auth.uid());

-- 投稿に紐づく子テーブルの可読判定
create or replace function public.app_can_read_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.posts p
    where p.id = p_post_id
      and ((p.status = 'published' and p.visibility = 'public') or p.user_id = auth.uid())
  );
$$;

create or replace function public.app_owns_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.posts p where p.id = p_post_id and p.user_id = auth.uid());
$$;

-- -----------------------------------------------------------------------------
-- post_media / post_tags : 投稿が読めれば読める / 書き込みは投稿の所有者
-- -----------------------------------------------------------------------------
create policy "post_media_read"   on public.post_media
  for select to anon, authenticated using (public.app_can_read_post(post_id));
create policy "post_media_write"  on public.post_media
  for all to authenticated using (public.app_owns_post(post_id)) with check (public.app_owns_post(post_id));

create policy "post_tags_read"    on public.post_tags
  for select to anon, authenticated using (public.app_can_read_post(post_id));
create policy "post_tags_write"   on public.post_tags
  for all to authenticated using (public.app_owns_post(post_id)) with check (public.app_owns_post(post_id));

-- -----------------------------------------------------------------------------
-- post_metrics : 誰でも読める（集計は trigger / service_role が更新）
-- -----------------------------------------------------------------------------
create policy "post_metrics_read" on public.post_metrics
  for select to anon, authenticated using (true);

-- -----------------------------------------------------------------------------
-- evaluations : 自分の評価のみ読める / 追加のみ（更新・削除不可）
-- -----------------------------------------------------------------------------
create policy "evaluations_read_self" on public.evaluations
  for select to authenticated using (user_id = auth.uid());
create policy "evaluations_insert_self" on public.evaluations
  for insert to authenticated with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- reactions / saved_posts : 自分のもの
-- -----------------------------------------------------------------------------
create policy "reactions_read_self"   on public.reactions
  for select to authenticated using (user_id = auth.uid());
create policy "reactions_write_self"  on public.reactions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "saved_read_self"   on public.saved_posts
  for select to authenticated using (user_id = auth.uid());
create policy "saved_write_self"  on public.saved_posts
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- comments : 公開コメントは誰でも読める / 投稿・編集・削除は本人
-- -----------------------------------------------------------------------------
create policy "comments_read" on public.comments
  for select to anon, authenticated
  using (status = 'published' or user_id = auth.uid());
create policy "comments_insert_self" on public.comments
  for insert to authenticated with check (user_id = auth.uid());
create policy "comments_update_self" on public.comments
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "comments_delete_self" on public.comments
  for delete to authenticated using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- points_ledger : 自分の履歴のみ読める（追加は definer 関数経由のみ）
-- -----------------------------------------------------------------------------
create policy "points_read_self" on public.points_ledger
  for select to authenticated using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- city_type_results : 自分のみ
-- -----------------------------------------------------------------------------
create policy "city_result_read_self"   on public.city_type_results
  for select to authenticated using (user_id = auth.uid());
create policy "city_result_write_self"  on public.city_type_results
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- ai_generation_jobs : 自分のジョブのみ
-- -----------------------------------------------------------------------------
create policy "ai_jobs_read_self"   on public.ai_generation_jobs
  for select to authenticated using (user_id = auth.uid());
create policy "ai_jobs_write_self"  on public.ai_generation_jobs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- notifications : 自分宛 or 全体お知らせ / 既読更新は自分宛のみ
-- -----------------------------------------------------------------------------
create policy "notifications_read" on public.notifications
  for select to authenticated using (user_id = auth.uid() or user_id is null);
create policy "notifications_update_self" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- moderation_queue : 通報の作成は認証ユーザー可 / 閲覧は admin のみ
-- -----------------------------------------------------------------------------
create policy "moderation_insert" on public.moderation_queue
  for insert to authenticated with check (true);
create policy "moderation_admin_read" on public.moderation_queue
  for select to authenticated using (public.is_admin());

-- -----------------------------------------------------------------------------
-- audit_logs : admin のみ閲覧（書き込みは service_role）
-- -----------------------------------------------------------------------------
create policy "audit_admin_read" on public.audit_logs
  for select to authenticated using (public.is_admin());

-- user_badges 付与・badges/projects 等の書き込みは service_role（RLSバイパス）。
-- そのため明示的な insert/update ポリシーは作らない＝認証ユーザーからは不可。

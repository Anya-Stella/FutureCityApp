-- =============================================================================
-- 0005 : System tables
-- ai_generation_jobs / notifications / moderation_queue / audit_logs
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ai_generation_jobs : AI画像生成ジョブ（queued / running / succeeded / failed）
-- -----------------------------------------------------------------------------
create table public.ai_generation_jobs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  project_id       uuid references public.projects(id) on delete set null,
  input_image_url  text,
  selected_tag_ids uuid[] not null default '{}',
  prompt           text,
  model            text,
  status           text not null default 'queued',  -- queued | running | succeeded | failed
  output_image_url text,
  error_message    text,
  created_at       timestamptz not null default now(),
  completed_at     timestamptz,
  constraint ai_jobs_status_check
    check (status in ('queued','running','succeeded','failed'))
);

-- -----------------------------------------------------------------------------
-- notifications : お知らせ/通知
-- -----------------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete cascade,  -- null = 全体お知らせ
  project_id uuid references public.projects(id) on delete set null,
  type       text not null,                         -- system | point | selection | comment ...
  title      text not null,
  body       text,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- moderation_queue : 通報/モデレーション待ち
-- -----------------------------------------------------------------------------
create table public.moderation_queue (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null,                         -- post | comment | profile
  target_id   uuid not null,
  reason      text,
  severity    text,                                  -- low | mid | high
  status      text not null default 'pending',       -- pending | reviewing | resolved | dismissed
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at  timestamptz not null default now(),
  constraint moderation_status_check
    check (status in ('pending','reviewing','resolved','dismissed'))
);

-- -----------------------------------------------------------------------------
-- audit_logs : 監査ログ（管理操作の記録）
-- -----------------------------------------------------------------------------
create table public.audit_logs (
  id            uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  action        text not null,
  target_type   text,
  target_id     uuid,
  metadata      jsonb not null default '{}',
  created_at    timestamptz not null default now()
);

-- =============================================================================
-- Indexes（読み取りが多い列）
-- =============================================================================
create index idx_posts_status_published   on public.posts (status, published_at desc);
create index idx_posts_user               on public.posts (user_id);
create index idx_posts_project             on public.posts (project_id);
create index idx_posts_selection           on public.posts (selection_status);
create index idx_posts_location            on public.posts using gist (location);

create index idx_post_media_post           on public.post_media (post_id);
create index idx_post_tags_tag             on public.post_tags (tag_id);

create index idx_evaluations_post          on public.evaluations (post_id);
create index idx_evaluations_user_created  on public.evaluations (user_id, created_at desc);
create index idx_evaluations_project       on public.evaluations (project_id);

create index idx_comments_post             on public.comments (post_id, created_at desc);
create index idx_reactions_post            on public.reactions (post_id);
create index idx_saved_posts_user          on public.saved_posts (user_id);

create index idx_points_ledger_user        on public.points_ledger (user_id, created_at desc);
create index idx_points_ledger_reason      on public.points_ledger (reason_code);

create index idx_rankings_lookup           on public.rankings (ranking_type, period, rank);
create index idx_ai_jobs_user              on public.ai_generation_jobs (user_id, created_at desc);
create index idx_notifications_user        on public.notifications (user_id, is_read, created_at desc);
create index idx_project_areas_polygon     on public.project_areas using gist (polygon);

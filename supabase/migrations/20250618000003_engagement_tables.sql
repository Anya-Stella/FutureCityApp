-- =============================================================================
-- 0003 : Engagement tables
-- evaluations / reactions / saved_posts / comments /
-- post_metrics / project_metrics
-- =============================================================================

-- -----------------------------------------------------------------------------
-- evaluations : フリック評価（support / skip）
--   ・1ユーザー1投稿につき1回（unique）
--   ・support_count_at_evaluation は早期発掘判定に使用
-- -----------------------------------------------------------------------------
create table public.evaluations (
  id                         uuid primary key default gen_random_uuid(),
  user_id                    uuid not null references public.profiles(id) on delete cascade,
  post_id                    uuid not null references public.posts(id)    on delete cascade,
  project_id                 uuid references public.projects(id) on delete set null,
  action                     text not null,                    -- support | skip
  dwell_ms                   int  not null default 0,
  opened_detail              boolean not null default false,
  source                     text not null default 'swipe',    -- swipe | detail
  support_count_at_evaluation int not null default 0,
  support_rate_at_evaluation  numeric not null default 0,
  created_at                 timestamptz not null default now(),
  constraint evaluations_action_check check (action in ('support','skip')),
  unique (user_id, post_id)
);

-- -----------------------------------------------------------------------------
-- reactions : 投稿詳細でのリアクション
-- -----------------------------------------------------------------------------
create table public.reactions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id)    on delete cascade,
  type       text not null,                              -- like | save | strong_support
  created_at timestamptz not null default now(),
  constraint reactions_type_check check (type in ('like','save','strong_support')),
  unique (user_id, post_id, type)
);

-- -----------------------------------------------------------------------------
-- saved_posts : 保存投稿
-- -----------------------------------------------------------------------------
create table public.saved_posts (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id)    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

-- -----------------------------------------------------------------------------
-- comments : コメント
-- -----------------------------------------------------------------------------
create table public.comments (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  post_id          uuid not null references public.posts(id)    on delete cascade,
  body             text not null,
  sentiment        text,                                  -- positive | neutral | negative (任意)
  extracted_topics text[] not null default '{}',
  status           text not null default 'published',     -- published | hidden | removed
  created_at       timestamptz not null default now(),
  constraint comments_status_check check (status in ('published','hidden','removed'))
);

-- -----------------------------------------------------------------------------
-- post_metrics : 投稿集計キャッシュ（トリガで更新）
-- -----------------------------------------------------------------------------
create table public.post_metrics (
  post_id       uuid primary key references public.posts(id) on delete cascade,
  support_count int not null default 0,
  skip_count    int not null default 0,
  support_rate  numeric not null default 0,    -- support / (support + skip)
  comment_count int not null default 0,
  save_count    int not null default 0,
  avg_dwell_ms  int not null default 0,
  score         numeric not null default 0,
  updated_at    timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- project_metrics : プロジェクト集計キャッシュ
-- -----------------------------------------------------------------------------
create table public.project_metrics (
  project_id        uuid primary key references public.projects(id) on delete cascade,
  post_count        int not null default 0,
  evaluation_count  int not null default 0,
  comment_count     int not null default 0,
  participant_count int not null default 0,
  avg_support_rate  numeric not null default 0,
  top_tags          jsonb not null default '{}',
  updated_at        timestamptz not null default now()
);

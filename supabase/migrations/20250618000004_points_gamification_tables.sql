-- =============================================================================
-- 0004 : Points & gamification tables
-- point_reason_master / point_rules / points_ledger /
-- badges / user_badges / city_type_results / rankings
--
-- ポイント設計の原則（仕様より）:
--   ・過去のポイント履歴は編集しない（修正はマイナス履歴を追加）
--   ・reason は削除せず is_active=false で無効化する
--   ・profiles.total_points は points_ledger 合計のキャッシュ
-- =============================================================================

-- -----------------------------------------------------------------------------
-- point_reason_master : ポイント付与理由のマスタ
-- -----------------------------------------------------------------------------
create table public.point_reason_master (
  reason_code    text primary key,
  title          text not null,
  description    text,
  category       text,                         -- onboarding | activity | reward | adjustment ...
  default_amount int not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- point_rules : ポイント付与ルール（しきい値+金額）
-- -----------------------------------------------------------------------------
create table public.point_rules (
  id             uuid primary key default gen_random_uuid(),
  reason_code    text not null references public.point_reason_master(reason_code),
  threshold_type text,                          -- support_count | evaluation_count ...
  threshold_value numeric,
  amount         int not null,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- points_ledger : ポイント履歴（追記専用）
--   ・unique_key で二重付与を防止
-- -----------------------------------------------------------------------------
create table public.points_ledger (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.profiles(id) on delete cascade,
  amount               int not null,
  reason_code          text not null references public.point_reason_master(reason_code),
  reason_label_snapshot text,
  related_post_id      uuid references public.posts(id)    on delete set null,
  related_project_id   uuid references public.projects(id) on delete set null,
  unique_key           text unique,
  metadata             jsonb not null default '{}',
  expires_at           timestamptz,
  created_at           timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- badges : 獲得バッジのマスタ
-- -----------------------------------------------------------------------------
create table public.badges (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  icon_url        text,
  condition_type  text,                         -- post_count | early_eval_count ...
  condition_value int,
  created_at      timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- user_badges : ユーザー×バッジ
-- -----------------------------------------------------------------------------
create table public.user_badges (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  badge_id  uuid not null references public.badges(id)   on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- -----------------------------------------------------------------------------
-- city_type_results : 街タイプ診断の結果
-- -----------------------------------------------------------------------------
create table public.city_type_results (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id)    on delete cascade,
  city_type_id  uuid not null references public.city_types(id)  on delete cascade,
  score_json    jsonb not null default '{}',
  calculated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- rankings : シーズン/種別ごとのランキング（バッチ or View で更新）
-- -----------------------------------------------------------------------------
create table public.rankings (
  id            uuid primary key default gen_random_uuid(),
  ranking_type  text not null,                  -- early_discoverer | supporter | creator | reviewer | contributor
  project_id    uuid references public.projects(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  score         numeric not null default 0,
  rank          int,
  period        text,                           -- season id / week label など
  calculated_at timestamptz not null default now(),
  constraint rankings_type_check
    check (ranking_type in ('early_discoverer','supporter','creator','reviewer','contributor'))
);

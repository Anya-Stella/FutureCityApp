-- =============================================================================
-- 0002 : Core tables
-- city_types / profiles / user_settings / projects / project_areas /
-- posts / post_media / tags / post_tags
--
-- 注: profiles.id は Supabase Auth の auth.users.id を参照する。
--     ログイン後にプロフィールが無ければ handle_new_user トリガ(0006)で自動作成。
-- =============================================================================

-- -----------------------------------------------------------------------------
-- city_types : 街タイプ（診断結果のマスタ）
--   profiles.city_type_id から参照されるため先に作成する
-- -----------------------------------------------------------------------------
create table public.city_types (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  icon_url      text,
  description   text,
  main_tag_ids  uuid[] not null default '{}',
  created_at    timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- profiles : ユーザー基本情報
-- -----------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar_url    text,
  area_name     text,
  resident_type text,
  level         int  not null default 1,
  city_type_id  uuid references public.city_types(id) on delete set null,
  total_points  int  not null default 0,   -- points_ledger 合計のキャッシュ
  trust_score   int  not null default 50,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- user_settings : 通知/プライバシー設定
-- -----------------------------------------------------------------------------
create table public.user_settings (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null unique references public.profiles(id) on delete cascade,
  is_profile_public boolean not null default true,
  allow_push        boolean not null default true,
  allow_email       boolean not null default false,
  theme             text    not null default 'system',  -- system | light | dark
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- projects : 行政等が出す募集テーマ
-- -----------------------------------------------------------------------------
create table public.projects (
  id               uuid primary key default gen_random_uuid(),
  owner_type       text not null default 'admin',   -- admin | gov | partner
  owner_name       text,
  title            text not null,
  description      text,
  cover_image_url  text,
  status           text not null default 'active',  -- active | closed | draft
  starts_at        timestamptz,
  ends_at          timestamptz,
  reward_points    int  not null default 0,
  target_area_name text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- project_areas : プロジェクトの対象エリア（PostGIS polygon）
-- -----------------------------------------------------------------------------
create table public.project_areas (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects(id) on delete cascade,
  name        text,
  polygon     geometry(Polygon, 4326),
  center_lat  numeric,
  center_lng  numeric,
  created_at  timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- posts : 市民の投稿（アイデア）
-- -----------------------------------------------------------------------------
create table public.posts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  project_id       uuid references public.projects(id) on delete set null,
  title            text,
  body             text,
  location         geography(Point, 4326),
  address_text     text,
  status           text not null default 'pending',   -- pending | published | hidden | removed
  visibility       text not null default 'public',    -- public | private
  selection_status text not null default 'none',      -- none | candidate | selected | rejected
  selected_by      uuid references public.profiles(id) on delete set null,
  selected_at      timestamptz,
  published_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint posts_status_check
    check (status in ('pending','published','hidden','removed')),
  constraint posts_selection_status_check
    check (selection_status in ('none','candidate','selected','rejected'))
);

-- -----------------------------------------------------------------------------
-- post_media : 投稿画像（before / generated）
-- -----------------------------------------------------------------------------
create table public.post_media (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts(id) on delete cascade,
  media_type   text not null,                    -- before | generated
  url          text not null,
  width        int,
  height       int,
  blur_applied boolean not null default false,
  created_at   timestamptz not null default now(),
  constraint post_media_type_check check (media_type in ('before','generated'))
);

-- -----------------------------------------------------------------------------
-- tags : 施策タグ（緑化/ベンチ ...）
-- -----------------------------------------------------------------------------
create table public.tags (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  category    text,
  icon_url    text,
  description text,
  is_active   boolean not null default true
);

-- -----------------------------------------------------------------------------
-- post_tags : 投稿×タグ
-- -----------------------------------------------------------------------------
create table public.post_tags (
  post_id uuid not null references public.posts(id) on delete cascade,
  tag_id  uuid not null references public.tags(id)  on delete cascade,
  primary key (post_id, tag_id)
);

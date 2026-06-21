-- =============================================================================
-- 0006 : Functions & triggers
-- updated_at / プロフィール自動作成 / ポイント付与 / 集計キャッシュ /
-- 早期発掘・高評価・行政採用ボーナス / 1日10件の評価制限
--
-- すべて SECURITY DEFINER（owner権限で実行）。他ユーザーのポイント付与や
-- 集計キャッシュ更新を行うため RLS をバイパスする必要がある。
-- =============================================================================

-- -----------------------------------------------------------------------------
-- updated_at 自動更新
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_profiles_updated  before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_user_settings_updated before update on public.user_settings
  for each row execute function public.set_updated_at();
create trigger trg_projects_updated  before update on public.projects
  for each row execute function public.set_updated_at();
create trigger trg_posts_updated     before update on public.posts
  for each row execute function public.set_updated_at();
create trigger trg_reason_master_updated before update on public.point_reason_master
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 新規ユーザー → profiles / user_settings を自動作成
--   ログイン後にプロフィールが無ければ作成する仕様を Auth トリガで担保
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name',
             new.raw_user_meta_data ->> 'full_name',
             split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  -- 初回登録ボーナス
  perform public.app_award_points(
    new.id, 'signup_bonus', null, null, 'signup:' || new.id::text, null, '{}'::jsonb
  );

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- ポイント金額の解決：point_rules（有効・最新） → master.default_amount → 0
-- -----------------------------------------------------------------------------
create or replace function public.app_point_amount(p_reason_code text)
returns int
language sql
stable
as $$
  select coalesce(
    (select amount from public.point_rules
       where reason_code = p_reason_code and is_active
       order by created_at desc limit 1),
    (select default_amount from public.point_reason_master
       where reason_code = p_reason_code),
    0
  );
$$;

-- -----------------------------------------------------------------------------
-- ポイント付与（追記専用 / unique_key で二重付与防止）
--   p_amount を渡さなければ app_point_amount で解決する
-- -----------------------------------------------------------------------------
create or replace function public.app_award_points(
  p_user_id    uuid,
  p_reason_code text,
  p_amount     int  default null,
  p_post_id    uuid default null,
  p_unique_key text default null,
  p_project_id uuid default null,
  p_metadata   jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount int;
  v_label  text;
  v_id     uuid;
begin
  -- 無効化された reason には付与しない
  if not exists (select 1 from public.point_reason_master
                 where reason_code = p_reason_code and is_active) then
    return null;
  end if;

  v_amount := coalesce(p_amount, public.app_point_amount(p_reason_code));
  select title into v_label from public.point_reason_master where reason_code = p_reason_code;

  insert into public.points_ledger (
    user_id, amount, reason_code, reason_label_snapshot,
    related_post_id, related_project_id, unique_key, metadata
  )
  values (
    p_user_id, v_amount, p_reason_code, v_label,
    p_post_id, p_project_id, p_unique_key, coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (unique_key) do nothing
  returning id into v_id;

  return v_id;  -- 二重付与時は null
end;
$$;

-- -----------------------------------------------------------------------------
-- profiles.total_points を points_ledger 合計のキャッシュとして維持
-- -----------------------------------------------------------------------------
create or replace function public.app_sync_total_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set total_points = total_points + new.amount,
         updated_at   = now()
   where id = new.user_id;
  return new;
end;
$$;

create trigger trg_points_ledger_sync
  after insert on public.points_ledger
  for each row execute function public.app_sync_total_points();

-- -----------------------------------------------------------------------------
-- 投稿集計キャッシュの再計算 + ボーナス判定
-- -----------------------------------------------------------------------------
create or replace function public.app_refresh_post_metrics(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_support int;
  v_skip    int;
  v_rate    numeric;
  v_comment int;
  v_save    int;
  v_dwell   int;
  v_score   numeric;
  v_author  uuid;
  r record;
begin
  select count(*) filter (where action = 'support'),
         count(*) filter (where action = 'skip'),
         coalesce(avg(dwell_ms), 0)::int
    into v_support, v_skip, v_dwell
    from public.evaluations where post_id = p_post_id;

  select count(*) into v_comment from public.comments
    where post_id = p_post_id and status = 'published';

  select count(*) into v_save from public.saved_posts where post_id = p_post_id;

  v_rate := case when (v_support + v_skip) > 0
                 then round(v_support::numeric / (v_support + v_skip), 4)
                 else 0 end;
  -- 単純スコア：支持数の重み + 支持率
  v_score := v_support * 1.0 + v_rate * 10 + v_comment * 0.5;

  insert into public.post_metrics (
    post_id, support_count, skip_count, support_rate,
    comment_count, save_count, avg_dwell_ms, score, updated_at
  )
  values (p_post_id, v_support, v_skip, v_rate, v_comment, v_save, v_dwell, v_score, now())
  on conflict (post_id) do update set
    support_count = excluded.support_count,
    skip_count    = excluded.skip_count,
    support_rate  = excluded.support_rate,
    comment_count = excluded.comment_count,
    save_count    = excluded.save_count,
    avg_dwell_ms  = excluded.avg_dwell_ms,
    score         = excluded.score,
    updated_at    = now();

  -- ===== 高評価ボーナス & 早期発掘者ボーナス（support_count が閾値到達時）=====
  if v_support >= 100 then
    select user_id into v_author from public.posts where id = p_post_id;

    -- 高評価ボーナス：投稿者へ1回のみ
    if v_author is not null then
      perform public.app_award_points(
        v_author, 'post_high_support', null, p_post_id,
        'high_support:' || p_post_id::text, null, '{}'::jsonb
      );
    end if;

    -- 早期発掘者：応援時点で support_count < 10 だったユーザーへ1回のみ
    for r in
      select user_id from public.evaluations
       where post_id = p_post_id
         and action = 'support'
         and support_count_at_evaluation < 10
    loop
      perform public.app_award_points(
        r.user_id, 'early_evaluation', null, p_post_id,
        'early:' || p_post_id::text || ':' || r.user_id::text, null, '{}'::jsonb
      );
    end loop;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 評価の事前チェック：1日10件まで / 評価時点の支持数を記録
-- -----------------------------------------------------------------------------
create or replace function public.app_before_evaluation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_count int;
  v_support     int;
  v_skip        int;
begin
  -- 1日10件制限（UTC日付基準）
  select count(*) into v_today_count
    from public.evaluations
   where user_id = new.user_id
     and created_at >= date_trunc('day', now());
  if v_today_count >= 10 then
    raise exception 'daily evaluation limit reached (10/day)'
      using errcode = 'check_violation';
  end if;

  -- 評価時点の支持数/支持率をスナップショット
  select support_count, skip_count into v_support, v_skip
    from public.post_metrics where post_id = new.post_id;
  v_support := coalesce(v_support, 0);
  v_skip    := coalesce(v_skip, 0);

  new.support_count_at_evaluation := v_support;
  new.support_rate_at_evaluation  :=
    case when (v_support + v_skip) > 0
         then round(v_support::numeric / (v_support + v_skip), 4) else 0 end;
  return new;
end;
$$;

create trigger trg_evaluations_before
  before insert on public.evaluations
  for each row execute function public.app_before_evaluation();

-- -----------------------------------------------------------------------------
-- 評価の事後処理：metrics更新 + 1日10件完了で daily_evaluation_completed 付与
-- -----------------------------------------------------------------------------
create or replace function public.app_after_evaluation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_count int;
begin
  perform public.app_refresh_post_metrics(new.post_id);

  select count(*) into v_today_count
    from public.evaluations
   where user_id = new.user_id
     and created_at >= date_trunc('day', now());

  if v_today_count >= 10 then
    perform public.app_award_points(
      new.user_id, 'daily_evaluation_completed', null, null,
      'daily_eval:' || new.user_id::text || ':' || to_char(now(), 'YYYY-MM-DD'),
      null, '{}'::jsonb
    );
  end if;
  return new;
end;
$$;

create trigger trg_evaluations_after
  after insert on public.evaluations
  for each row execute function public.app_after_evaluation();

-- -----------------------------------------------------------------------------
-- コメント / 保存 / リアクション → metrics 再計算
-- -----------------------------------------------------------------------------
create or replace function public.app_touch_post_metrics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post uuid;
begin
  v_post := coalesce(new.post_id, old.post_id);
  perform public.app_refresh_post_metrics(v_post);

  -- コメント作成時のポイント（公開コメントのみ・INSERT時）
  if tg_table_name = 'comments' and tg_op = 'INSERT'
     and new.status = 'published' then
    perform public.app_award_points(
      new.user_id, 'comment_created', null, new.post_id,
      'comment:' || new.id::text, null, '{}'::jsonb
    );
  end if;
  return coalesce(new, old);
end;
$$;

create trigger trg_comments_metrics
  after insert or update or delete on public.comments
  for each row execute function public.app_touch_post_metrics();
create trigger trg_saved_posts_metrics
  after insert or delete on public.saved_posts
  for each row execute function public.app_touch_post_metrics();

-- -----------------------------------------------------------------------------
-- 投稿公開時 → post_created 付与
-- -----------------------------------------------------------------------------
create or replace function public.app_after_post_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- published になった瞬間（INSERT で published / UPDATE で pending→published）
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    -- post_metrics 行を用意
    insert into public.post_metrics (post_id) values (new.id)
      on conflict (post_id) do nothing;

    perform public.app_award_points(
      new.user_id, 'post_created', null, new.id,
      'post_created:' || new.id::text, new.project_id, '{}'::jsonb
    );
  end if;

  -- 行政採用ボーナス：selection_status が selected になったら投稿者へ
  if new.selection_status = 'selected'
     and (tg_op = 'INSERT' or old.selection_status is distinct from 'selected') then
    perform public.app_award_points(
      new.user_id, 'post_selected_by_admin', null, new.id,
      'selected:' || new.id::text, new.project_id, '{}'::jsonb
    );
  end if;

  return new;
end;
$$;

create trigger trg_posts_after
  after insert or update on public.posts
  for each row execute function public.app_after_post_change();

-- -----------------------------------------------------------------------------
-- ランキング（シーズン中のポイント）を返す View
--   フィードバック画面の総合貢献ランキングに使用
-- -----------------------------------------------------------------------------
create or replace view public.season_point_rankings as
select
  pl.user_id,
  p.display_name,
  p.avatar_url,
  sum(pl.amount) as season_points,
  rank() over (order by sum(pl.amount) desc) as rank
from public.points_ledger pl
join public.profiles p on p.id = pl.user_id
group by pl.user_id, p.display_name, p.avatar_url;

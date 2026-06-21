-- =============================================================================
-- 0001 : Extensions
-- Future City MVP — 必要な PostgreSQL 拡張を有効化する
-- =============================================================================

-- gen_random_uuid() / 暗号系
create extension if not exists "pgcrypto";

-- 位置情報（posts.location geography / project_areas.polygon geometry）
create extension if not exists "postgis";

-- 全文検索・あいまい検索を将来使う余地（タグ/コメント解析）
create extension if not exists "pg_trgm";

# Supabase 構築・接続セットアップガイド (supabase_setup.md)

本ドキュメントは、`FutureCityApp` プロジェクトを本番/開発環境の Supabase に接続し、データベースとストレージの初期構築を行うための手順書です。

---

## 1. データベース構築手順 (CLIを用いたデプロイ)

### ① Supabase CLIのログインとリンク
ターミナルで `FutureCityApp` ディレクトリへ移動し、以下のコマンドを実行して Supabase アカウントにログインおよびプロジェクトとのリンクを行います。

```bash
# Supabaseアカウントへのログイン
supabase login

# プロジェクトとのリンク (Project Ref は Supabase ダッシュボードの Settings > General から取得可能)
supabase link --project-ref <YOUR_PROJECT_REF>
```

### ② スキーマのデプロイ (Migrations)
`supabase/migrations/` ディレクトリ内に定義されたマイグレーションファイルをリモートデータベースに反映します。

```bash
supabase db push
```

### ③ デモデータの投入 (Seeding)
初期マスターデータ（タグ、バッジ、診断タイプ、ポイント付与ルール）およびデモユーザーを投入します。
リモートデータベースに `seed.sql` の内容を実行するには、**Supabase ダッシュボードの SQL Editor** に `supabase/seed.sql` の中身をコピー＆ペーストして実行するか、以下のコマンドを実行します。

```bash
# パスワード入力が必要な場合があります
psql "postgresql://postgres:<YOUR_DB_PASSWORD>@db.<YOUR_PROJECT_REF>.supabase.co:5432/postgres" -f supabase/seed.sql
```

---

## 2. ストレージ（Storage Buckets）の作成とセキュリティ (RLS)

ダッシュボードの **Storage** 画面から以下の3つのバケットを作成し、それぞれ RLS ポリシー（Policies）を設定します。

### ① `challenges` バケット (チャレンジ画像用)
- **公開設定**: Public (公開バケット)
- **RLSポリシー**:
  - **閲覧 (SELECT)**: すべてのユーザー (Public) に許可
    ```sql
    true
    ```
  - **書き込み (INSERT/UPDATE/DELETE)**: 管理者のみ (`service_role` または特定ロール) に制限
    - ※ 一般ユーザーからの書き込みポリシーは作成しません。

### ② `posts` バケット (投稿before画像用)
- **公開設定**: Public (公開バケット)
- **RLSポリシー**:
  - **閲覧 (SELECT)**: すべてのユーザー (Public) に許可
    ```sql
    true
    ```
  - **書き込み (INSERT)**: 認証済みユーザーのみ許可
    ```sql
    auth.role() = 'authenticated'
    ```

### ③ `ai-generations` バケット (AI生成画像用)
- **公開設定**: Public (公開バケット、URLでの画像読み込みを容易にするため)
- **RLSポリシー**:
  - **閲覧 (SELECT)**: すべてのユーザーに許可
    ```sql
    true
    ```
  - **書き込み (INSERT/ALL)**: 認証済みの本人のみ許可
    ```sql
    auth.uid() = owner_id
    ```

---

## 3. アプリ内の接続情報設定

Flutter アプリが作成した Supabase プロジェクトと接続できるように、以下のファイルをご自身の環境に合わせて書き換えてください。

ファイルパス: [lib/config.dart](file:///Users/tsubasaishihara/DEV/OpenVista/FUTURECITY/FutureCityApp/lib/config.dart)

```dart
class SupabaseConfig {
  SupabaseConfig._();

  // あなたの Supabase API URL (Settings > API)
  static const String url = 'https://<YOUR_PROJECT_REF>.supabase.co';

  // あなたの Anon Key (Settings > API)
  static const String anonKey = '<YOUR_SUPABASE_ANON_KEY>';
}
```

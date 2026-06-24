# Issue #1 — Image Generation: Changed Files

This documents every file added or edited for the server-side AI image
generation flow, and why.

## Design summary

The existing `ai_generation_jobs` flow is preserved. Flutter inserts a `queued`
job, invokes a new Supabase Edge Function, then polls `getAIGenerationJob` and
displays `output_image_url` when the job succeeds (falling back on failure /
timeout). OpenAI is **only** called server-side from the Edge Function.

## New files

### `supabase/functions/process-ai-generation/index.ts`
The Edge Function (Deno). Accepts `{ job_id }`, validates the job, marks it
`running` after authenticated ownership and queued-state checks, resolves tags,
extracts the free prompt from the raw job prompt, synthesizes a weighted prompt
with an OpenAI chat model, validates/fetches the source image URL, calls the
OpenAI **Images edit** endpoint with the source image,
decodes the returned `b64_json`, uploads the PNG to the `ai-generations` Storage
bucket, and writes `output_image_url` + `status=succeeded` (or `failed`) back to
`ai_generation_jobs`. Location fixed to 皇居. Image edit defaults are now
`size=1536x1024` and `quality=medium`, overridable via `OPENAI_IMAGE_SIZE` /
`OPENAI_IMAGE_QUALITY`. Prompt synthesis explicitly asks for realistic photo /
high-quality architectural visualization output and forbids illustration,
anime, watercolor, concept sketch, cartoon, labels, text, icons, and UI elements.
CORS handled for Flutter web. See
`supabase/functions/process-ai-generation/README.md` for full details.

### `supabase/functions/process-ai-generation/README.md`
Explains what the Edge Function does, its env vars, the flow, input-image
normalization, and failure behavior. Notes that no deploy / secrets / bucket
commands are executed by this change.

### `docs/issue-1-image-generation-changes.md`
This file.

## Edited files

### `lib/services/supabase_service.dart`
- **Added** `invokeProcessAIGeneration(String jobId)` in the AI Generation
  section. It calls `_supabase.functions.invoke('process-ai-generation', body:
  { 'job_id': jobId })`.
- **Why:** Flutter needs a way to trigger the server-side worker after inserting
  a job, without calling OpenAI itself.
- `insertAIGenerationJob` and `getAIGenerationJob` are **unchanged**.

### `lib/screens/create_screen.dart`
All changes are inside `_triggerAIGeneration()` (plus one new constant). UI
structure and `_submitPost()` are untouched.
- **Added** `_fixedLocation = '皇居'` constant.
- **Added** an early validation: if no tags are selected **and** the trimmed
  free prompt is empty, show a SnackBar and return without starting generation.
- **Changed** the job `prompt` string to encode the fixed location (皇居), the
  selected tags, and the user's free request as raw job input. (Final weighted
  prompt synthesis happens server-side.)
- **Added** a fire-and-forget call to
  `SupabaseService.invokeProcessAIGeneration(jobId)` right after the job is
  inserted, so Flutter starts polling immediately while the Edge Function works
  server-side. Invoke failures are logged with `debugPrint`.
- **Changed** the polling timeout from 8 checks (~16s) to 40 checks (~80s),
  keeping the existing 2-second polling interval and UI structure.
- **Why:** trigger server-side processing, enforce minimal input, allow enough
  time for OpenAI image edit + Storage upload + DB update, and fix the location
  to 皇居, while preserving the existing polling structure and
  `generatedImageUrl` display.

## Explicitly NOT changed
- `_submitPost()` and `posts` / `post_media` / `post_tags` handling
  (`insertPost`, `insertPostMedia`, `insertPostTags`).
- UI layout / structure.
- No API keys or secrets hardcoded. No deploy / `supabase secrets set` /
  bucket creation / push / commit performed.

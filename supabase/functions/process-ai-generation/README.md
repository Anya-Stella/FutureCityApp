# Edge Function: process-ai-generation

Server-side worker for the existing `ai_generation_jobs` flow. It performs all
OpenAI work **server-side** — Flutter never calls OpenAI directly.

## What it does

1. Receives authenticated `POST` with JSON body `{ "job_id": "<uuid>" }`.
2. Validates the caller JWT and confirms the job belongs to that user.
3. Loads the job row from `ai_generation_jobs` by id and validates it exists and
   is still `queued`.
4. Atomically claims the job by updating `status` from `queued` to `running`.
5. Reads `input_image_url`, `prompt`, `selected_tag_ids`, `user_id`, `project_id`.
6. Resolves tag titles from the `tags` table for `selected_tag_ids` (used as
   supporting structured elements).
7. Extracts the free prompt from the raw job prompt and synthesizes a concise,
   visual English image-edit prompt server-side using an
   OpenAI chat model. Weighting is treated as **design priority, not a numeric
   formula**:
   - user free prompt → most important (~60)
   - selected tags → supporting elements (~30)
   - fixed place context → low-priority background framing (~10)
8. Normalizes and validates the source image URL (https only, allowed hosts,
   manual redirect validation before following, supported image content type,
   size cap) and fetches it.
9. Calls the OpenAI **Images edit** endpoint (`/v1/images/edits`,
   `multipart/form-data`) with the source image file + prompt. This is an
   image-to-image edit, **not** text-to-image.
   - defaults: `size=1536x1024`, `output_format=png`, `quality=medium`.
     Size and quality can be overridden with `OPENAI_IMAGE_SIZE` and
     `OPENAI_IMAGE_QUALITY`.
   - `response_format` is **never** sent — GPT image models don't support it and
     return base64 image data.
10. Decodes `data[0].b64_json` into PNG bytes.
11. Uploads the PNG to Supabase Storage bucket `ai-generations` at path
    `<user_id>/<job_id>.png` (upsert).
12. Writes the public URL into `ai_generation_jobs.output_image_url`, sets
    `status=succeeded`, `model`, and `completed_at`, and verifies the update
    affected the claimed job.

## Location

Location is **fixed to the Imperial Palace (皇居)** in this function. A fixed
place context / direction is embedded in the prompt synthesis:

- calmness appropriate to the Imperial Palace surroundings
- a highly public urban landscape
- harmony of greenery and pedestrian space
- coexistence of historical character and the contemporary city
- avoid overly commercial or flashy expression

## Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `OPENAI_API_KEY` | yes | — | OpenAI API key. Never logged or returned. |
| `SUPABASE_URL` | yes | — | Supabase project URL. |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | — | Service-role key (bypasses RLS). Secret. |
| `OPENAI_IMAGE_MODEL` | no | `gpt-image-2` | Images edit model. |
| `OPENAI_IMAGE_SIZE` | no | `1536x1024` | Images edit output size. |
| `OPENAI_IMAGE_QUALITY` | no | `medium` | Images edit quality. Set `high` if quality is prioritized over latency/cost. |
| `OPENAI_PROMPT_MODEL` | no | `gpt-4o-mini` | Chat model for prompt synthesis. |
| `INPUT_IMAGE_PUBLIC_URL` | no | built-in fallback | Public BEFORE image used when the job stored an `assets/...` path. |

No secrets are hardcoded. No `supabase secrets set`, deploy, or bucket-creation
commands are run by this repo change — those are operational steps performed
outside the repo.

## Input image normalization

The Flutter UI stores preset BEFORE images, some as local asset paths
(`assets/...`) that the server cannot fetch. When `input_image_url` is empty or
starts with `assets/`, the function substitutes `INPUT_IMAGE_PUBLIC_URL` if set,
otherwise a fixed GitHub raw URL for the default `assets/street-before.png`.
The UI is unchanged for this. Direct URLs are accepted only when they use
`https` and their host is on the function allow-list (`raw.githubusercontent.com`,
`picsum.photos`, `fastly.picsum.photos`, the configured `INPUT_IMAGE_PUBLIC_URL`
host, or the Supabase project host). Redirects are followed manually only after
the `Location` destination passes the same allow-list check.

## Flow with Flutter

```
Flutter: insert ai_generation_jobs (status=queued)
Flutter: authenticated invoke process-ai-generation { job_id }
   └─ function: auth/ownership check → queued claim → OpenAI prompt → OpenAI images edit
                → upload to Storage → status=succeeded + output_image_url
Flutter: polls getAIGenerationJob(jobId) → shows output_image_url on succeeded
```

## Failure behavior

- Missing/invalid body → `400`. Missing auth → `401`. Caller/job mismatch →
  `403`. Missing env config → `500`. Job not found → `404`. Job not queued /
  already claimed → `409`. These leave the job untouched.
- Any error after the job is found (tag fetch, OpenAI, decode, upload) sets the
  job to `status=failed` with `error_message` and `completed_at`, and returns
  `200` with `{ ok: false, status: "failed" }`.
- The Flutter polling loop reacts to `failed` (and to its own timeout) via its
  existing fallback image path, so the UI never hangs.
- Prompt synthesis has its own deterministic fallback prompt if the chat model
  call fails, so a prompt-model hiccup does not fail the whole job.

## Responses

Returns JSON only; never includes secrets. On success:
`{ ok, job_id, status: "succeeded", output_image_url, model }`.

## CORS

`OPTIONS` preflight is handled; responses include permissive CORS headers
sufficient for Flutter web `functions.invoke`.

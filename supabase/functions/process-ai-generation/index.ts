// supabase/functions/process-ai-generation/index.ts
//
// Server-side worker for the existing ai_generation_jobs flow.
//
// Flutter inserts a `queued` row into ai_generation_jobs and then invokes this
// function with { "job_id": "<uuid>" }. This function performs all OpenAI work
// server-side (Flutter never calls OpenAI), uploads the result to Supabase
// Storage, and writes the public URL + final status back to the job row so the
// existing Flutter polling loop can pick it up.
//
// Required env vars:
//   OPENAI_API_KEY              - OpenAI API key (secret, never logged/returned)
//   SUPABASE_URL                - Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY   - service-role key (bypasses RLS, secret)
// Optional env vars:
//   OPENAI_IMAGE_MODEL          - image edit model, default "gpt-image-2"
//   OPENAI_PROMPT_MODEL         - chat model for prompt synthesis, default "gpt-4o-mini"
//   INPUT_IMAGE_PUBLIC_URL      - public URL used to normalize "assets/..." inputs
//
// NOTE: This file only defines the function. No deploy, no `supabase secrets set`,
// no bucket creation is performed here. Those are operational steps done outside
// of this repo.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const STORAGE_BUCKET = "ai-generations";

// Location is fixed to the Imperial Palace (皇居) for this MVP.
const FIXED_LOCATION = "皇居 (Imperial Palace), Tokyo, Japan";

// Fixed place context / direction kept in the function (not user supplied).
// This is the lowest-priority signal in the final prompt.
const PLACE_CONTEXT_DIRECTION = [
  "calmness appropriate to the Imperial Palace surroundings",
  "a highly public urban landscape",
  "harmony of greenery and pedestrian space",
  "coexistence of historical character and the contemporary city",
  "avoid overly commercial or flashy expression",
].join("; ");

// Fallback public URL for the BEFORE image when the job stored an "assets/..."
// path and INPUT_IMAGE_PUBLIC_URL is not configured. This keeps the edit
// endpoint working without changing the Flutter UI. The fallback points at a
// public raw copy of the default asset.
const FALLBACK_INPUT_IMAGE_URL = "https://raw.githubusercontent.com/Anya-Stella/FutureCityApp/main/assets/street-before.png";
const MAX_INPUT_IMAGE_BYTES = 10 * 1024 * 1024;

// CORS headers, permissive enough for Flutter web `functions.invoke`.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Prompt synthesis (server-side, via OpenAI chat model)
// ---------------------------------------------------------------------------
//
// Weighting is expressed as design priority, NOT a numeric formula:
//   - user free prompt  : most important (≈60)
//   - selected tags     : supporting structured elements (≈30)
//   - fixed place context: background framing only (≈10)
//
async function synthesizePrompt(opts: {
  apiKey: string;
  model: string;
  userPrompt: string;
  tagTitles: string[];
}): Promise<string> {
  const { apiKey, model, userPrompt, tagTitles } = opts;

  const tagsText = tagTitles.length > 0 ? tagTitles.join(", ") : "(none)";
  const userText = userPrompt.trim().length > 0 ? userPrompt.trim() : "(none)";

  const systemInstruction = [
    "You write a single, concise, vivid English image-editing prompt that",
    "transforms a photo of a real Japanese street near the Imperial Palace into",
    "a hopeful, realistic near-future version of the same place.",
    "",
    "Priority of inputs (design priority, not a formula):",
    "1. USER REQUEST is the most important driver of the result.",
    "2. SELECTED TAGS are supporting structured elements to weave in.",
    "3. PLACE CONTEXT is only low-priority background framing.",
    "",
    `Fixed location: ${FIXED_LOCATION}.`,
    `Place context / direction: ${PLACE_CONTEXT_DIRECTION}.`,
    "",
    "Rules: keep the original scene's geometry and viewpoint; produce one",
    "paragraph, under ~80 words, purely visual description, no lists, no",
    "preamble, no quotes. Output only the prompt text.",
    "",
    "The output image must look like a realistic photo or high-quality architectural visualization, not an illustration, anime, watercolor, concept sketch, or cartoon. Preserve the original camera angle, perspective, street geometry, building positions, and realistic lighting. Do not add text, labels, icons, or UI elements inside the image.",
  ].join("\n");

  const userMessage = [
    `USER REQUEST (most important): ${userText}`,
    `SELECTED TAGS (supporting): ${tagsText}`,
  ].join("\n");

  try {
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemInstruction },
          { role: "user", content: userMessage },
        ],
        temperature: 0.7,
        max_tokens: 220,
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(`prompt model HTTP ${resp.status}: ${errText}`);
    }

    const data = await resp.json();
    const text = data?.choices?.[0]?.message?.content?.trim();
    if (text && text.length > 0) return text;
  } catch (e) {
    console.error("Prompt synthesis failed, using deterministic fallback:", e);
  }

  // Deterministic fallback prompt keeps the same priority ordering.
  return [
    `Transform this ${FIXED_LOCATION} street scene into a hopeful near-future version.`,
    userText !== "(none)" ? `Focus on the request: ${userText}.` : "",
    tagsText !== "(none)" ? `Incorporate: ${tagsText}.` : "",
    `Keep ${PLACE_CONTEXT_DIRECTION}.`,
    "Preserve original viewpoint and layout. Photorealistic.",
  ]
    .filter((s) => s.length > 0)
    .join(" ");
}

// ---------------------------------------------------------------------------
// Input image normalization
// ---------------------------------------------------------------------------
function normalizeInputImageUrl(rawUrl: string | null | undefined): string {
  const url = (rawUrl ?? "").trim();
  if (url.length === 0 || url.startsWith("assets/")) {
    // Local Flutter asset paths are not reachable by the server. Use the
    // configured public URL, otherwise a public raw copy of the default asset.
    return (Deno.env.get("INPUT_IMAGE_PUBLIC_URL") ?? "").trim() ||
      FALLBACK_INPUT_IMAGE_URL;
  }
  return url;
}

function validateSourceImageUrl(sourceUrl: string, supabaseUrl: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(sourceUrl);
  } catch (_e) {
    throw new Error("invalid source image URL");
  }

  if (parsed.protocol !== "https:") {
    throw new Error("source image URL must use https");
  }

  const allowedHosts = new Set([
    "raw.githubusercontent.com",
    "githubusercontent.com",
    "picsum.photos",
    "fastly.picsum.photos",
  ]);

  const configuredInputUrl = (Deno.env.get("INPUT_IMAGE_PUBLIC_URL") ?? "")
    .trim();
  if (configuredInputUrl) {
    try {
      allowedHosts.add(new URL(configuredInputUrl).host);
    } catch (_e) {
      throw new Error("INPUT_IMAGE_PUBLIC_URL is invalid");
    }
  }
  if (supabaseUrl) {
    allowedHosts.add(new URL(supabaseUrl).host);
  }

  if (!allowedHosts.has(parsed.host)) {
    throw new Error("source image URL host is not allowed");
  }

  return parsed;
}

async function fetchValidatedImage(
  initialUrl: string,
  supabaseUrl: string,
): Promise<Response> {
  let currentUrl = validateSourceImageUrl(initialUrl, supabaseUrl).toString();

  for (let i = 0; i < 3; i++) {
    const resp = await fetch(currentUrl, { redirect: "manual" });
    if (![301, 302, 303, 307, 308].includes(resp.status)) {
      return resp;
    }

    const location = resp.headers.get("location");
    if (!location) {
      throw new Error("source image redirect missing Location header");
    }

    const nextUrl = new URL(location, currentUrl).toString();
    currentUrl = validateSourceImageUrl(nextUrl, supabaseUrl).toString();
  }

  throw new Error("source image redirected too many times");
}

function extractFreePrompt(rawPrompt: string): string {
  const text = rawPrompt.trim();
  const match = text.match(/要望:\s*(.*)$/s);
  if (match) return match[1].trim();

  // The Flutter job prompt is structured as `場所: ... タグ: ... 要望: ...`.
  // If there is no `要望:` segment, do not promote place/tag text into the
  // highest-priority user request bucket. Legacy unstructured prompts can still
  // pass through as free prompt text.
  if (text.includes("場所:") || text.includes("タグ:")) return "";
  return text;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  // Env
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const imageModel = (Deno.env.get("OPENAI_IMAGE_MODEL") ?? "").trim() ||
    "gpt-image-2";
  const promptModel = (Deno.env.get("OPENAI_PROMPT_MODEL") ?? "").trim() ||
    "gpt-4o-mini";

  if (!openaiApiKey || !supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  // Parse body
  let jobId: string | undefined;
  try {
    const body = await req.json();
    jobId = body?.job_id;
  } catch (_e) {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  if (!jobId || typeof jobId !== "string") {
    return jsonResponse({ error: "missing_job_id" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }

  const { data: authData, error: authErr } = await supabase.auth.getUser(jwt);
  if (authErr || !authData.user) {
    return jsonResponse({ error: "invalid_authorization" }, 401);
  }

  // Helper to mark a job as failed.
  const markFailed = async (message: string) => {
    await supabase
      .from("ai_generation_jobs")
      .update({
        status: "failed",
        error_message: message.slice(0, 1000),
        completed_at: new Date().toISOString(),
      })
      .eq("id", jobId)
      .eq("user_id", authData.user.id)
      .eq("status", "running");
  };

  try {
    // 1. Fetch + validate job
    const { data: job, error: jobErr } = await supabase
      .from("ai_generation_jobs")
      .select(
        "id, user_id, project_id, input_image_url, selected_tag_ids, prompt, status",
      )
      .eq("id", jobId)
      .single();

    if (jobErr || !job) {
      return jsonResponse({ error: "job_not_found", job_id: jobId }, 404);
    }

    if (job.user_id !== authData.user.id) {
      return jsonResponse({ error: "forbidden", job_id: jobId }, 403);
    }

    if (job.status !== "queued") {
      return jsonResponse({
        error: "job_not_queued",
        job_id: jobId,
        status: job.status,
      }, 409);
    }

    // 2. Atomically claim a queued job to avoid double execution / overwrite.
    const { data: claimedJob, error: claimErr } = await supabase
      .from("ai_generation_jobs")
      .update({ status: "running" })
      .eq("id", jobId)
      .eq("user_id", authData.user.id)
      .eq("status", "queued")
      .select("id")
      .single();
    if (claimErr || !claimedJob) {
      return jsonResponse({ error: "job_already_claimed", job_id: jobId }, 409);
    }

    const userId: string = job.user_id;
    const selectedTagIds: string[] = Array.isArray(job.selected_tag_ids)
      ? job.selected_tag_ids
      : [];
    const userPrompt: string = extractFreePrompt((job.prompt ?? "").toString());

    // 3. Resolve tag titles (supporting structured elements)
    let tagTitles: string[] = [];
    if (selectedTagIds.length > 0) {
      const { data: tagRows, error: tagErr } = await supabase
        .from("tags")
        .select("id, title")
        .in("id", selectedTagIds);
      if (!tagErr && Array.isArray(tagRows)) {
        tagTitles = tagRows.map((t: { title: string }) => t.title);
      }
    }

    if (userPrompt.length === 0 && tagTitles.length === 0) {
      throw new Error("tag or free prompt is required");
    }

    // 4. Synthesize final image prompt server-side
    const finalPrompt = await synthesizePrompt({
      apiKey: openaiApiKey,
      model: promptModel,
      userPrompt,
      tagTitles,
    });

    // 5. Normalize + fetch source image (Images EDIT requires a source image)
    const sourceUrl = normalizeInputImageUrl(job.input_image_url);
    const srcResp = await fetchValidatedImage(sourceUrl, supabaseUrl);
    if (!srcResp.ok) {
      throw new Error(`failed to fetch source image (${srcResp.status})`);
    }
    const srcBytes = new Uint8Array(await srcResp.arrayBuffer());
    if (srcBytes.byteLength > MAX_INPUT_IMAGE_BYTES) {
      throw new Error("source image is too large");
    }
    const srcContentType = srcResp.headers.get("content-type") ?? "image/png";
    if (!/image\/(png|jpeg|jpg|webp)/i.test(srcContentType)) {
      throw new Error("source URL did not return a supported image type");
    }
    const srcExt = srcContentType.includes("webp")
      ? "webp"
      : srcContentType.includes("jpeg") || srcContentType.includes("jpg")
      ? "jpg"
      : "png";
    const srcBlob = new Blob([srcBytes], { type: srcContentType });

    // 6. Call OpenAI Images EDIT (multipart/form-data) — NOT text-to-image.
    //    GPT image models return b64_json; response_format is NOT supported,
    //    so we never set it. quality "low" for MVP cost/latency.
    const form = new FormData();
    form.append("model", imageModel);
    form.append("prompt", finalPrompt);
    form.append("image", srcBlob, `source.${srcExt}`);
    form.append("size", "1536x1024");
    form.append("output_format", "png");
    form.append("quality", "high");

    const editResp = await fetch("https://api.openai.com/v1/images/edits", {
      method: "POST",
      headers: { Authorization: `Bearer ${openaiApiKey}` },
      body: form,
    });

    if (!editResp.ok) {
      const errText = await editResp.text();
      throw new Error(`images edit HTTP ${editResp.status}: ${errText}`);
    }

    const editData = await editResp.json();
    const b64: string | undefined = editData?.data?.[0]?.b64_json;
    if (!b64) {
      throw new Error("openai response missing b64_json image data");
    }

    // 7. Decode base64 PNG bytes
    const binary = atob(b64);
    const pngBytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      pngBytes[i] = binary.charCodeAt(i);
    }

    // 8. Upload to Storage bucket: <user_id>/<job_id>.png
    const objectPath = `${userId}/${jobId}.png`;
    const { error: uploadErr } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(objectPath, pngBytes, {
        contentType: "image/png",
        upsert: true,
      });
    if (uploadErr) {
      throw new Error(`storage upload failed: ${uploadErr.message}`);
    }

    const { data: publicUrlData } = supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(objectPath);
    const outputImageUrl = publicUrlData.publicUrl;

    // 9. Mark succeeded
    const { data: updatedJob, error: updateErr } = await supabase
      .from("ai_generation_jobs")
      .update({
        status: "succeeded",
        output_image_url: outputImageUrl,
        model: imageModel,
        completed_at: new Date().toISOString(),
      })
      .eq("id", jobId)
      .eq("user_id", authData.user.id)
      .eq("status", "running")
      .select("id, status, output_image_url")
      .single();
    if (
      updateErr || !updatedJob || updatedJob.status !== "succeeded" ||
      updatedJob.output_image_url !== outputImageUrl
    ) {
      throw new Error("failed to update ai_generation_jobs with generated image URL");
    }

    return jsonResponse({
      ok: true,
      job_id: jobId,
      status: "succeeded",
      output_image_url: outputImageUrl,
      model: imageModel,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("process-ai-generation failed:", message);
    await markFailed(message);
    return jsonResponse({ ok: false, job_id: jobId, status: "failed" }, 200);
  }
});

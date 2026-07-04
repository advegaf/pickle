/**
 * PICKLE AI proxy: holds the Anthropic key server-side so no key ever ships in a
 * client binary. Implements exactly the contract ProxyAIEstimationService expects
 * (Pickle/Services/AIEstimationService.swift):
 *
 *   POST /estimate  {"text": string} | {"image_base64": string}
 *   -> 200 {"items":[{"name","portion","kcal","protein","carbs","fat","confidence"}]}
 *   -> 400 malformed request, 413 oversized image, 422 nothing extractable,
 *      502 upstream failure.
 *
 * The app applies its own sanity gate on top; this validates and clamps first so
 * garbage never leaves the server.
 */

export interface Env {
  ANTHROPIC_API_KEY: string;
}

const MODEL = "claude-haiku-4-5-20251001";
const MAX_IMAGE_BASE64_BYTES = 5 * 1024 * 1024; // ~3.7MB of JPEG
const UPSTREAM_TIMEOUT_MS = 15_000;

const SYSTEM_PROMPT = `You extract food items from a meal description or photo for a calorie tracker.
Respond with ONLY a JSON object, no prose, matching exactly:
{"items":[{"name":"...","portion":"...","kcal":123,"protein":10,"carbs":20,"fat":5,"confidence":0.9}]}
Rules: 1-6 items; kcal is the item's total calories for the stated portion; protein/carbs/fat
are grams for that portion; confidence is 0-1 (use lower values when the portion is a guess);
portion is a short human label like "1 bowl" or "2 slices". If nothing edible is described,
return {"items":[]}.`;

type Item = {
  name: string;
  portion: string;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence: number;
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // The app's public privacy policy (linked from App Store Connect).
    if (request.method === "GET" && url.pathname === "/privacy") {
      return new Response(PRIVACY_HTML, {
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    if (request.method !== "POST" || url.pathname !== "/estimate") {
      return json({ error: "not found" }, 404);
    }

    let body: { text?: unknown; image_base64?: unknown };
    try {
      body = await request.json();
    } catch {
      return json({ error: "malformed JSON" }, 400);
    }

    const text = typeof body.text === "string" ? body.text.trim() : "";
    const image = typeof body.image_base64 === "string" ? body.image_base64 : "";
    if (!text && !image) return json({ error: "text or image_base64 required" }, 400);
    if (image && image.length > MAX_IMAGE_BASE64_BYTES) return json({ error: "image too large" }, 413);

    const content: unknown[] = [];
    if (image) {
      content.push({
        type: "image",
        source: { type: "base64", media_type: "image/jpeg", data: image },
      });
      content.push({ type: "text", text: "Extract the food items in this meal photo." });
    } else {
      content.push({ type: "text", text: `Meal description: ${text.slice(0, 2000)}` });
    }

    const upstream = await callAnthropic(env, content);
    if (!upstream.ok) return json({ error: "upstream" }, 502);

    const items = parseItems(upstream.text);
    if (items.length === 0) return json({ error: "nothing extractable" }, 422);
    return json({ items });
  },
} satisfies ExportedHandler<Env>;

async function callAnthropic(
  env: Env,
  content: unknown[],
): Promise<{ ok: boolean; text: string }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content }],
      }),
    });
    if (!res.ok) return { ok: false, text: "" };
    const data = (await res.json()) as { content?: Array<{ type: string; text?: string }> };
    const text = (data.content ?? [])
      .filter((b) => b.type === "text")
      .map((b) => b.text ?? "")
      .join("");
    return { ok: true, text };
  } catch {
    return { ok: false, text: "" };
  } finally {
    clearTimeout(timer);
  }
}

/** Pull the first JSON object out of the model text and validate/clamp every item. */
function parseItems(raw: string): Item[] {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) return [];
  let parsed: { items?: unknown };
  try {
    parsed = JSON.parse(raw.slice(start, end + 1));
  } catch {
    return [];
  }
  if (!Array.isArray(parsed.items)) return [];

  const items: Item[] = [];
  for (const candidate of parsed.items.slice(0, 6)) {
    const c = candidate as Record<string, unknown>;
    const name = typeof c.name === "string" ? c.name.trim().slice(0, 80) : "";
    if (!name) continue;
    const item: Item = {
      name,
      portion: typeof c.portion === "string" && c.portion.trim() ? c.portion.trim().slice(0, 40) : "1 serving",
      kcal: clampInt(c.kcal, 0, 4000),
      protein: clampInt(c.protein, 0, 1000),
      carbs: clampInt(c.carbs, 0, 1000),
      fat: clampInt(c.fat, 0, 1000),
      confidence: clampFloat(c.confidence, 0, 1, 0.8),
    };
    items.push(item);
  }
  return items;
}

function clampInt(v: unknown, lo: number, hi: number): number {
  const n = typeof v === "number" && Number.isFinite(v) ? Math.round(v) : 0;
  return Math.min(Math.max(n, lo), hi);
}

function clampFloat(v: unknown, lo: number, hi: number, fallback: number): number {
  const n = typeof v === "number" && Number.isFinite(v) ? v : fallback;
  return Math.min(Math.max(n, lo), hi);
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}

const PRIVACY_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PICKLE Privacy Policy</title>
<style>
  body { background:#000; color:#e8e8e8; font: 17px/1.6 -apple-system, system-ui, sans-serif;
         max-width: 640px; margin: 0 auto; padding: 48px 24px 96px; }
  h1 { font-size: 28px; } h2 { font-size: 20px; margin-top: 2em; color: #fff; }
  p, li { color:#a3a3a3; } strong { color:#e8e8e8; }
  a { color:#e8e8e8; }
</style>
</head>
<body>
<h1>PICKLE Privacy Policy</h1>
<p>Effective July 4, 2026</p>

<p><strong>The short version: your data stays on your phone.</strong> PICKLE has no
accounts, no sign-up, no analytics, and no advertising. We cannot see your food diary,
your weight, or anything else you enter.</p>

<h2>Data stored on your device</h2>
<p>Your food diary, calorie and macro targets, body stats, weight entries, saved foods
and meals, and reminder settings are stored locally on your iPhone. They are included
in your device backups under your control. You can export everything (CSV/JSON) or
permanently delete all data at any time from About &amp; Privacy inside the app.</p>

<h2>AI meal estimation (the one exception)</h2>
<p>When you choose AI logging, the meal description you type or the photo you take is
sent over an encrypted connection to our server, which forwards it to an AI provider
(Anthropic) to estimate the foods and macros. The request is processed and the result
returned; we do not store your descriptions or photos, and they are not used to train
models. Nothing is ever sent unless you explicitly use the AI logging feature.</p>

<h2>Apple Health</h2>
<p>With your permission, PICKLE can read your body weight from Apple Health and save
the nutrition you log back to Apple Health. Health data is handled entirely on your
device under Apple's HealthKit rules, is never transmitted to us, and you can revoke
access anytime in the Health app.</p>

<h2>Notifications</h2>
<p>Meal reminders are local notifications scheduled on your device. They use generic
wording; what you eat never appears on your lock screen.</p>

<h2>What we do not do</h2>
<ul>
<li>No accounts, no personal identifiers collected</li>
<li>No analytics, tracking, or third-party SDKs</li>
<li>No selling or sharing of data with anyone</li>
</ul>

<h2>Changes and contact</h2>
<p>If this policy changes, the update will be posted at this address. Questions:
<a href="mailto:advegaf@tamu.edu">advegaf@tamu.edu</a>.</p>
</body>
</html>`;

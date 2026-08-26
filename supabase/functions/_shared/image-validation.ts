// ============================================================================
// image-validation.ts
// ----------------------------------------------------------------------------
// LLM-based image validation for restaurant photos. Uses MiMo v2.5 vision
// to check if an image is a legitimate restaurant/food photo before promoting
// it as the primary image.
// ============================================================================

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ImageValidationResult {
  approved: boolean;
  score: number; // 0.0 - 1.0
  reason: string; // "food_photo", "person_selfie", "logo", "ad", "menu", "interior", "storefront", "other"
  notes: string;
}

// ---------------------------------------------------------------------------
// Validation prompt
// ---------------------------------------------------------------------------

const VALIDATION_SYSTEM_PROMPT =
  `You are validating images for a restaurant directory app called MakanSpot.
Analyze this image and determine if it's a good representation of the restaurant.

Rate the image on these criteria:
1. Does it show food, the restaurant interior, or the storefront?
2. Does it prominently feature people's faces (selfies, influencer photos)?
3. Is it an advertisement, logo, menu screenshot, or non-food content?
4. Would this image make a user want to visit the restaurant?

Return strict JSON:
{
  "approved": true or false,
  "score": 0.0 to 1.0,
  "reason": "food_photo|person_selfie|logo|ad|menu|interior|storefront|other",
  "notes": "brief explanation"
}

Rules:
- Approved if the image primarily shows food, interior, or storefront
- Rejected if the image prominently features people's faces (selfies > 30% of frame)
- Rejected if it's clearly a logo, advertisement, or menu screenshot
- Score 0.8-1.0 for excellent food/ambiance photos
- Score 0.5-0.7 for acceptable but not ideal photos
- Score 0.0-0.4 for poor quality or rejected images`;

// ---------------------------------------------------------------------------
// Validation function
// ---------------------------------------------------------------------------

/**
 * Validate an image URL for restaurant suitability.
 * Downloads the image and sends to a vision LLM for classification.
 *
 * Fails closed: an unavailable validator must never promote an unverified image.
 */
export async function validateImage(
  imageUrl: string,
  restaurantName: string,
  downloaded?: { bytes: Uint8Array; contentType: string },
): Promise<ImageValidationResult> {
  const apiKey = Deno.env.get("MIMO_API_KEY") ?? Deno.env.get("LLM_API_KEY") ??
    Deno.env.get("OPENAI_API_KEY");
  const baseUrl =
    (Deno.env.get("MIMO_BASE_URL") ?? Deno.env.get("LLM_BASE_URL") ??
      "https://api.openai.com/v1")
      .replace(/\/+$/, "");
  const model = Deno.env.get("MIMO_MODEL") ?? Deno.env.get("LLM_MODEL") ??
    Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  // Fail closed if no API key; existing primary images remain untouched.
  if (!apiKey) {
    return {
      approved: false,
      score: 0,
      reason: "no_api_key",
      notes: "Validation skipped: no LLM API key configured",
    };
  }

  try {
    // Download image as base64
    let contentType = downloaded?.contentType;
    let imageBytes: ArrayBuffer;
    if (downloaded) {
      imageBytes = downloaded.bytes.buffer.slice(
        downloaded.bytes.byteOffset,
        downloaded.bytes.byteOffset + downloaded.bytes.byteLength,
      ) as ArrayBuffer;
    } else {
      const imageResp = await fetch(imageUrl, {
        signal: AbortSignal.timeout(12_000),
      });
      if (!imageResp.ok) {
        return {
          approved: false,
          score: 0,
          reason: "download_failed",
          notes: `Image download failed (${imageResp.status}), allowing image`,
        };
      }
      contentType = imageResp.headers.get("content-type") ?? "image/jpeg";
      imageBytes = await imageResp.arrayBuffer();
    }
    const base64 = btoa(
      Array.from(new Uint8Array(imageBytes))
        .map((b) => String.fromCharCode(b))
        .join(""),
    );

    // Call vision LLM
    const resp = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: VALIDATION_SYSTEM_PROMPT },
          {
            role: "user",
            content: [
              {
                type: "text",
                text:
                  `Validate this image for the restaurant "${restaurantName}".`,
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:${contentType};base64,${base64}`,
                },
              },
            ],
          },
        ],
      }),
      signal: AbortSignal.timeout(25_000),
    });

    if (!resp.ok) {
      console.error(
        `[image-validation] LLM API error: ${resp.status} ${await resp.text()}`,
      );
      return {
        approved: false,
        score: 0,
        reason: "api_error",
        notes: `LLM API error (${resp.status}), allowing image`,
      };
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) {
      return {
        approved: false,
        score: 0,
        reason: "empty_response",
        notes: "LLM returned empty response, allowing image",
      };
    }

    const parsed = JSON.parse(content) as {
      approved?: boolean;
      score?: number;
      reason?: string;
      notes?: string;
    };

    return {
      approved: parsed.approved !== false,
      score: typeof parsed.score === "number"
        ? Math.max(0, Math.min(1, parsed.score))
        : 0.5,
      reason: typeof parsed.reason === "string" ? parsed.reason : "unknown",
      notes: typeof parsed.notes === "string" ? parsed.notes : "",
    };
  } catch (e) {
    console.error("[image-validation] Validation failed:", e);
    return {
      approved: false,
      score: 0,
      reason: "exception",
      notes: `Validation exception: ${
        e instanceof Error ? e.message : String(e)
      }`,
    };
  }
}

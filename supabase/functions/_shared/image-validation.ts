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
The app is a directory that helps users discover Malaysian restaurants. Many
restaurants promote themselves on Instagram with creative posts that include
people, branding, lifestyle shots, promos, collages, and styled food
photography. We want to KEEP any image that has a clear connection to a
restaurant — only reject images that are clearly unrelated to the
restaurant/food/dining experience.

Analyze this image and answer:

1. Is there ANY visible connection to a restaurant, café, eatery, food
   brand, food product, or dining experience? Examples of "connected":
   - Food, drinks, desserts, plated meals, ingredients being prepared
   - Restaurant interior, exterior, signage, storefront, dining area
   - Staff, chefs, or people holding/serving food at a venue
   - Promotional posts, price tags, vouchers, posters, flyers for a restaurant
   - Menus, menu boards, or order screens IF branded with a specific restaurant
   - Packaging, takeaway boxes, branded cups, branded bags
   - Influencer/selfie shots WHERE the post is clearly at or about a restaurant
     (e.g. person holding food from the venue, branded backdrop, restaurant
     signage visible)
   - Lifestyle shots that include food/venue in a recognisable way
2. Or is the image completely unrelated to food/dining (e.g. random
   landscape, generic stock photo, unrelated meme, off-topic screenshot,
   portrait with no food/venue context)?

Return strict JSON:
{
  "approved": true or false,
  "score": 0.0 to 1.0,
  "reason": "food_photo|drink_photo|interior|storefront|staff_serving|branded_promo|menu|packaging|selfie_at_venue|unrelated",
  "notes": "brief explanation"
}

Rules:
- DEFAULT TO APPROVED. Only reject if the image is clearly unrelated to
  food, drink, or a restaurant/café/venue. When in doubt, approve.
- Approve restaurant promotions, advertisements, posters, and branded
  collages — these ARE useful representation of the restaurant.
- Approve menus / menu boards if they show a specific restaurant's branding.
- Approve influencer-style shots if the venue or food is recognisable in
  the frame. Only reject selfies with no food/venue context.
- Approve packaging (branded takeaway boxes, cups, bags) and product shots.
- Approve storefronts, signage, and interior shots even without people.
- Approve ingredient or behind-the-scenes prep shots.
- Reject only: random scenery with no venue/food, generic stock photos
  unrelated to dining, off-topic memes, screenshots of unrelated apps, or
  pure portraits with no food/venue in frame.
- Score 0.8-1.0 for excellent food / storefront / interior photos
- Score 0.6-0.8 for good branded promos, packaging, or clear food photos
- Score 0.4-0.6 for acceptable lifestyle/selfie-at-venue shots
- Score 0.0-0.3 for unrelated or low-quality rejected images`;

// ---------------------------------------------------------------------------
// Validation function
// ---------------------------------------------------------------------------

/**
 * Validate an image URL for restaurant suitability.
 * Downloads the image and sends to a vision LLM for classification.
 *
 * Defaults to APPROVED. Only an explicit LLM rejection
 * (parsed.approved === false) blocks the image. The prompt is tuned to
 * accept anything with a visible restaurant/food/dining connection
 * (promos, branded packaging, menus, influencer-at-venue shots, etc.)
 * and reject only images that are clearly unrelated to food or dining.
 * Infrastructure errors (no API key, network, 5xx, parse failure) return
 * approved: true so a borderline photo still makes it through when the
 * validator itself is unavailable. Callers should log the reason in
 * restaurant_images.validation_reason so an operator can audit later.
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
    console.warn(
      "[image-validation] No LLM API key configured — skipping validation and allowing image through",
    );
    return {
      approved: true,
      score: 0.5,
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
        console.warn(
          `[image-validation] Image download failed (${imageResp.status}) — allowing image through`,
        );
        return {
          approved: true,
          score: 0.5,
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
        `[image-validation] LLM API error: ${resp.status} ${await resp.text()} — allowing image through`,
      );
      return {
        approved: true,
        score: 0.5,
        reason: "api_error",
        notes: `LLM API error (${resp.status}), allowing image`,
      };
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) {
      console.warn(
        "[image-validation] LLM returned empty response — allowing image through",
      );
      return {
        approved: true,
        score: 0.5,
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
    console.error(
      "[image-validation] Validation exception — allowing image through:",
      e,
    );
    return {
      approved: true,
      score: 0.5,
      reason: "exception",
      notes: `Validation exception: ${
        e instanceof Error ? e.message : String(e)
      }`,
    };
  }
}

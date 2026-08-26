import {
  toPlaceCandidate,
  toStagingRow,
  applyAuthoritativeLocation,
  boundLocationPostItems,
  boundLocationPostTargets,
  isLikelyFoodPlace,
  placePostsToRows,
  shouldQueueLocationPosts,
} from "./apify.ts";
import {
  deriveCategories,
  isLikelyNotRestaurant,
  normalizeName,
  popularityScore,
  reverseGeocode,
  selectBestImageCandidate,
  sumComponentCosts,
  trendScore,
} from "./enrich.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("post mapper extracts stable Instagram identity", () => {
  const row = toStagingRow({
    url: "https://www.instagram.com/reel/ABC_123/",
    ownerUsername: "foodie",
    likesCount: 42,
    hashtags: ["pjfood", { name: "cafe" }],
  }, "PJ food");
  assert(
    row?.external_post_id === "ABC_123",
    "shortcode should be the dedup key",
  );
  assert(row?.status === "pending", "new rows start pending");
  assert(
    row?.hashtags.join(",") === "pjfood,cafe",
    "hashtags should normalize",
  );
});

Deno.test("place mapper carries metadata and injects location into embedded posts", () => {
  const place = toPlaceCandidate({
    location_id: "9988",
    name: "Kedai Kopi Test",
    lat: 3.1,
    lng: 101.6,
    category: "Cafe",
    posts: [{ url: "https://instagram.com/p/POST1/", caption: "Lunch" }],
  });
  assert(place?.external_id === "9988", "place identity should map");
  const rows = placePostsToRows(place!);
  assert(rows.length === 1, "embedded post should map");
  assert(rows[0].location_id === "9988", "place identity should be injected");
  assert(
    rows[0].location_name === "Kedai Kopi Test",
    "place name should be injected",
  );
});

Deno.test("nested place posts normalize and inherit exact location", () => {
  const place = toPlaceCandidate({
    location_id: "445566",
    name: "Restoran Nested",
    lat: 3.1,
    lng: 101.6,
    slug: "restoran-nested",
    posts: [{
      code: "NESTED1",
      locationId: "wrong-nested-location",
      parentData: {
        location_id: "wrong-parent-location",
        inputUrl: "https://instagram.com/explore/locations/999999/wrong/",
      },
      caption: { text: "Best #nasi in town" },
      image_versions2: { candidates: [{ url: "https://img.test/food.jpg" }] },
      like_count: 88,
      comment_count: 7,
      taken_at: 1_700_000_000,
      user: { username: "foodlover" },
    }],
  });
  const row = placePostsToRows(place!)[0];
  assert(row.external_post_id === "NESTED1", "nested shortcode should map");
  assert(
    row.cover_url === "https://img.test/food.jpg",
    "nested image should map",
  );
  assert(
    row.likes === 88 && row.comments === 7,
    "nested engagement should map",
  );
  assert(row.location_id === "445566", "exact parent location should inherit");
});

Deno.test("place food filter rejects obvious non-food places conservatively", () => {
  assert(
    isLikelyFoodPlace({
      name: "Ali Cafe",
      category: "Coffee Shop",
      posts: [],
    }),
    "cafe should pass",
  );
  assert(
    !isLikelyFoodPlace({
      name: "Community Gym",
      category: "Fitness",
      posts: [],
    }),
    "gym should fail",
  );
  assert(
    !isLikelyFoodPlace({ name: "Unknown Venue", category: null, posts: [] }),
    "unknown metadata without food evidence should fail",
  );
  assert(
    isLikelyFoodPlace({
      name: "Unknown Venue",
      category: null,
      posts: [{ caption: "Great ramen and sushi restaurant" }],
    }),
    "embedded food-post evidence should pass",
  );
  assert(
    !isLikelyFoodPlace({
      name: "City Hotel",
      category: "Hotel",
      posts: [{ caption: "Great ramen restaurant downstairs" }],
    }),
    "hotel metadata must override embedded food evidence",
  );
  assert(
    !isLikelyFoodPlace({
      name: "Mega Shopping Mall",
      category: "Shopping Mall",
      posts: [{ caption: "Try this cafe and dessert" }],
    }),
    "mall metadata must override embedded food evidence",
  );
  assert(
    !isLikelyFoodPlace({
      name: "Kedai Buku Ilmu",
      category: "Bookstore",
      posts: [],
    }),
    "bare kedai must not be treated as food evidence",
  );
});

Deno.test("pure filtering and scoring helpers remain deterministic", () => {
  assert(
    isLikelyNotRestaurant("Cara masak nasi lemak step by step", []),
    "recipe should skip",
  );
  assert(
    !isLikelyNotRestaurant(
      "Try the excellent noodles at Restoran ABC in SS15",
      ["ss15food"],
    ),
    "venue post should pass",
  );
  assert(
    normalizeName("  Café D'Anis! ") === "cafe d anis",
    "name should normalize",
  );
  assert(
    deriveCategories("Cafe", "Test", []).includes("Cafe"),
    "category should derive",
  );
  assert(
    popularityScore(10_000, 1_000, 1_000_000) === 100,
    "score should cap at 100",
  );
  const trend = trendScore({
    mentionsLast7d: 4,
    mentionsPrev7d: 2,
    uniqueCreators: 3,
    totalMentions: 4,
    avgEngagement: 500,
    daysSinceLastMention: 1,
  });
  assert(trend > 0 && trend <= 1, "trend score should be normalized");
});

Deno.test("embedded covers suppress paid location follow-up", () => {
  assert(
    !shouldQueueLocationPosts({
      hasPrimary: false,
      hasEmbeddedCover: true,
      exactLocationUrl: "https://instagram.com/explore/locations/123/cafe/",
    }),
    "embedded cover should suppress follow-up",
  );
  assert(
    shouldQueueLocationPosts({
      hasPrimary: false,
      hasEmbeddedCover: false,
      exactLocationUrl: "https://instagram.com/explore/locations/123/cafe/",
    }),
    "missing images should queue exact location URL",
  );
});

Deno.test("location follow-up is globally bounded and authoritative", () => {
  assert(
    boundLocationPostTargets(["first", "second"]).join(",") === "first",
    "only one exact location target is allowed",
  );
  assert(
    boundLocationPostItems([1, 2, 3, 4], 1).join(",") === "1,2",
    "remaining global item allowance must cap at three",
  );
  const row = toStagingRow({
    code: "CONFLICT1",
    location: { pk: "wrong-location" },
    image_versions2: { candidates: [{ url: "https://img.test/conflict.jpg" }] },
  })!;
  applyAuthoritativeLocation(row, "target-location");
  assert(
    row.location_id === "target-location",
    "stored target location must override conflicting actor metadata",
  );
});

Deno.test("best image ranking is deterministic and penalizes promotions", () => {
  const best = selectBestImageCandidate([
    {
      cover_url: "https://img.test/ad.jpg",
      caption: "GIVEAWAY sponsored announcement logo",
      hashtags: ["ad"],
      likes: 1000,
      comments: 200,
      posted_at: "2026-01-01T00:00:00Z",
    },
    {
      cover_url: "https://img.test/food.jpg",
      caption: "Fresh ramen and sushi at this restaurant",
      hashtags: ["food"],
      likes: 500,
      comments: 40,
      posted_at: "2026-01-01T00:00:00Z",
    },
  ], Date.parse("2026-01-02T00:00:00Z"));
  assert(
    best?.cover_url === "https://img.test/food.jpg",
    "food image should outrank ad",
  );
});

Deno.test("reverse geocode uses v6 request and parses context", async () => {
  const previous = Deno.env.get("MAPBOX_TOKEN");
  Deno.env.set("MAPBOX_TOKEN", "test-token");
  let requested = "";
  const result = await reverseGeocode(3.1, 101.6, (input) => {
    requested = String(input);
    return Promise.resolve(
      new Response(
        JSON.stringify({
          features: [{
            properties: {
              full_address: "1 Jalan Test, Petaling Jaya, Malaysia",
              context: { place: { name: "Petaling Jaya" } },
            },
          }],
        }),
        { status: 200 },
      ),
    );
  });
  if (previous == null) Deno.env.delete("MAPBOX_TOKEN");
  else Deno.env.set("MAPBOX_TOKEN", previous);
  assert(
    requested.includes("/search/geocode/v6/reverse"),
    "v6 endpoint required",
  );
  assert(
    requested.includes("country=my"),
    "country=my flag required",
  );
  assert(result?.city === "Petaling Jaya", "city context should parse");
});

Deno.test("component costs aggregate safely", () => {
  assert(
    sumComponentCosts([0.0027, 0.004, null, -1]) === 0.0067,
    "component costs should sum non-negative values",
  );
});

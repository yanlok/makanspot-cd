// ============================================================================
// discovery-priority
// ----------------------------------------------------------------------------
// Deterministic replacement for "have an LLM pick the best query every run".
// A live model call per run adds latency, cost, and non-determinism to a
// problem a numeric score already solves better: this is a classic
// explore/exploit (multi-armed bandit) ranking over discovery_sources.
//
// priority_score blends three signals so ORDER BY priority_score DESC
// actually reflects real performance (previously this column was written
// once at insert time and never recomputed, so every source sat at the
// same 0.5 default forever):
//
//   0.50 x normalized yield        (new_restaurants / posts_scraped)
// + 0.35 x cost efficiency         (lower cost_per_new_restaurant is better)
// + 0.15 x exploration bonus       (decays to 0 by the 5th scrape)
//
// Freshness (how long since a source was last scraped) is intentionally
// NOT baked into the stored score, since it would go stale immediately
// after every write with no cron job to keep recomputing it. Callers should
// use last_scraped_at as a secondary ORDER BY tiebreaker instead.
// ============================================================================

/** Reference cost/restaurant used to normalize cost efficiency into 0..1. */
const REFERENCE_COST_PER_RESTAURANT = 0.05;

/** Scrape count at which the exploration bonus fully decays to zero. */
const EXPLORATION_SCRAPE_CAP = 5;

/** Neutral priority assigned to a source that has never been scraped. */
export const DEFAULT_NEW_SOURCE_PRIORITY = computePriorityScore({
  scrapeCount: 0,
  yieldRate: 0,
  newRestaurants: 0,
  costPerNewRestaurant: 0,
});

export interface PriorityInputs {
  /** Lifetime scrape attempts for this source, including the current one. */
  scrapeCount: number;
  /** Lifetime new_restaurants / posts_scraped. Ignored when scrapeCount is 0. */
  yieldRate: number;
  /** Lifetime new restaurants found. Used to detect "tried and found nothing". */
  newRestaurants: number;
  /** Lifetime total_cost_usd / new_restaurants. Ignored when newRestaurants is 0. */
  costPerNewRestaurant: number;
}

export function computePriorityScore(input: PriorityInputs): number {
  const hasBeenScraped = input.scrapeCount > 0;

  const normalizedYield = hasBeenScraped ? clampUnit(input.yieldRate) : 0.5;

  const costEfficiency = !hasBeenScraped
    ? 0.5 // Unproven source, neutral prior.
    : input.newRestaurants === 0
    ? 0.15 // Tried and found nothing; a $0 "average cost" is not a good sign.
    : clampUnit(
      1 - input.costPerNewRestaurant / REFERENCE_COST_PER_RESTAURANT,
    );

  const explorationBonus = clampUnit(
    (EXPLORATION_SCRAPE_CAP - input.scrapeCount) / EXPLORATION_SCRAPE_CAP,
  );

  return round4(
    0.50 * normalizedYield + 0.35 * costEfficiency + 0.15 * explorationBonus,
  );
}

/**
 * Cooldown tiers follow the documented yield bands (see
 * docs/data-pipeline-implementation.md §5), shortened when this specific
 * run was productive so hot sources get retried sooner than the lifetime
 * average alone would suggest.
 */
export function computeCooldownMs(
  lifetimeYieldRate: number,
  thisRunProductive: boolean,
): number {
  const DAY_MS = 24 * 60 * 60 * 1000;
  if (lifetimeYieldRate > 0.20) return thisRunProductive ? DAY_MS : 2 * DAY_MS;
  if (lifetimeYieldRate > 0.05) {
    return thisRunProductive ? 3 * DAY_MS : 7 * DAY_MS;
  }
  if (lifetimeYieldRate > 0.01) return 7 * DAY_MS;
  return 14 * DAY_MS;
}

/**
 * A source should be paused once it looks dry. Place-search sources
 * (search_query/automation) are structurally low-volume on the current
 * Apify actors (verified: ~1 result/run vs 12-20+ for hashtag sources
 * regardless of query wording), so they get a shorter leash than hashtags.
 */
export function shouldPauseSource(input: {
  sourceType: string;
  scrapeCount: number;
  lifetimeYieldRate: number;
  consecutiveZeroYieldRuns: number;
}): boolean {
  const isLowVolumeType = input.sourceType === "automation" ||
    input.sourceType === "search_query";

  if (input.scrapeCount >= 5 && input.lifetimeYieldRate < 0.01) return true;
  if (isLowVolumeType && input.consecutiveZeroYieldRuns >= 2) return true;
  if (input.consecutiveZeroYieldRuns >= 3) return true;
  return false;
}

function clampUnit(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.min(1, Math.max(0, n));
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}

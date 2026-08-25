-- Migration: Add last_scraped_at to restaurants
-- Tracks when each restaurant's Instagram location page was last scraped.
-- Used by scrape_locations.mjs to avoid re-scraping too frequently.

ALTER TABLE public.restaurants
ADD COLUMN IF NOT EXISTS last_scraped_at timestamp with time zone;

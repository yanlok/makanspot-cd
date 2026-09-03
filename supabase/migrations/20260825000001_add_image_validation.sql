-- Add image validation columns to restaurant_images.
-- Stores LLM validation results for admin review.

ALTER TABLE restaurant_images
  ADD COLUMN validation_score NUMERIC(3,2) DEFAULT NULL,
  ADD COLUMN validation_reason TEXT DEFAULT NULL;

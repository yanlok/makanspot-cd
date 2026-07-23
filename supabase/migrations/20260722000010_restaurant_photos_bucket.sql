-- Public storage bucket for re-hosted restaurant photos (originally created for the
-- Google Places photo pipeline, which has since been removed due to cost).
-- The bucket still exists but is no longer written to by any active function.
-- TikTok/Instagram cover URLs are signed and expire, so the enrich function
-- used to pull a photo from Google Places, upload the bytes here, and store the
-- permanent public URL in restaurant_images. The bucket is public-read; writes
-- happen server-side via the Edge Function (service_role bypasses storage RLS).
--
-- NOTE: Since Places API removal, this bucket is orphaned.
-- No active code writes to it anymore. Photos are not being re-hosted.
-- Keep the bucket + restaurant_images table in place for potential future use
-- (e.g. admin-uploaded photos).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'restaurant-photos',
    'restaurant-photos',
    true,
    10485760, -- 10 MB per file
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
    SET public = EXCLUDED.public,
        file_size_limit = EXCLUDED.file_size_limit,
        allowed_mime_types = EXCLUDED.allowed_mime_types;

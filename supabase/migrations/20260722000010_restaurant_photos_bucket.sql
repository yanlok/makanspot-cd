-- Public storage bucket for re-hosted restaurant photos.
-- TikTok/Instagram cover URLs are signed and expire, so the enrich function
-- pulls a photo from Google Places, uploads the bytes here, and stores the
-- permanent public URL in restaurant_images. The bucket is public-read; writes
-- happen server-side via the Edge Function (service_role bypasses storage RLS).

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

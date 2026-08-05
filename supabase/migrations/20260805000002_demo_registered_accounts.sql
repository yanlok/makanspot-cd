-- Demo registered accounts for profile/admin exploration.
-- Includes validation checks and seed rows for search/filter demos.

CREATE TABLE IF NOT EXISTS public.demo_registered_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_url TEXT NOT NULL,
    name TEXT NOT NULL CHECK (char_length(trim(name)) >= 2),
    email TEXT NOT NULL UNIQUE CHECK (position('@' IN email) > 1),
    bio TEXT NOT NULL CHECK (char_length(trim(bio)) BETWEEN 10 AND 300),
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'pending', 'deactivated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS demo_registered_accounts_name_idx
ON public.demo_registered_accounts (lower(name));

CREATE INDEX IF NOT EXISTS demo_registered_accounts_email_idx
ON public.demo_registered_accounts (lower(email));

CREATE INDEX IF NOT EXISTS demo_registered_accounts_role_status_idx
ON public.demo_registered_accounts (role, status);

ALTER TABLE public.demo_registered_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view demo accounts" ON public.demo_registered_accounts;
CREATE POLICY "Authenticated users can view demo accounts"
ON public.demo_registered_accounts
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Service role manages demo accounts" ON public.demo_registered_accounts;
CREATE POLICY "Service role manages demo accounts"
ON public.demo_registered_accounts
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

GRANT SELECT ON public.demo_registered_accounts TO authenticated;
GRANT ALL ON public.demo_registered_accounts TO service_role;

INSERT INTO public.demo_registered_accounts (id, photo_url, name, email, bio, role, status)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'assets/images/default_icon.jpg', 'Yih Loong', 'yl@makanspot.my', 'Sedap hunter exploring hidden gems around Klang Valley and sharing trusted spots.', 'admin', 'active'),
    ('22222222-2222-2222-2222-222222222222', 'assets/images/default_icon.jpg', 'Aina Rahman', 'aina.r@makanspot.my', 'Weekend cafe hopper who compares flat whites and local brunch menus.', 'user', 'active'),
    ('33333333-3333-3333-3333-333333333333', 'assets/images/default_icon.jpg', 'Kelvin Ong', 'kelvin.o@makanspot.my', 'Tracks supper hotspots and hawker stalls for after-hours cravings.', 'user', 'pending'),
    ('44444444-4444-4444-4444-444444444444', 'assets/images/default_icon.jpg', 'Nadia Suraya', 'nadia.s@makanspot.my', 'Food storyteller focused on local kuih and nostalgic family recipes.', 'admin', 'deactivated'),
    ('55555555-5555-5555-5555-555555555555', 'assets/images/default_icon.jpg', 'Raj Mehta', 'raj.m@makanspot.my', 'Rates banana leaf lunches and spicy curries around the city center.', 'user', 'active')
ON CONFLICT (email) DO UPDATE SET
    photo_url = EXCLUDED.photo_url,
    name = EXCLUDED.name,
    bio = EXCLUDED.bio,
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    updated_at = NOW();

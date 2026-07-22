-- Idempotent public SELECT policies.
-- DROP first because Postgres has no CREATE POLICY IF NOT EXISTS, and a prior
-- partial apply may already have created some of these.

DROP POLICY IF EXISTS "Categories are viewable by everyone." ON public.categories;
CREATE POLICY "Categories are viewable by everyone." ON public.categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Achievements are viewable by everyone." ON public.achievements;
CREATE POLICY "Achievements are viewable by everyone." ON public.achievements FOR SELECT USING (true);

DROP POLICY IF EXISTS "Restaurant categories are viewable by everyone." ON public.restaurant_categories;
CREATE POLICY "Restaurant categories are viewable by everyone." ON public.restaurant_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Restaurant images are viewable by everyone." ON public.restaurant_images;
CREATE POLICY "Restaurant images are viewable by everyone." ON public.restaurant_images FOR SELECT USING (true);

DROP POLICY IF EXISTS "Restaurant menu is viewable by everyone." ON public.restaurant_menu;
CREATE POLICY "Restaurant menu is viewable by everyone." ON public.restaurant_menu FOR SELECT USING (true);

DROP POLICY IF EXISTS "Reviews are viewable by everyone." ON public.reviews;
CREATE POLICY "Reviews are viewable by everyone." ON public.reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Comments are viewable by everyone." ON public.comments;
CREATE POLICY "Comments are viewable by everyone." ON public.comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Likes are viewable by everyone." ON public.likes;
CREATE POLICY "Likes are viewable by everyone." ON public.likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Journeys are viewable by everyone." ON public.journeys;
CREATE POLICY "Journeys are viewable by everyone." ON public.journeys FOR SELECT USING (true);

DROP POLICY IF EXISTS "User achievements are viewable by everyone." ON public.user_achievements;
CREATE POLICY "User achievements are viewable by everyone." ON public.user_achievements FOR SELECT USING (true);

DROP POLICY IF EXISTS "Bookmarks are viewable by everyone." ON public.bookmarks;
CREATE POLICY "Bookmarks are viewable by everyone." ON public.bookmarks FOR SELECT USING (true);

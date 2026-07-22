-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user_journey()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.journeys (user_id)
  VALUES (new.id);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create journey row on user insert
CREATE OR REPLACE TRIGGER on_user_created_journey
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_journey();

-- Initialize journeys for any existing users who don't have one
INSERT INTO public.journeys (user_id)
SELECT id FROM public.users
WHERE id NOT IN (SELECT user_id FROM public.journeys)
ON CONFLICT (user_id) DO NOTHING;

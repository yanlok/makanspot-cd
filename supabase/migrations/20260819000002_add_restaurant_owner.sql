-- Stores the person responsible for a restaurant record in the admin console.
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS owner_name TEXT;

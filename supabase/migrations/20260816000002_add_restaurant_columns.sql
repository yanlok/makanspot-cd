-- Add new columns to restaurants table
ALTER TABLE public.restaurants 
ADD COLUMN IF NOT EXISTS phone_number TEXT,
ADD COLUMN IF NOT EXISTS website TEXT,
ADD COLUMN IF NOT EXISTS operating_hours JSONB;

-- Add driver_view_data JSONB column to rate_confirmations
-- This stores the curated driver view (pickup/delivery instructions, equipment requirements, etc.)

DO $$ BEGIN
    ALTER TABLE public.rate_confirmations 
    ADD COLUMN driver_view_data JSONB;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

NOTIFY pgrst, 'reload schema';

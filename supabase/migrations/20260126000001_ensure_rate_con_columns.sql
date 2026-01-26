-- Ensure rate_confirmations table has the required columns
-- This migration fixes missing columns if previous migrations failed or were skipped

DO $$ 
BEGIN
    -- 1. Ensure overall_traffic_light exists
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'traffic_light_status') THEN
        CREATE TYPE traffic_light_status AS ENUM ('RED', 'YELLOW', 'GREEN');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'rate_confirmations' AND column_name = 'overall_traffic_light') THEN
        ALTER TABLE public.rate_confirmations ADD COLUMN overall_traffic_light traffic_light_status;
    END IF;

    -- 2. Ensure driver_view_data exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'rate_confirmations' AND column_name = 'driver_view_data') THEN
        ALTER TABLE public.rate_confirmations ADD COLUMN driver_view_data JSONB;
    END IF;

END $$;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

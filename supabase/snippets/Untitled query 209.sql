-- Migration: Add status and timestamp columns to rc_stops table
-- This allows tracking the progress of each stop in a trip

DO $$ BEGIN
    CREATE TYPE stop_status_enum AS ENUM ('PENDING', 'ARRIVED', 'COMPLETED', 'SKIPPED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.rc_stops
ADD COLUMN IF NOT EXISTS status stop_status_enum DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS actual_arrival TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS actual_departure TIMESTAMPTZ;

-- Call notify schema reload
NOTIFY pgrst, 'reload schema';
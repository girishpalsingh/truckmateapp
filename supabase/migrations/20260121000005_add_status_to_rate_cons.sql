-- Add status column to rate_cons table

-- Create enum type for rate_con_status
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rate_con_status') THEN
        CREATE TYPE rate_con_status AS ENUM ('under_review', 'processing', 'approved');
    END IF;
END $$;

-- Add status column to rate_cons table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rate_cons' AND column_name = 'status') THEN
        ALTER TABLE public.rate_cons 
        ADD COLUMN status rate_con_status NOT NULL DEFAULT 'under_review';
    END IF;
END $$;

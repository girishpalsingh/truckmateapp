-- Ensure rate_con_id column exists in rate_confirmations
-- This fixes the issue where test script fails to find the column

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'rate_confirmations' AND column_name = 'rate_con_id') THEN
        ALTER TABLE public.rate_confirmations ADD COLUMN rate_con_id VARCHAR(50);
    END IF;
END $$;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

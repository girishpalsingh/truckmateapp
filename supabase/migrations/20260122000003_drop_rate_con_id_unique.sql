-- Drop the UNIQUE constraint from rate_con_id
-- The UUID (id) is the unique identifier, rate_con_id can have duplicates

ALTER TABLE public.rate_confirmations 
DROP CONSTRAINT IF EXISTS rate_confirmations_rate_con_id_key;

-- Also drop the index if it exists
DROP INDEX IF EXISTS idx_rate_confirmations_rate_con_id;

-- Recreate index without unique constraint
CREATE INDEX IF NOT EXISTS idx_rate_confirmations_rate_con_id 
ON public.rate_confirmations(rate_con_id);

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

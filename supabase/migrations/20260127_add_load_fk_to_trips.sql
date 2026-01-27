-- Add load_id column if it doesn't exist (idempotent check)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'trips' AND column_name = 'load_id') THEN
        ALTER TABLE public.trips ADD COLUMN load_id UUID;
    END IF;
END $$;

-- Clean up invalid load_ids (orphaned references) before adding constraint
UPDATE public.trips 
SET load_id = NULL 
WHERE load_id IS NOT NULL 
  AND load_id NOT IN (SELECT id FROM public.loads);

-- Add foreign key constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_trips_loads') THEN
        ALTER TABLE public.trips
        ADD CONSTRAINT fk_trips_loads
        FOREIGN KEY (load_id)
        REFERENCES public.loads(id)
        ON DELETE SET NULL;
    END IF;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_trips_load_id ON public.trips(load_id);

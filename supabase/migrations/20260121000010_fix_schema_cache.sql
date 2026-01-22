-- Ensure overall_traffic_light exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rate_cons' AND column_name = 'overall_traffic_light') THEN
        ALTER TABLE public.rate_cons ADD COLUMN overall_traffic_light text;
    END IF;
END $$;

-- Ensure rate_con_clauses exists
CREATE TABLE IF NOT EXISTS public.rate_con_clauses (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    rate_con_id uuid NOT NULL REFERENCES public.rate_cons(id) ON DELETE CASCADE,
    
    clause_type text,
    traffic_light text,
    danger_simple_language text,
    danger_simple_punjabi text,
    original_text text,
    warning_en text,
    warning_pa text,
    notification jsonb,
    
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    
    CONSTRAINT rate_con_clauses_pkey PRIMARY KEY (id)
);

-- Ensure RLS is enabled
ALTER TABLE public.rate_con_clauses ENABLE ROW LEVEL SECURITY;

-- Ensure Policy exists (drop and recreate to be safe/idempotent if needed, or IF NOT EXISTS logic)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'rate_con_clauses' 
        AND policyname = 'Users can access clauses via rate_con organization'
    ) THEN
        CREATE POLICY "Users can access clauses via rate_con organization"
            ON public.rate_con_clauses
            FOR ALL
            USING (
                exists (
                    select 1 from public.rate_cons rc
                    where rc.id = rate_con_clauses.rate_con_id
                    and rc.organization_id in (
                        select organization_id 
                        from public.profiles 
                        where id = auth.uid()
                    )
                )
            );
    END IF;
END $$;

-- Force Schema Cache Reload
NOTIFY pgrst, 'reload schema';

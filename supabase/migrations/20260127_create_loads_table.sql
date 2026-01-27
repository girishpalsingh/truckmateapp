-- Create Loads Table
CREATE TABLE IF NOT EXISTS public.loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    active_rate_con_id INT REFERENCES public.rate_confirmations(rc_id),
    
    broker_name VARCHAR(255),
    broker_load_id VARCHAR(50),
    
    status VARCHAR(50) DEFAULT 'created', -- created, assigned, dispatched, in_transit, delivered, completed, cancelled
    
    -- Financials
    primary_rate DECIMAL(10, 2),
    total_rate DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    
    dispatcher_id UUID REFERENCES public.profiles(id),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_loads_org ON public.loads(organization_id);
CREATE INDEX IF NOT EXISTS idx_loads_status ON public.loads(status);
CREATE INDEX IF NOT EXISTS idx_loads_active_rc ON public.loads(active_rate_con_id);

-- RLS
ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to allow replacement (idempotency)
DROP POLICY IF EXISTS "Users can view own org loads" ON public.loads;
CREATE POLICY "Users can view own org loads"
    ON public.loads
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id FROM public.profiles WHERE id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own org loads" ON public.loads;
CREATE POLICY "Users can insert own org loads"
    ON public.loads
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM public.profiles WHERE id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update own org loads" ON public.loads;
CREATE POLICY "Users can update own org loads"
    ON public.loads
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id FROM public.profiles WHERE id = auth.uid()
        )
    );

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_loads_updated_at ON public.loads;
CREATE TRIGGER update_loads_updated_at 
    BEFORE UPDATE ON public.loads 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Force schema reload
NOTIFY pgrst, 'reload schema';

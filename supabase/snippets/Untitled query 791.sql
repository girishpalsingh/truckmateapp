-- Migration: Trip Journey Schema Updates
-- 1. Add availability_status to profiles, trucks, trailers
-- 2. Add resource columns to loads (driver_id, truck_id, trailer_id) for easier access/RLS
-- 3. Update RLS policies

-- ============================================
-- 1. AVAILABILITY STATUS
-- ============================================

DO $$ BEGIN
    CREATE TYPE availability_status_enum AS ENUM ('AVAILABLE', 'ON_TRIP', 'OFF_DUTY', 'MAINTENANCE');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add to profiles (restricted to drivers usually, but good for all)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS availability_status availability_status_enum DEFAULT 'AVAILABLE';

-- Add to trucks
ALTER TABLE public.trucks 
ADD COLUMN IF NOT EXISTS availability_status availability_status_enum DEFAULT 'AVAILABLE';

-- Add to trailers
CREATE TABLE IF NOT EXISTS public.trailers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    trailer_number VARCHAR(20) NOT NULL,
    trailer_type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, trailer_number)
);

ALTER TABLE public.trailers 
ADD COLUMN IF NOT EXISTS availability_status availability_status_enum DEFAULT 'AVAILABLE';

-- ============================================
-- 2. LOADS RESOURCE COLUMNS
-- ============================================

ALTER TABLE public.loads
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS truck_id UUID REFERENCES public.trucks(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS trailer_id UUID REFERENCES public.trailers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_loads_driver ON public.loads(driver_id);

-- ============================================
-- 3. RLS POLICIES
-- ============================================

-- Drivers can view loads assigned to them
DROP POLICY IF EXISTS "Drivers can view assigned loads" ON public.loads;
CREATE POLICY "Drivers can view assigned loads"
    ON public.loads
    FOR SELECT
    TO authenticated
    USING (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        AND (
            (SELECT role FROM profiles WHERE id = auth.uid()) IN ('owner', 'manager', 'dispatcher', 'orgadmin')
            OR 
            driver_id = auth.uid()
        )
    );

-- Drivers can update loads assigned to them
DROP POLICY IF EXISTS "Drivers can update assigned loads" ON public.loads;
CREATE POLICY "Drivers can update assigned loads"
    ON public.loads
    FOR UPDATE
    TO authenticated
    USING (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        AND driver_id = auth.uid()
    )
    WITH CHECK (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        AND driver_id = auth.uid()
    );

-- Enable RLS on trailers if not already
ALTER TABLE public.trailers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view org trailers" ON public.trailers;
CREATE POLICY "Users can view org trailers" 
ON public.trailers FOR SELECT 
TO authenticated 
USING (organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Managers can manage trailers" ON public.trailers;
CREATE POLICY "Managers can manage trailers" 
ON public.trailers FOR ALL 
TO authenticated 
USING (
    organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid()) 
    AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('owner', 'manager', 'dispatcher', 'orgadmin')
);

NOTIFY pgrst, 'reload schema';
-- Migration: Advanced Trip-Load Workflow
-- 1. Create trip_loads table for many-to-many relationship
-- 2. Add rate_confirmation_id to loads
-- 3. Add dispatch_document_id to trips
-- 4. Make trips.odometer_start optional

-- 1. Create trip_loads table
CREATE TABLE public.trip_loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    
    -- Sequencing logic
    pickup_sequence INT DEFAULT 1,
    delivery_sequence INT DEFAULT 1,
    
    -- Segment logic
    is_partial_segment BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate linking of same load to same trip
    UNIQUE(trip_id, load_id)
);

-- Enable RLS for trip_loads (same policy pattern as trips/loads)
ALTER TABLE public.trip_loads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view org trip_loads"
  ON public.trip_loads FOR SELECT
  TO authenticated
  USING (
    trip_id IN (
      SELECT id FROM public.trips 
      WHERE organization_id IN (SELECT organization_id FROM public.profiles WHERE id = auth.uid())
    )
  );

CREATE POLICY "Drivers/Managers can manage trip_loads"
  ON public.trip_loads FOR ALL
  TO authenticated
  USING (
    trip_id IN (
      SELECT id FROM public.trips 
      WHERE organization_id IN (SELECT organization_id FROM public.profiles WHERE id = auth.uid())
      AND (driver_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('owner', 'manager', 'dispatcher', 'orgadmin')
      ))
    )
  )
  WITH CHECK (
    trip_id IN (
      SELECT id FROM public.trips 
      WHERE organization_id IN (SELECT organization_id FROM public.profiles WHERE id = auth.uid())
      AND (driver_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('owner', 'manager', 'dispatcher', 'orgadmin')
      ))
    )
  );

-- 2. Add rate_confirmation_id to loads
DO $$ BEGIN
    ALTER TABLE public.loads 
    ADD COLUMN rate_confirmation_id UUID REFERENCES public.rate_confirmations(id) ON DELETE SET NULL;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

-- 3. Add dispatch_document_id to trips
DO $$ BEGIN
    ALTER TABLE public.trips
    ADD COLUMN dispatch_document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

-- 4. Make odometer_start optional
ALTER TABLE public.trips ALTER COLUMN odometer_start DROP NOT NULL;

-- 5. Add indexes
CREATE INDEX idx_trip_loads_trip ON public.trip_loads(trip_id);
CREATE INDEX idx_trip_loads_load ON public.trip_loads(load_id);
CREATE INDEX idx_loads_rate_con ON public.loads(rate_confirmation_id);

NOTIFY pgrst, 'reload schema';

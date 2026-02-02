-- ================================================
-- Detention Invoice Feature: Database Schema
-- ================================================
-- This migration creates tables for tracking detention time and invoices.
-- Execute via: http://localhost:54323/project/default/sql/new?skip=true

-- ================================================
-- Table: detention_records
-- Stores detention time tracking data
-- ================================================
CREATE TABLE IF NOT EXISTS public.detention_records (
    -- Primary key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Foreign keys
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    stop_id INTEGER, -- References rc_stops.stop_id (no FK constraint as it's an integer sequence)
    
    -- Start detention data
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    start_location_lat NUMERIC(9, 6),
    start_location_lng NUMERIC(9, 6),
    
    -- End detention data (null while detention is active)
    end_time TIMESTAMPTZ,
    end_location_lat NUMERIC(9, 6),
    end_location_lng NUMERIC(9, 6),
    
    -- Evidence photo
    evidence_photo_url TEXT,
    evidence_photo_time TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_detention_records_org ON public.detention_records(organization_id);
CREATE INDEX IF NOT EXISTS idx_detention_records_load ON public.detention_records(load_id);
CREATE INDEX IF NOT EXISTS idx_detention_records_active ON public.detention_records(load_id) WHERE end_time IS NULL;

-- Enable RLS
ALTER TABLE public.detention_records ENABLE ROW LEVEL SECURITY;

-- RLS Policies for detention_records
CREATE POLICY "Users can view detention records in their organization"
    ON public.detention_records FOR SELECT
    USING (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can insert detention records in their organization"
    ON public.detention_records FOR INSERT
    WITH CHECK (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can update detention records in their organization"
    ON public.detention_records FOR UPDATE
    USING (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can delete detention records in their organization"
    ON public.detention_records FOR DELETE
    USING (organization_id = public.get_user_organization_id());

-- Comment for documentation
COMMENT ON TABLE public.detention_records IS 'Stores detention time records for loads at stops. Created when driver starts detention timer, updated when stopped.';

-- ================================================
-- Table: detention_invoices
-- Stores generated detention invoices
-- ================================================
CREATE TABLE IF NOT EXISTS public.detention_invoices (
    -- Primary key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Foreign keys
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    detention_record_id UUID NOT NULL REFERENCES public.detention_records(id) ON DELETE CASCADE,
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    
    -- Invoice identification
    invoice_number TEXT NOT NULL UNIQUE,
    detention_invoice_display_number TEXT,
    
    -- Reference numbers from BOL/RC
    po_number TEXT,
    bol_number TEXT,
    
    -- Facility information
    facility_name TEXT,
    facility_address TEXT,
    
    -- Detention time details (denormalized for invoice record)
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    start_location_lat NUMERIC(9, 6),
    start_location_lng NUMERIC(9, 6),
    end_location_lat NUMERIC(9, 6),
    end_location_lng NUMERIC(9, 6),
    
    -- Evidence
    detention_photo_link TEXT,
    detention_photo_time TIMESTAMPTZ,
    
    -- Financial calculations
    rate_per_hour NUMERIC(10, 2) NOT NULL,
    total_hours NUMERIC(10, 2) NOT NULL,
    payable_hours NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    total_due NUMERIC(10, 2) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL, -- Alias for total_due (used by some queries)
    
    -- Generated PDF
    pdf_url TEXT,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'APPROVED', 'SENT', 'PAID')),
    
    -- Email for sending invoice
    broker_email TEXT,
    sent_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_detention_invoices_org ON public.detention_invoices(organization_id);
CREATE INDEX IF NOT EXISTS idx_detention_invoices_load ON public.detention_invoices(load_id);
CREATE INDEX IF NOT EXISTS idx_detention_invoices_record ON public.detention_invoices(detention_record_id);

-- Enable RLS
ALTER TABLE public.detention_invoices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for detention_invoices
CREATE POLICY "Users can view detention invoices in their organization"
    ON public.detention_invoices FOR SELECT
    USING (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can insert detention invoices in their organization"
    ON public.detention_invoices FOR INSERT
    WITH CHECK (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can update detention invoices in their organization"
    ON public.detention_invoices FOR UPDATE
    USING (organization_id = public.get_user_organization_id());

CREATE POLICY "Users can delete detention invoices in their organization"
    ON public.detention_invoices FOR DELETE
    USING (organization_id = public.get_user_organization_id());

-- Comment for documentation
COMMENT ON TABLE public.detention_invoices IS 'Stores finalized detention invoices with calculated charges and PDF links.';

-- ================================================
-- Trigger for updated_at
-- ================================================
CREATE OR REPLACE FUNCTION public.update_detention_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER detention_records_updated_at
    BEFORE UPDATE ON public.detention_records
    FOR EACH ROW
    EXECUTE FUNCTION public.update_detention_updated_at();

CREATE TRIGGER detention_invoices_updated_at
    BEFORE UPDATE ON public.detention_invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.update_detention_updated_at();

-- ================================================
-- Grant permissions for service role and authenticated users
-- ================================================
GRANT ALL ON public.detention_records TO authenticated;
GRANT ALL ON public.detention_records TO service_role;
GRANT ALL ON public.detention_invoices TO authenticated;
GRANT ALL ON public.detention_invoices TO service_role;

-- Verification query (run after migration)
-- SELECT 'detention_records' as table_name, count(*) as row_count FROM detention_records
-- UNION ALL
-- SELECT 'detention_invoices', count(*) FROM detention_invoices;

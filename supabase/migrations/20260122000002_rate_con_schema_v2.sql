-- Rate Confirmation Schema v2
-- Normalized schema with one-to-many relationships for stops, charges, references, and risk clauses

-- ============================================
-- ENUMS
-- ============================================

-- Stop type enum
DO $$ BEGIN
    CREATE TYPE stop_type_enum AS ENUM ('Pickup', 'Delivery');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Traffic light status (if not exists)
DO $$ BEGIN
    CREATE TYPE traffic_light_status AS ENUM ('RED', 'YELLOW', 'GREEN');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Trigger type for notifications
DO $$ BEGIN
    CREATE TYPE trigger_type_enum AS ENUM ('Absolute', 'Relative', 'Conditional');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Notification event types
DO $$ BEGIN
    CREATE TYPE notification_event_enum AS ENUM (
        'Before Contract signature',
        'Daily Check Call',
        'Status',
        'Detention Start',
        'Delivery Delay',
        'Delivery Done',
        'Pickup Delay',
        'Pickup Done',
        'Other'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- DROP OLD TABLES (CASCADE to handle dependencies)
-- ============================================

DROP TABLE IF EXISTS public.rate_con_clauses CASCADE;
DROP TABLE IF EXISTS public.rate_cons CASCADE;

-- ============================================
-- CREATE NEW TABLES
-- ============================================

-- Rate Confirmations (Main Table)
CREATE TABLE public.rate_confirmations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- External ID (not unique - same rate con can be processed multiple times)
    rate_con_id VARCHAR(50) NOT NULL,
    
    -- Foreign Keys
    document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Broker Details (Denormalized for snapshotting contract state)
    broker_name VARCHAR(255),
    broker_mc_number VARCHAR(50),
    broker_address TEXT,
    broker_phone VARCHAR(50),
    broker_email VARCHAR(255),
    
    -- Carrier Details
    carrier_name VARCHAR(255),
    carrier_dot_number VARCHAR(50),
    carrier_address TEXT,
    carrier_phone VARCHAR(50),
    carrier_email VARCHAR(255),
    carrier_equipment_type VARCHAR(100),
    carrier_equipment_number VARCHAR(50),
    
    -- Financial Overview
    total_rate_amount DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    payment_terms TEXT,
    
    -- Commodity Snapshot (1:1 relationship based on JSON)
    commodity_name VARCHAR(255),
    commodity_weight DECIMAL(10, 2),
    commodity_unit VARCHAR(20),
    pallet_count INT,
    
    -- Overall Risk
    overall_traffic_light traffic_light_status,
    
    -- Status for review workflow
    status VARCHAR(20) DEFAULT 'under_review',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Reference Numbers (One-to-Many)
-- Captures POs, BOLs, SOs associated with the load
CREATE TABLE public.reference_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_confirmation_id UUID NOT NULL REFERENCES public.rate_confirmations(id) ON DELETE CASCADE,
    ref_type VARCHAR(50),  -- e.g., "PO", "BOL", "Load Number"
    ref_value VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Stops (One-to-Many)
-- Ordered sequence of pickups and deliveries
CREATE TABLE public.stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_confirmation_id UUID NOT NULL REFERENCES public.rate_confirmations(id) ON DELETE CASCADE,
    sequence_number INT NOT NULL,  -- To maintain order (Pickup = 1, Delivery = last)
    stop_type stop_type_enum NOT NULL,
    address TEXT,
    contact_person VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    
    -- Scheduling
    scheduled_arrival TIMESTAMPTZ,
    scheduled_departure TIMESTAMPTZ,
    date_raw VARCHAR(50),  -- Retain original string if parsing fails
    time_raw VARCHAR(50),  -- Retain original string if parsing fails
    special_instructions TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Charges/Line Items (One-to-Many)
-- Breakdowns of Fuel, Line Haul, Lumper fees, etc.
CREATE TABLE public.charges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_confirmation_id UUID NOT NULL REFERENCES public.rate_confirmations(id) ON DELETE CASCADE,
    description VARCHAR(255),
    amount DECIMAL(10, 2),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Risk Analysis Clauses (One-to-Many)
-- Stores the specific clauses identified as dangerous
CREATE TABLE public.risk_clauses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_confirmation_id UUID NOT NULL REFERENCES public.rate_confirmations(id) ON DELETE CASCADE,
    clause_type VARCHAR(50),  -- Payment, Detention, Fines, etc.
    traffic_light traffic_light_status NOT NULL,
    
    -- Titles and Translations
    clause_title VARCHAR(255),
    clause_title_punjabi TEXT,  -- UTF-8 support required
    
    -- Explanations
    danger_simple_language TEXT,
    danger_simple_punjabi TEXT,
    
    -- The raw text for legal verification
    original_text TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Clause Notifications (One-to-One with Risk Clauses)
-- Machine-readable rules for triggering alerts
CREATE TABLE public.clause_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    risk_clause_id UUID NOT NULL REFERENCES public.risk_clauses(id) ON DELETE CASCADE,
    title VARCHAR(100),
    description TEXT,
    
    -- Trigger Logic
    trigger_type trigger_type_enum,
    start_event notification_event_enum,
    
    -- Timing Constraints
    deadline_iso TIMESTAMPTZ,  -- For "Absolute" triggers
    relative_minutes_offset INT,  -- For "Relative" triggers (e.g., -30 for 30 mins before)
    
    original_clause_excerpt TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_rate_confirmations_rate_con_id ON public.rate_confirmations(rate_con_id);
CREATE INDEX idx_rate_confirmations_org ON public.rate_confirmations(organization_id);
CREATE INDEX idx_rate_confirmations_doc ON public.rate_confirmations(document_id);
CREATE INDEX idx_reference_numbers_rate_con ON public.reference_numbers(rate_confirmation_id);
CREATE INDEX idx_stops_rate_con ON public.stops(rate_confirmation_id);
CREATE INDEX idx_stops_sequence ON public.stops(rate_confirmation_id, sequence_number);
CREATE INDEX idx_charges_rate_con ON public.charges(rate_confirmation_id);
CREATE INDEX idx_risk_clauses_rate_con ON public.risk_clauses(rate_confirmation_id);
CREATE INDEX idx_clause_notifications_risk_clause ON public.clause_notifications(risk_clause_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.rate_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reference_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_clauses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clause_notifications ENABLE ROW LEVEL SECURITY;

-- Rate Confirmations - Users can access their org's rate confirmations
CREATE POLICY "Users can access own org rate confirmations"
    ON public.rate_confirmations
    FOR ALL
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM public.profiles 
            WHERE id = auth.uid()
        )
    )
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM public.profiles 
            WHERE id = auth.uid()
        )
    );

-- Reference Numbers - Access through rate_confirmation
CREATE POLICY "Users can access own org reference numbers"
    ON public.reference_numbers
    FOR ALL
    USING (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    )
    WITH CHECK (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );

-- Stops - Access through rate_confirmation
CREATE POLICY "Users can access own org stops"
    ON public.stops
    FOR ALL
    USING (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    )
    WITH CHECK (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );

-- Charges - Access through rate_confirmation
CREATE POLICY "Users can access own org charges"
    ON public.charges
    FOR ALL
    USING (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    )
    WITH CHECK (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );

-- Risk Clauses - Access through rate_confirmation
CREATE POLICY "Users can access own org risk clauses"
    ON public.risk_clauses
    FOR ALL
    USING (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    )
    WITH CHECK (
        rate_confirmation_id IN (
            SELECT id FROM public.rate_confirmations
            WHERE organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );

-- Clause Notifications - Access through risk_clause -> rate_confirmation
CREATE POLICY "Users can access own org clause notifications"
    ON public.clause_notifications
    FOR ALL
    USING (
        risk_clause_id IN (
            SELECT rc.id FROM public.risk_clauses rc
            JOIN public.rate_confirmations r ON rc.rate_confirmation_id = r.id
            WHERE r.organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    )
    WITH CHECK (
        risk_clause_id IN (
            SELECT rc.id FROM public.risk_clauses rc
            JOIN public.rate_confirmations r ON rc.rate_confirmation_id = r.id
            WHERE r.organization_id IN (
                SELECT organization_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );

-- ============================================
-- GRANTS
-- ============================================

GRANT ALL ON TABLE public.rate_confirmations TO authenticated;
GRANT ALL ON TABLE public.rate_confirmations TO service_role;

GRANT ALL ON TABLE public.reference_numbers TO authenticated;
GRANT ALL ON TABLE public.reference_numbers TO service_role;

GRANT ALL ON TABLE public.stops TO authenticated;
GRANT ALL ON TABLE public.stops TO service_role;

GRANT ALL ON TABLE public.charges TO authenticated;
GRANT ALL ON TABLE public.charges TO service_role;

GRANT ALL ON TABLE public.risk_clauses TO authenticated;
GRANT ALL ON TABLE public.risk_clauses TO service_role;

GRANT ALL ON TABLE public.clause_notifications TO authenticated;
GRANT ALL ON TABLE public.clause_notifications TO service_role;

-- ============================================
-- TRIGGER FOR updated_at
-- ============================================

CREATE TRIGGER update_rate_confirmations_updated_at 
    BEFORE UPDATE ON public.rate_confirmations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

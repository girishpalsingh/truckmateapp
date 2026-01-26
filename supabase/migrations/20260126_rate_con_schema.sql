-- Drop existing tables (Reverse Order of Dependencies)
DROP TABLE IF EXISTS rate_con_dispatcher_instructions CASCADE;
DROP TABLE IF EXISTS clause_notifications CASCADE;
DROP TABLE IF EXISTS risk_clauses CASCADE;
DROP TABLE IF EXISTS charges CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS reference_numbers CASCADE;
DROP TABLE IF EXISTS rate_confirmations CASCADE;
DROP TABLE IF EXISTS rc_notifications CASCADE;
DROP TABLE IF EXISTS rc_risk_clauses CASCADE;
DROP TABLE IF EXISTS rc_commodities CASCADE;
DROP TABLE IF EXISTS rc_stops CASCADE;
DROP TABLE IF EXISTS rc_charges CASCADE;
DROP TABLE IF EXISTS rc_references CASCADE;
DROP TABLE IF EXISTS rc_dispatch_instructions CASCADE;

-- 1. Rate Confirmations (Hub)
CREATE TABLE rate_confirmations (
    rc_id SERIAL PRIMARY KEY,
    id UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    load_id VARCHAR(50) NOT NULL,
    
    broker_name VARCHAR(255),
    broker_mc VARCHAR(50),
    broker_address TEXT,
    broker_phone VARCHAR(50),
    broker_email VARCHAR(255),
    
    carrier_name VARCHAR(255),
    carrier_dot VARCHAR(50),
    carrier_equipment_type VARCHAR(100),
    carrier_equipment_number VARCHAR(100),
    
    total_rate DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    payment_terms VARCHAR(100),

    risk_score VARCHAR(10) CHECK (risk_score IN ('RED', 'YELLOW', 'GREEN', 'UNKNOWN')),
    status VARCHAR(50) DEFAULT 'under_review',
    
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    UNIQUE(organization_id, load_id)
);

-- 2. RC References
CREATE TABLE rc_references (
    ref_id SERIAL PRIMARY KEY,
    rc_id INT REFERENCES rate_confirmations(rc_id) ON DELETE CASCADE,
    rate_confirmation_id UUID REFERENCES rate_confirmations(id) ON DELETE CASCADE,
    ref_type VARCHAR(50),
    ref_value VARCHAR(100)
);

-- 3. RC Charges
CREATE TABLE rc_charges (
    charge_id SERIAL PRIMARY KEY,
    rc_id INT REFERENCES rate_confirmations(rc_id) ON DELETE CASCADE,
    rate_confirmation_id UUID REFERENCES rate_confirmations(id) ON DELETE CASCADE,
    description VARCHAR(255),
    amount DECIMAL(10, 2)
);

-- 4. RC Stops
CREATE TABLE rc_stops (
    stop_id SERIAL PRIMARY KEY,
    rc_id INT REFERENCES rate_confirmations(rc_id) ON DELETE CASCADE,
    rate_confirmation_id UUID REFERENCES rate_confirmations(id) ON DELETE CASCADE,
    
    stop_sequence INT NOT NULL,
    stop_type VARCHAR(20) CHECK (stop_type IN ('Pickup', 'Delivery')),
    
    facility_address TEXT,
    contact_name VARCHAR(100),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    
    raw_date_text VARCHAR(100),
    scheduled_arrival TIMESTAMP WITH TIME ZONE,
    scheduled_departure TIMESTAMP WITH TIME ZONE,
    
    special_instructions TEXT
);

-- 5. RC Commodities
CREATE TABLE rc_commodities (
    comm_id SERIAL PRIMARY KEY,
    stop_id INT REFERENCES rc_stops(stop_id) ON DELETE CASCADE,
    
    description TEXT,
    weight_lbs DECIMAL(10, 2),
    quantity INT,
    unit_type VARCHAR(50),
    is_hazmat BOOLEAN DEFAULT FALSE,
    temp_req VARCHAR(50)
);

-- 6. RC Risk Clauses
CREATE TABLE rc_risk_clauses (
    clause_id SERIAL PRIMARY KEY,
    rc_id INT REFERENCES rate_confirmations(rc_id) ON DELETE CASCADE,
    rate_confirmation_id UUID REFERENCES rate_confirmations(id) ON DELETE CASCADE,
    
    traffic_light VARCHAR(10) CHECK (traffic_light IN ('RED', 'YELLOW', 'GREEN')),
    clause_type VARCHAR(50),
    
    title_en VARCHAR(255),
    title_punjabi TEXT,
    
    explanation_en TEXT,
    explanation_punjabi TEXT,
    
    original_text TEXT
);

-- 7. RC Notifications
CREATE TABLE rc_notifications (
    notif_id SERIAL PRIMARY KEY,
    clause_id INT REFERENCES rc_risk_clauses(clause_id) ON DELETE CASCADE,
    
    title VARCHAR(100),
    description TEXT,
    
    trigger_type VARCHAR(20) CHECK (trigger_type IN ('Absolute', 'Relative', 'Conditional')),
    start_event VARCHAR(50),
    
    deadline_date DATE,
    relative_offset_minutes INT
);

-- 8. RC Dispatch Instructions
CREATE TABLE rc_dispatch_instructions (
    dispatch_id SERIAL PRIMARY KEY,
    rc_id INT REFERENCES rate_confirmations(rc_id) ON DELETE CASCADE,
    rate_confirmation_id UUID REFERENCES rate_confirmations(id) ON DELETE CASCADE,
    
    pickup_summary TEXT,
    delivery_summary TEXT,
    
    transit_reqs_en JSONB, 
    transit_reqs_punjabi JSONB,
    special_equip_en JSONB, 
    special_equip_punjabi JSONB,
    
    action_items JSONB
);

-- Enable RLS
ALTER TABLE rate_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_commodities ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_risk_clauses ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE rc_dispatch_instructions ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- 1. Rate Confirmations Policy
CREATE POLICY "Users can access org rate cons" ON rate_confirmations
    FOR ALL
    USING (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
    );

-- Child Tables Policies (Inherit from parent via EXISTS)

-- rc_references
CREATE POLICY "Inherit RC Org Policy" ON rc_references
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.rc_id = rc_references.rc_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_charges
CREATE POLICY "Inherit RC Org Policy" ON rc_charges
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.rc_id = rc_charges.rc_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_stops
CREATE POLICY "Inherit RC Org Policy" ON rc_stops
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.rc_id = rc_stops.rc_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_commodities (Grandchild)
CREATE POLICY "Inherit Stop Org Policy" ON rc_commodities
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rc_stops s
            JOIN rate_confirmations rc ON s.rc_id = rc.rc_id
            WHERE s.stop_id = rc_commodities.stop_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_risk_clauses
CREATE POLICY "Inherit RC Org Policy" ON rc_risk_clauses
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.rc_id = rc_risk_clauses.rc_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_notifications (Grandchild)
CREATE POLICY "Inherit Clause Org Policy" ON rc_notifications
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rc_risk_clauses c
            JOIN rate_confirmations rc ON c.rc_id = rc.rc_id
            WHERE c.clause_id = rc_notifications.clause_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- rc_dispatch_instructions
CREATE POLICY "Inherit RC Org Policy" ON rc_dispatch_instructions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.rc_id = rc_dispatch_instructions.rc_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- Triggers
CREATE TRIGGER update_rate_confirmations_updated_at BEFORE UPDATE ON rate_confirmations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Restore FK on loads table (dropped by CASCADE)
ALTER TABLE loads 
    ADD CONSTRAINT fk_loads_rate_confirmation 
    FOREIGN KEY (rate_confirmation_id) 
    REFERENCES rate_confirmations(id) 
    ON DELETE SET NULL;


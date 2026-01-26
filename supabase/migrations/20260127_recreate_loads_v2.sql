-- Recreate Loads Table
-- Dropping existing table to match new schema definition strictly
DROP TABLE IF EXISTS loads CASCADE;

CREATE TABLE loads (
    load_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Link to the source of truth (The PDF)
    -- Referencing the internal SERIAL ID of rate_confirmations as requested
    active_rate_con_id INT REFERENCES rate_confirmations(rc_id) ON DELETE SET NULL,
    
    -- Internal Status Workflow
    status VARCHAR(20) DEFAULT 'BOOKED' 
        CHECK (status IN ('BOOKED', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'INVOICED', 'PAID')),
    
    -- Money (The "Final" numbers after disputes)
    final_revenue DECIMAL(10,2), 
    invoice_date DATE,
    payment_status VARCHAR(20),
    
    -- Who owns this job internally?
    dispatcher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE loads ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- "only organization manager, owner and dispatcher able to operate on it"

CREATE POLICY "Managers, Owners and Dispatchers can access loads" ON loads
    FOR ALL
    USING (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        AND (
            SELECT role FROM profiles WHERE id = auth.uid()
        ) IN ('owner', 'manager', 'dispatcher')
    )
    WITH CHECK (
        organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        AND (
            SELECT role FROM profiles WHERE id = auth.uid()
        ) IN ('owner', 'manager', 'dispatcher')
    );

-- Trigger for updated_at
CREATE TRIGGER update_loads_updated_at BEFORE UPDATE ON loads FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

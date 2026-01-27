-- Remove duplicate Foreign Keys (rc_id) and update RLS policies to use UUID

-- 1. rc_references
DROP POLICY IF EXISTS "Inherit RC Org Policy" ON rc_references;
ALTER TABLE rc_references DROP COLUMN IF EXISTS rc_id;

CREATE POLICY "Inherit RC Org Policy" ON rc_references
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.id = rc_references.rate_confirmation_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- 2. rc_charges
DROP POLICY IF EXISTS "Inherit RC Org Policy" ON rc_charges;
ALTER TABLE rc_charges DROP COLUMN IF EXISTS rc_id;

CREATE POLICY "Inherit RC Org Policy" ON rc_charges
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.id = rc_charges.rate_confirmation_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- 3. rc_stops
DROP POLICY IF EXISTS "Inherit RC Org Policy" ON rc_stops;
-- rc_commodities depends on rc_stops, so we need to update its policy too if it relied on the broken join, 
-- but wait, rc_commodities connects to rc_stops via stop_id. 
-- However, the policy logic for rc_commodities likely joined rc_stops to rate_confirmations via rc_id.
-- So we must drop and recreate rc_commodities policy too.
DROP POLICY IF EXISTS "Inherit Stop Org Policy" ON rc_commodities;

ALTER TABLE rc_stops DROP COLUMN IF EXISTS rc_id;

CREATE POLICY "Inherit RC Org Policy" ON rc_stops
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.id = rc_stops.rate_confirmation_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

CREATE POLICY "Inherit Stop Org Policy" ON rc_commodities
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rc_stops s
            JOIN rate_confirmations rc ON s.rate_confirmation_id = rc.id
            WHERE s.stop_id = rc_commodities.stop_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- 4. rc_risk_clauses
DROP POLICY IF EXISTS "Inherit RC Org Policy" ON rc_risk_clauses;
-- rc_notifications depends on rc_risk_clauses
DROP POLICY IF EXISTS "Inherit Clause Org Policy" ON rc_notifications;

ALTER TABLE rc_risk_clauses DROP COLUMN IF EXISTS rc_id;

CREATE POLICY "Inherit RC Org Policy" ON rc_risk_clauses
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.id = rc_risk_clauses.rate_confirmation_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

CREATE POLICY "Inherit Clause Org Policy" ON rc_notifications
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rc_risk_clauses c
            JOIN rate_confirmations rc ON c.rate_confirmation_id = rc.id
            WHERE c.clause_id = rc_notifications.clause_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- 5. rc_dispatch_instructions
DROP POLICY IF EXISTS "Inherit RC Org Policy" ON rc_dispatch_instructions;
ALTER TABLE rc_dispatch_instructions DROP COLUMN IF EXISTS rc_id;

CREATE POLICY "Inherit RC Org Policy" ON rc_dispatch_instructions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rate_confirmations rc
            WHERE rc.id = rc_dispatch_instructions.rate_confirmation_id
            AND rc.organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
        )
    );

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

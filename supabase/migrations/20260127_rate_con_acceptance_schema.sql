-- Create load_statuses table
CREATE TABLE IF NOT EXISTS load_statuses (
    code VARCHAR(20) PRIMARY KEY,
    description TEXT
);

-- Insert default statuses
INSERT INTO load_statuses (code, description) VALUES
    ('created', 'Load is created but not assigned'),
    ('assigned', 'Load is assigned to a driver/truck'),
    ('dispatched', 'Driver has been dispatched'),
    ('at_pickup', 'Driver arrived at pickup'),
    ('in_transit', 'Cargo is in transit'),
    ('at_delivery', 'Driver arrived at delivery'),
    ('delivered', 'Load has been delivered'),
    ('invoiced', 'Invoice has been generated'),
    ('cancelled', 'Load was cancelled'),
    ('TONU', 'Truck Ordered Not Used');

-- Modify loads table
-- First, drop the existing check constraint on status if it exists
DO $$ 
BEGIN 
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'loads_status_check'
    ) THEN 
        ALTER TABLE loads DROP CONSTRAINT loads_status_check;
    END IF; 
END $$;

-- Update loads table structure
ALTER TABLE loads
    ADD COLUMN IF NOT EXISTS broker_name TEXT,
    ADD COLUMN IF NOT EXISTS broker_load_id TEXT,
    ADD COLUMN IF NOT EXISTS primary_rate DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS fuel_surcharge DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS total_rate DECIMAL(10,2);

-- Since we are changing status to be FK, we should ensure existing values match or are updated.
-- Assuming existing status was uppercase BOOKED, DISPATCHED, etc. mapping them to lowercase if needed or update load_statuses to include uppercase.
-- The verification step showed "BOOKED", "DISPATCHED" etc in the check constraint.
-- Let's insert those into load_statuses as well or migrate data. 
-- User requirement said "created, assigned, dispatched..." (lowercase).
-- Let's Map existing statuses to new ones if any.
-- For now, I will add the UPPERCASE ones to load_statuses to be safe for existing data, 
-- but the new app logic will use lowercase.
INSERT INTO load_statuses (code, description) VALUES
    ('BOOKED', 'Legacy: Booked'),
    ('DISPATCHED', 'Legacy: Dispatched'),
    ('IN_TRANSIT', 'Legacy: In Transit'),
    ('DELIVERED', 'Legacy: Delivered'),
    ('INVOICED', 'Legacy: Invoiced'),
    ('PAID', 'Legacy: Paid')
ON CONFLICT (code) DO NOTHING;


-- Now add FK constraint
-- We need to make sure all current statuses in `loads` exist in `load_statuses`.
-- If there are any that don't, this will fail. Use a safe update first if paranoid, but for dev we assume consistency or empty table.
ALTER TABLE loads
    ADD CONSTRAINT fk_loads_status FOREIGN KEY (status) REFERENCES load_statuses(code);

-- Enable RLS on new table
ALTER TABLE load_statuses ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users for load_statuses
CREATE POLICY "Authenticated users can read load_statuses" ON load_statuses
    FOR SELECT
    TO authenticated
    USING (true);

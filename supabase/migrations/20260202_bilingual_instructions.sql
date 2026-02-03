-- Add Punjabi columns to rc_stops
ALTER TABLE rc_stops 
ADD COLUMN IF NOT EXISTS special_instructions_punjabi TEXT;

-- Add Punjabi columns to rc_dispatch_instructions
ALTER TABLE rc_dispatch_instructions 
ADD COLUMN IF NOT EXISTS pickup_summary_punjabi TEXT,
ADD COLUMN IF NOT EXISTS delivery_summary_punjabi TEXT;

-- TruckMate Seed Data for Development
-- This seeds a sample organization with drivers, trucks, and trips

-- Insert sample organization
INSERT INTO organizations (id, name, legal_entity_name, mc_dot_number, tax_id, llm_provider, approval_email_address)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Highway Heroes Trucking',
  'Highway Heroes Trucking LLC',
  'MC-123456',
  '12-3456789',
  'gemini',
  'invoices@highwayherostrucking.com'
);

-- Insert sample trucks
INSERT INTO trucks (id, organization_id, truck_number, make, model, year, current_odometer)
VALUES 
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'TRK-001', 'Peterbilt', '579', 2023, 125000),
  ('22222222-2222-2222-2222-222222222223', '11111111-1111-1111-1111-111111111111', 'TRK-002', 'Kenworth', 'T680', 2022, 187500),
  ('22222222-2222-2222-2222-222222222224', '11111111-1111-1111-1111-111111111111', 'TRK-003', 'Freightliner', 'Cascadia', 2024, 45000);

-- Note: Profiles are linked to auth.users, so they need to be created after users sign up
-- For development, we'll create placeholder entries that will be linked when users authenticate

-- Insert sample loads
INSERT INTO loads (id, organization_id, broker_name, broker_mc_number, broker_load_id, primary_rate, fuel_surcharge, detention_policy_hours, detention_rate_per_hour, commodity_type, weight_lbs, status)
VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'ABC Logistics', 'MC-789012', 'LOAD-2026-001', 3500.00, 250.00, 2, 75.00, 'Electronics', 42000, 'assigned'),
  ('33333333-3333-3333-3333-333333333334', '11111111-1111-1111-1111-111111111111', 'XYZ Freight', 'MC-345678', 'LOAD-2026-002', 2800.00, 180.00, 2, 50.00, 'Furniture', 38000, 'picked_up'),
  ('33333333-3333-3333-3333-333333333335', '11111111-1111-1111-1111-111111111111', 'FastHaul Inc', 'MC-901234', 'LOAD-2026-003', 4200.00, 320.00, 3, 100.00, 'Machinery', 44000, 'delivered');

-- Insert sample trips (without driver_id since no users exist yet)
INSERT INTO trips (id, organization_id, load_id, truck_id, origin_address, destination_address, odometer_start, odometer_end, status)
VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333335', '22222222-2222-2222-2222-222222222222', 'Los Angeles, CA', 'Phoenix, AZ', 124500, 124870, 'completed'),
  ('44444444-4444-4444-4444-444444444445', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333334', '22222222-2222-2222-2222-222222222223', 'Seattle, WA', 'Portland, OR', 187000, NULL, 'active'),
  ('44444444-4444-4444-4444-444444444446', '11111111-1111-1111-1111-111111111111', NULL, '22222222-2222-2222-2222-222222222224', 'Denver, CO', 'Salt Lake City, UT', 44500, NULL, 'deadhead');

-- Insert sample expenses
INSERT INTO expenses (id, organization_id, trip_id, category, amount, vendor_name, jurisdiction, gallons, date)
VALUES
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'fuel', 485.50, 'Pilot Flying J', 'CA', 125.0, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555556', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'fuel', 320.25, 'Love''s Travel Stop', 'AZ', 85.5, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555557', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'tolls', 45.00, 'Arizona DOT', 'AZ', NULL, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555558', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', 'fuel', 550.00, 'TA Petro', 'WA', 140.0, '2026-01-18'),
  ('55555555-5555-5555-5555-555555555559', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', 'food', 28.50, 'Denny''s', 'WA', NULL, '2026-01-18');

-- Insert sample documents (references to storage, actual files would be uploaded separately)
INSERT INTO documents (id, organization_id, trip_id, load_id, type, image_url, status, ai_data)
VALUES
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333335', 'rate_con', 'documents/rate_con_sample.pdf', 'approved', '{"broker_name": "FastHaul Inc", "rate": 4200, "pickup": "Los Angeles, CA", "delivery": "Phoenix, AZ"}'),
  ('66666666-6666-6666-6666-666666666667', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', NULL, 'fuel_receipt', 'documents/fuel_receipt_1.jpg', 'approved', '{"vendor": "Pilot Flying J", "amount": 485.50, "gallons": 125.0, "state": "CA"}'),
  ('66666666-6666-6666-6666-666666666668', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', '33333333-3333-3333-3333-333333333334', 'bol', 'documents/bol_sample.pdf', 'pending_review', NULL);

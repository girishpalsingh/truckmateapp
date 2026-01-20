-- TruckMate Seed Data for Development
-- This seeds a sample organization with drivers, trucks, and trips

-- ============================================
-- 1. ORGANIZATIONS
-- ============================================
INSERT INTO organizations (id, name, legal_entity_name, mc_dot_number, tax_id, llm_provider, approval_email_address)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Highway Heroes Trucking', 'Highway Heroes Trucking LLC', 'MC-123456', '12-3456789', 'gemini', 'invoices@highwayherostrucking.com'),
  ('11111111-1111-1111-1111-111111111112', 'Pacific Coast Freight', 'Pacific Coast Freight Inc', 'MC-234567', '23-4567890', 'gemini', 'invoices@pacificcoastfreight.com')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2. AUTH USERS (Supabase Auth)
-- Password for all dev users: DevPassword123!
-- ============================================
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at, 
  created_at, updated_at, aud, role, raw_app_meta_data, raw_user_meta_data, is_super_admin
)
VALUES 
  -- User 1: Driver 1 (Highway Heroes)
  (
    '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'dev.driver1@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+15551234567', now(), 
    now(), now(), 'authenticated', 'authenticated', '{"provider": "phone", "providers": ["phone"]}', '{"full_name": "Harpreet Singh", "role": "driver"}', false
  ),
  -- User 2: Driver 2 (Highway Heroes)
  (
    '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'dev.driver2@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+15559876543', now(), 
    now(), now(), 'authenticated', 'authenticated', '{"provider": "phone", "providers": ["phone"]}', '{"full_name": "Balwinder Singh", "role": "driver"}', false
  ),
  -- User 3: Admin (Highway Heroes)
  (
    '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'dev.admin@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+15550001111', now(), 
    now(), now(), 'authenticated', 'authenticated', '{"provider": "email", "providers": ["email"]}', '{"full_name": "Admin User", "role": "orgadmin"}', false
  ),
  -- User 4: Driver 3 (Pacific Coast) - TEST USER
  (
    '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'dev.driver3@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+11234567890', now(), 
    now(), now(), 'authenticated', 'authenticated', '{"provider": "phone", "providers": ["phone"]}', '{"full_name": "Test User", "role": "driver"}', false
  ),
  -- User 5: System Admin (no organization - global admin)
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'systemadmin@truckmate.app', crypt('SystemAdmin123!', gen_salt('bf')), now(), '+15550000000', now(), 
    now(), now(), 'authenticated', 'authenticated', '{"provider": "email", "providers": ["email"]}', '{"full_name": "System Admin", "role": "systemadmin"}', false
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 3. AUTH IDENTITIES
-- ============================================
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"sub": "00000000-0000-0000-0000-000000000001", "phone": "+15551234567"}', 'phone', '+15551234567', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '{"sub": "00000000-0000-0000-0000-000000000002", "phone": "+15559876543"}', 'phone', '+15559876543', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', '{"sub": "00000000-0000-0000-0000-000000000003", "email": "dev.admin@truckmate.app"}', 'email', 'dev.admin@truckmate.app', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', '{"sub": "00000000-0000-0000-0000-000000000004", "phone": "+11234567890"}', 'phone', '+11234567890', now(), now(), now()),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '{"sub": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "email": "systemadmin@truckmate.app"}', 'email', 'systemadmin@truckmate.app', now(), now(), now())
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 4. PROFILES
-- ============================================
INSERT INTO profiles (id, organization_id, full_name, phone_number, email_address, role)
VALUES 
  ('00000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Harpreet Singh', '+15551234567', 'dev.driver1@truckmate.app', 'driver'),
  ('00000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Balwinder Singh', '+15559876543', 'dev.driver2@truckmate.app', 'driver'),
  ('00000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Admin User', '+15550001111', 'dev.admin@truckmate.app', 'orgadmin'),
  ('00000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111112', 'Test User', '+11234567890', 'dev.driver3@truckmate.app', 'driver'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'System Admin', '+15550000000', 'systemadmin@truckmate.app', 'systemadmin')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. TRUCKS
-- ============================================
INSERT INTO trucks (id, organization_id, truck_number, make, model, year, current_odometer)
VALUES 
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'TRK-001', 'Peterbilt', '579', 2023, 125000),
  ('22222222-2222-2222-2222-222222222223', '11111111-1111-1111-1111-111111111111', 'TRK-002', 'Kenworth', 'T680', 2022, 187500),
  ('22222222-2222-2222-2222-222222222224', '11111111-1111-1111-1111-111111111111', 'TRK-003', 'Freightliner', 'Cascadia', 2024, 45000)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 6. LOADS
-- ============================================
INSERT INTO loads (id, organization_id, broker_name, broker_mc_number, broker_load_id, primary_rate, fuel_surcharge, detention_policy_hours, detention_rate_per_hour, commodity_type, weight_lbs, status)
VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'ABC Logistics', 'MC-789012', 'LOAD-2026-001', 3500.00, 250.00, 2, 75.00, 'Electronics', 42000, 'assigned'),
  ('33333333-3333-3333-3333-333333333334', '11111111-1111-1111-1111-111111111111', 'XYZ Freight', 'MC-345678', 'LOAD-2026-002', 2800.00, 180.00, 2, 50.00, 'Furniture', 38000, 'picked_up'),
  ('33333333-3333-3333-3333-333333333335', '11111111-1111-1111-1111-111111111111', 'FastHaul Inc', 'MC-901234', 'LOAD-2026-003', 4200.00, 320.00, 3, 100.00, 'Machinery', 44000, 'delivered')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 7. TRIPS
-- ============================================
INSERT INTO trips (id, organization_id, driver_id, load_id, truck_id, origin_address, destination_address, odometer_start, odometer_end, status)
VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333335', '22222222-2222-2222-2222-222222222222', 'Los Angeles, CA', 'Phoenix, AZ', 124500, 124870, 'completed'),
  ('44444444-4444-4444-4444-444444444445', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333334', '22222222-2222-2222-2222-222222222223', 'Seattle, WA', 'Portland, OR', 187000, NULL, 'active'),
  ('44444444-4444-4444-4444-444444444446', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', NULL, '22222222-2222-2222-2222-222222222224', 'Denver, CO', 'Salt Lake City, UT', 44500, NULL, 'deadhead')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 8. EXPENSES
-- ============================================
INSERT INTO expenses (id, organization_id, trip_id, category, amount, vendor_name, jurisdiction, gallons, date)
VALUES
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'fuel', 485.50, 'Pilot Flying J', 'CA', 125.0, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555556', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'fuel', 320.25, 'Love''s Travel Stop', 'AZ', 85.5, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555557', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'tolls', 45.00, 'Arizona DOT', 'AZ', NULL, '2026-01-15'),
  ('55555555-5555-5555-5555-555555555558', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', 'fuel', 550.00, 'TA Petro', 'WA', 140.0, '2026-01-18'),
  ('55555555-5555-5555-5555-555555555559', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', 'food', 28.50, 'Denny''s', 'WA', NULL, '2026-01-18')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 9. DOCUMENTS
-- ============================================
INSERT INTO documents (id, organization_id, trip_id, load_id, type, image_url, status, ai_data)
VALUES
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333335', 'rate_con', 'documents/rate_con_sample.pdf', 'approved', '{"broker_name": "FastHaul Inc", "rate": 4200, "pickup": "Los Angeles, CA", "delivery": "Phoenix, AZ"}'),
  ('66666666-6666-6666-6666-666666666667', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', NULL, 'fuel_receipt', 'documents/fuel_receipt_1.jpg', 'approved', '{"vendor": "Pilot Flying J", "amount": 485.50, "gallons": 125.0, "state": "CA"}'),
  ('66666666-6666-6666-6666-666666666668', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444445', '33333333-3333-3333-3333-333333333334', 'bol', 'documents/bol_sample.pdf', 'pending_review', NULL)
ON CONFLICT (id) DO NOTHING;

-- Display seeded dev users for reference
DO $$
BEGIN
  RAISE NOTICE '=== DEV USERS SEEDED ===';
  RAISE NOTICE 'Driver 1: +15551234567 (Harpreet Singh) - OTP: 123456';
  RAISE NOTICE 'Driver 2: +15559876543 (Balwinder Singh) - OTP: 123456';
  RAISE NOTICE 'Driver 3: +11234567890 (Test User) - OTP: 123456';
  RAISE NOTICE 'Admin: dev.admin@truckmate.app - OTP: 123456';
  RAISE NOTICE '========================';
END $$;

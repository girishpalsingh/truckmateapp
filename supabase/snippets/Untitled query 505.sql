-- ENABLE ENCRYPTION
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CREATE DEV USERS
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at, created_at, updated_at, aud, role, raw_app_meta_data, raw_user_meta_data, is_super_admin)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'dev.driver1@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+15551234567', now(), now(), now(), 'authenticated', 'authenticated', '{"provider":"phone"}', '{"full_name":"Harpreet Singh"}', false),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab', '00000000-0000-0000-0000-000000000000', 'dev.driver2@truckmate.app', crypt('DevPassword123!', gen_salt('bf')), now(), '+15559876543', now(), now(), now(), 'authenticated', 'authenticated', '{"provider":"phone"}', '{"full_name":"Balwinder Singh"}', false)
ON CONFLICT (id) DO NOTHING;

-- CREATE IDENTITIES
INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","phone":"+15551234567"}', 'phone', '+15551234567', now(), now(), now()),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab', '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab","phone":"+15559876543"}', 'phone', '+15559876543', now(), now(), now())
ON CONFLICT (id) DO NOTHING;

-- ORGANIZATIONS & PROFILES
INSERT INTO organizations (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Highway Heroes Trucking') ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, organization_id, full_name, phone_number, role)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Harpreet Singh', '+15551234567', 'driver'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab', '11111111-1111-1111-1111-111111111111', 'Balwinder Singh', '+15559876543', 'driver')
ON CONFLICT (id) DO NOTHING;
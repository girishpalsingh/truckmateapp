-- Simple Seed: Create 1 Organization with 20 Users (Phone Auth)
-- Run with: docker exec -i supabase_db_truckmateapp psql -U postgres -d postgres < seed-simple.sql

DO $$
DECLARE
    org_id UUID;
    user_id UUID;
    user_phone TEXT;
    user_name TEXT;
    user_role user_role;
    base_phone BIGINT := 3001234560;
    first_names TEXT[] := ARRAY['James','Maria','David','Sarah','Michael','Jennifer','Robert','Linda','William','Elizabeth','Richard','Patricia','Joseph','Barbara','Thomas','Susan','Christopher','Jessica','Daniel','Karen'];
    last_names TEXT[] := ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'];
    roles user_role[] := ARRAY['orgadmin'::user_role, 'manager'::user_role, 'manager'::user_role, 'dispatcher'::user_role, 'dispatcher'::user_role, 'dispatcher'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role, 'driver'::user_role];
BEGIN
    -- Step 1: Create Organization (database auto-generates ID)
    INSERT INTO organizations (name, legal_entity_name, mc_dot_number, tax_id, llm_provider, approval_email_address)
    VALUES ('Golden Gate Transport', 'Golden Gate Transport LLC', 'MC-555123', '55-1234567', 'gemini', 'invoices@goldengatetransport.com')
    RETURNING id INTO org_id;
    
    RAISE NOTICE '✅ Created organization: Golden Gate Transport';
    RAISE NOTICE '   Organization ID: %', org_id;
    RAISE NOTICE '';
    
    -- Step 2: Create 20 users with phone authentication
    FOR i IN 1..20 LOOP
        user_id := gen_random_uuid();
        user_phone := '+1' || (base_phone + i)::text;
        user_name := first_names[i] || ' ' || last_names[i];
        user_role := roles[i];
        
        -- Insert into auth.users (phone authentication)
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, 
            phone, phone_confirmed_at, 
            created_at, updated_at, aud, role, 
            raw_app_meta_data, raw_user_meta_data, is_super_admin,
            confirmation_token, recovery_token, email_change_token_new,
            email_change_token_current, reauthentication_token, phone_change_token,
            email_change, phone_change, email_change_confirm_status, is_sso_user, is_anonymous
        )
        VALUES (
            user_id, 
            '00000000-0000-0000-0000-000000000000',
            NULL, -- No email for phone-only auth
            NULL, -- No password for phone auth
            user_phone, 
            now(), -- Phone confirmed
            now(), now(), 'authenticated', 'authenticated',
            '{"provider": "phone", "providers": ["phone"]}'::jsonb,
            json_build_object('full_name', user_name, 'role', user_role::text)::jsonb,
            false,
            '', '', '', '', '', '', '', '', 0, false, false
        );
        
        -- Insert identity for phone auth
        INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
        VALUES (
            user_id, user_id,
            json_build_object('sub', user_id::text, 'phone', user_phone)::jsonb,
            'phone', user_phone, now(), now(), now()
        );
        
        -- Insert profile
        INSERT INTO profiles (id, organization_id, full_name, phone_number, role, is_active)
        VALUES (user_id, org_id, user_name, user_phone, user_role, true);
        
        RAISE NOTICE '   👤 User %: % | % | %', i, user_name, user_phone, user_role;
    END LOOP;
    
    -- Update organization admin_id to first user (orgadmin)
    UPDATE organizations SET admin_id = (
        SELECT id FROM profiles WHERE organization_id = org_id AND role = 'orgadmin' LIMIT 1
    ) WHERE id = org_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SEED COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Organization: Golden Gate Transport';
    RAISE NOTICE 'Org ID: %', org_id;
    RAISE NOTICE 'Users created: 20 (phone auth, auto OTP: 123456 in dev)';
    RAISE NOTICE '========================================';
END $$;

-- Show created data
SELECT 'Organization' as type, id::text, name as detail FROM organizations WHERE name = 'Golden Gate Transport'
UNION ALL
SELECT 'Total Users', COUNT(*)::text, '' FROM profiles WHERE organization_id = (SELECT id FROM organizations WHERE name = 'Golden Gate Transport');

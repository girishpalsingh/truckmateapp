-- Mock Fleet Data Seed: Create 20 Trucks, 20 Trailers, and 20 Drivers for ALL Organizations
-- Run with: docker exec -i supabase_db_truckmateapp psql -U postgres -d postgres < mock_fleet_data.sql

DO $$
DECLARE
    org_rec RECORD;
    t_id UUID;
    
    -- Truck variables
    truck_makes TEXT[] := ARRAY['Freightliner', 'Kenworth', 'Peterbilt', 'Volvo', 'International', 'Mack'];
    truck_models TEXT[] := ARRAY['Cascadia', 'T680', '579', 'VNL 860', 'LT Series', 'Anthem'];
    truck_years INT[] := ARRAY[2018, 2019, 2020, 2021, 2022, 2023, 2024];
    t_make TEXT;
    t_model TEXT;
    t_year INT;
    t_vin TEXT;
    
    -- Trailer variables
    trailer_types public.trailer_type_enum[] := ARRAY['DRY_VAN'::public.trailer_type_enum, 'REEFER'::public.trailer_type_enum, 'FLATBED'::public.trailer_type_enum];
    trailer_door_types public.trailer_door_type_enum[] := ARRAY['SWING'::public.trailer_door_type_enum, 'ROLL_UP'::public.trailer_door_type_enum];
    tr_type public.trailer_type_enum;
    tr_door public.trailer_door_type_enum;
    tr_len INT;
    
    -- Driver variables
    user_id UUID;
    user_phone TEXT;
    user_name TEXT;
    user_role user_role := 'driver';
    first_names TEXT[] := ARRAY['James','Maria','David','Sarah','Michael','Jennifer','Robert','Linda','William','Elizabeth','Richard','Patricia','Joseph','Barbara','Thomas','Susan','Christopher','Jessica','Daniel','Karen'];
    last_names TEXT[] := ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'];
    base_phone BIGINT;
    
BEGIN
    RAISE NOTICE 'Starting Mock Fleet Data Seeding...';

    -- Loop through all organizations
    FOR org_rec IN SELECT id, name FROM organizations LOOP
        RAISE NOTICE 'Processing Organization: % (%)', org_rec.name, org_rec.id;
        
        -- Use a unique base phone number based on org ID hash or just random per org to avoid collision if possible.
        -- Ideally, we'd ensure global uniqueness. Let's pick a random start base for the block.
        -- For simplicity in this mock, we'll just increment a global counter or user random bigints.
        -- Let's use a deterministic base derived from loop index would be hard without row_number.
        -- We will just use a random 10-digit base for the batch of drivers to minimize collision chance with existing seed.
        -- Existing seed used 3001234560.
        base_phone := (floor(random() * (9999999999 - 4000000000 + 1) + 4000000000))::BIGINT;
        
        ----------------------------------------------------
        -- 1. Create 20 Trucks
        ----------------------------------------------------
        FOR i IN 1..20 LOOP
            -- Random Attributes
            t_make := truck_makes[1 + floor(random() * array_length(truck_makes, 1))];
            t_model := truck_models[1 + floor(random() * array_length(truck_models, 1))];
            t_year := truck_years[1 + floor(random() * array_length(truck_years, 1))];
            t_vin := md5(random()::text || clock_timestamp()::text); -- Fake VIN
            
            INSERT INTO trucks (
                organization_id,
                truck_number,
                make,
                model,
                year,
                vin,
                license_plate,
                license_plate_state,
                fuel_type,
                current_odometer,
                status,
                availability_status
            ) VALUES (
                org_rec.id,
                'TRK-' || (1000 + i)::text,
                t_make,
                t_model,
                t_year,
                upper(substring(t_vin from 1 for 17)),
                'PLT-' || (1000 + i)::text,
                'CA',
                'DIESEL',
                floor(random() * 500000)::INT,
                'ACTIVE',
                'AVAILABLE'
            );
        END LOOP;
        RAISE NOTICE '   - Created 20 Trucks';

        ----------------------------------------------------
        -- 2. Create 20 Trailers
        ----------------------------------------------------
        FOR i IN 1..20 LOOP
            tr_type := trailer_types[1 + floor(random() * array_length(trailer_types, 1))];
            IF tr_type = 'DRY_VAN' OR tr_type = 'REEFER' THEN
                tr_door := trailer_door_types[1 + floor(random() * array_length(trailer_door_types, 1))];
                tr_len := 53;
            ELSE
                tr_door := NULL;
                tr_len := 48;
            END IF;

            INSERT INTO trailers (
                organization_id,
                trailer_number,
                trailer_type,
                door_type,
                length_feet,
                width_inches,
                height_inches,
                status,
                license_plate,
                license_plate_state
            ) VALUES (
                org_rec.id,
                'TRL-' || (5000 + i)::text,
                tr_type,
                tr_door,
                tr_len,
                102,
                110,
                'ACTIVE',
                'TRL-' || (5000 + i)::text,
                'CA'
            );
        END LOOP;
        RAISE NOTICE '   - Created 20 Trailers';

        ----------------------------------------------------
        -- 3. Create 20 Drivers
        ----------------------------------------------------
        FOR i IN 1..20 LOOP
            user_id := gen_random_uuid();
            user_phone := '+1' || (base_phone + i)::text;
            user_name := first_names[1 + floor(random() * array_length(first_names, 1))] || ' ' || 
                         last_names[1 + floor(random() * array_length(last_names, 1))];
            
            -- Insert into auth.users
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
                NULL, 
                NULL, 
                user_phone, 
                now(), 
                now(), now(), 'authenticated', 'authenticated',
                '{"provider": "phone", "providers": ["phone"]}'::jsonb,
                json_build_object('full_name', user_name, 'role', user_role::text)::jsonb,
                false,
                '', '', '', '', '', '', '', '', 0, false, false
            );
            
            -- Insert into auth.identities
            INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
            VALUES (
                user_id, user_id,
                json_build_object('sub', user_id::text, 'phone', user_phone)::jsonb,
                'phone', user_phone, now(), now(), now()
            );
            
            -- Insert into profiles
            INSERT INTO profiles (id, organization_id, full_name, phone_number, role, is_active)
            VALUES (user_id, org_rec.id, user_name, user_phone, user_role, true)
            ON CONFLICT (id) DO NOTHING; 

        END LOOP;
        RAISE NOTICE '   - Created 20 Drivers';
        
    END LOOP;

    RAISE NOTICE 'Mock Fleet Data Seeding Completed Successfully.';
END $$;

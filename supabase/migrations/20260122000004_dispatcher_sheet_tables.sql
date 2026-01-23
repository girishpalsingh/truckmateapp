-- Dispatcher Sheet Tables Migration
-- Updates trucks, creates trailers, dispatch events, config, facility profiles, assignments, and instructions.

-- ============================================
-- ENUMS
-- ============================================

DO $$ BEGIN
    CREATE TYPE truck_status_enum AS ENUM ('ACTIVE', 'MAINTENANCE', 'SOLD');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE trailer_type_enum AS ENUM ('DRY_VAN', 'REEFER', 'FLATBED', 'STEP_DECK', 'POWER_ONLY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE trailer_status_enum AS ENUM ('ACTIVE', 'MAINTENANCE', 'SOLD');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE trailer_door_type_enum AS ENUM ('SWING', 'ROLL_UP');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE dispatch_event_type_enum AS ENUM ('SHEET_GENERATED', 'SHEET_SENT_APP', 'SHEET_VIEWED', 'ACKNOWLEDGED', 'REFUSED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE dispatch_assignment_status_enum AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- 1. TRUCKS TABLE (Update existing)
-- ============================================
-- Existing columns: id, organization_id, truck_number, make, model, year, vin, license_plate, current_odometer, created_at, updated_at
ALTER TABLE public.trucks 
    ADD COLUMN IF NOT EXISTS license_plate_state VARCHAR(2),
    ADD COLUMN IF NOT EXISTS fuel_type VARCHAR(20) DEFAULT 'DIESEL',
    ADD COLUMN IF NOT EXISTS is_carb_compliant BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS has_sleeper BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS eld_device_id VARCHAR(50),
    ADD COLUMN IF NOT EXISTS status truck_status_enum DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS current_location_lat DECIMAL(9,6),
    ADD COLUMN IF NOT EXISTS current_location_lng DECIMAL(9,6);
    -- Using existing current_odometer instead of last_odometer_reading

-- ============================================
-- 2. TRAILERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.trailers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Identification
    trailer_number VARCHAR(20) NOT NULL,
    vin VARCHAR(17),
    license_plate VARCHAR(20),
    license_plate_state VARCHAR(2),
    
    -- Dimensions & Capacity
    length_feet INT CHECK (length_feet IN (28, 48, 53)),
    width_inches INT DEFAULT 102,
    height_inches INT DEFAULT 110,
    max_weight_lbs INT DEFAULT 45000,
    
    -- Type Classification
    trailer_type trailer_type_enum,
    
    -- Specific Features
    door_type trailer_door_type_enum,
    floor_type VARCHAR(20) DEFAULT 'WOOD',
    has_e_track BOOLEAN DEFAULT FALSE,
    is_food_grade BOOLEAN DEFAULT FALSE,
    
    -- Reefer Only
    reefer_unit_make VARCHAR(50),
    reefer_engine_hours DECIMAL(10,1),
    
    -- Status
    status trailer_status_enum DEFAULT 'ACTIVE',
    current_location_lat DECIMAL(9,6),
    current_location_lng DECIMAL(9,6),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(organization_id, trailer_number)
);

-- ============================================
-- 3. DISPATCH EVENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.dispatch_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- event_id
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES public.profiles(id), -- drivers are profiles
    
    event_type dispatch_event_type_enum,
    
    meta_data JSONB,
    occurred_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. LOAD DISPATCH CONFIG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.load_dispatch_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- config_id
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    
    -- 1. Route Optimization & Fuel
    fuel_plan JSONB, 
    total_planned_miles DECIMAL(10,2),
    route_warnings_en TEXT[],
    route_warnings_pb TEXT[],
    
    -- 2. Sanitized Instructions
    driver_pickup_instructions_en TEXT, 
    driver_pickup_instructions_pb TEXT, 
    driver_delivery_instructions_en TEXT,
    driver_delivery_instructions_pb TEXT,

    special_handling_instructions_en TEXT,
    special_handling_instructions_pb TEXT,
    
    -- 3. Document Links
    generated_sheet_url TEXT,
    qr_code_payload TEXT,
    
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. FACILITY PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.facility_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- facility_id
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Matching Logic
    normalized_name VARCHAR(255),
    address_hash VARCHAR(64),
    full_address TEXT,
    
    -- Value Add Data
    access_notes_en TEXT,
    access_notes_pb TEXT,
    safety_requirements_en JSONB,
    safety_requirements_pb JSONB,

    amenities_en JSONB,
    amenities_pb JSONB,
    avg_dwell_time_minutes INT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. DISPATCH ASSIGNMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.dispatch_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- assignment_id
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Actors
    driver_id UUID REFERENCES public.profiles(id),
    co_driver_id UUID REFERENCES public.profiles(id),
    truck_id UUID REFERENCES public.trucks(id),
    trailer_id UUID REFERENCES public.trailers(id),
    
    -- Manager
    dispatcher_user_id UUID REFERENCES public.profiles(id),
    
    -- Lifecycle
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status dispatch_assignment_status_enum DEFAULT 'ACTIVE',
    
    UNIQUE(load_id, status) -- Unique active assignment per load logic handled by status check if needed, or unique(load_id) for simplicty if only one allowed ever? Prompt says "UNIQUE(load_id, status)"
);

-- ============================================
-- 7. RATE CON DISPATCHER INSTRUCTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.rate_con_dispatcher_instructions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_confirmation_id UUID NOT NULL REFERENCES public.rate_confirmations(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    title_en TEXT,
    title_punjab TEXT,
    description_en TEXT,
    description_punjab TEXT,
    trigger_type VARCHAR(50), -- Absolute, Relative, Conditional
    deadline_iso TIMESTAMPTZ,
    relative_minutes_offset INT,
    original_clause TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


-- ============================================
-- RLS POLICIES
-- ============================================

-- Function helper if not exists (usually exists)
-- get_user_organization_id() is defined in 001_initial_schema.sql

-- Enable RLS
ALTER TABLE public.trailers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.load_dispatch_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facility_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_con_dispatcher_instructions ENABLE ROW LEVEL SECURITY;

-- Trailers
CREATE POLICY "Users can view org trailers" ON public.trailers FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can manage trailers" ON public.trailers FOR ALL TO authenticated USING (organization_id = get_user_organization_id() AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'));

-- Dispatch Events
CREATE POLICY "Users can view org dispatch events" ON public.dispatch_events FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can insert dispatch events" ON public.dispatch_events FOR INSERT TO authenticated WITH CHECK (organization_id = get_user_organization_id());

-- Load Dispatch Config
CREATE POLICY "Users can view org load dispatch config" ON public.load_dispatch_config FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can manage load dispatch config" ON public.load_dispatch_config FOR ALL TO authenticated USING (organization_id = get_user_organization_id() AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'));

-- Facility Profiles
CREATE POLICY "Users can view org facility profiles" ON public.facility_profiles FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can manage facility profiles" ON public.facility_profiles FOR ALL TO authenticated USING (organization_id = get_user_organization_id() AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'));

-- Dispatch Assignments
CREATE POLICY "Users can view org dispatch assignments" ON public.dispatch_assignments FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can manage dispatch assignments" ON public.dispatch_assignments FOR ALL TO authenticated USING (organization_id = get_user_organization_id() AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'));

-- Rate Con Dispatcher Instructions
CREATE POLICY "Users can view org rate con instructions" ON public.rate_con_dispatcher_instructions FOR SELECT TO authenticated USING (organization_id = get_user_organization_id());
CREATE POLICY "Managers can manage rate con instructions" ON public.rate_con_dispatcher_instructions FOR ALL TO authenticated USING (organization_id = get_user_organization_id() AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin'));

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

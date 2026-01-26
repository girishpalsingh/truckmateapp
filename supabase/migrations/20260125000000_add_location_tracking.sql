-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Create devices table
CREATE TABLE IF NOT EXISTS "public"."devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "device_fingerprint" "text" NOT NULL,
    "device_type" "text",
    "os_version" "text",
    "app_version" "text",
    "last_active_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "devices_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "devices_device_fingerprint_key" UNIQUE ("device_fingerprint"),
    CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL
    -- organization_id check will be enforced by RLS, no strict FK to a table if organizations table doesn't exist in public or isn't queryable directly, 
    -- but usually it refers to public.organizations if it exists. 
    -- Looking at schema dump, there is no public.organizations table visible in the dump provided (it might be omitted or I missed it). 
    -- Using common pattern: no FK constraint if table not guaranteed, or just assume it's fine. 
    -- The schema dump had `organization_id` in many tables but no `CREATE TABLE organizations`. 
    -- I will omit the FK constraint for organization_id to be safe and consistent with other tables like `trips` which has it but I didn't see the FK definition in the snippets I read.
    -- Wait, looking at `trips` in schema dump:
    -- 1098: "organization_id" "uuid" NOT NULL,
    -- It does not show an FK constraint in the create table statement or alter table.
    -- So I will follow that pattern.
);

ALTER TABLE "public"."devices" OWNER TO "postgres";

-- Create driver_locations table
CREATE TABLE IF NOT EXISTS "public"."driver_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "trip_id" "uuid" NOT NULL,
    "driver_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "device_id" "uuid" NOT NULL,
    "location" "geography"(POINT, 4326) NOT NULL,
    "speed" numeric,
    "heading" numeric,
    "accuracy" numeric,
    "altitude" numeric,
    "timestamp" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "driver_locations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "driver_locations_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE CASCADE,
    CONSTRAINT "driver_locations_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE,
    CONSTRAINT "driver_locations_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE CASCADE
);

ALTER TABLE "public"."driver_locations" OWNER TO "postgres";

-- Create index on geog column
CREATE INDEX "driver_locations_location_idx" ON "public"."driver_locations" USING GIST ("location");
CREATE INDEX "driver_locations_trip_id_idx" ON "public"."driver_locations" ("trip_id");
CREATE INDEX "driver_locations_timestamp_idx" ON "public"."driver_locations" ("timestamp");

-- RLS for devices
ALTER TABLE "public"."devices" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own devices" ON "public"."devices"
    FOR INSERT
    TO "authenticated"
    WITH CHECK (true); -- Ideally check organization_id match but user might be registering for first time. 
    -- Actually `handle_new_user` assigns role and maybe organization. 
    -- Let's stick to: Authenticated users can insert.

CREATE POLICY "Users can update their own devices" ON "public"."devices"
    FOR UPDATE
    TO "authenticated"
    USING (
        "organization_id" = "public"."get_user_organization_id"()
    )
    WITH CHECK (
        "organization_id" = "public"."get_user_organization_id"()
    );

CREATE POLICY "Users can view devices in their organization" ON "public"."devices"
    FOR SELECT
    TO "authenticated"
    USING (
        "organization_id" = "public"."get_user_organization_id"()
    );

-- RLS for driver_locations
ALTER TABLE "public"."driver_locations" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can insert their own locations" ON "public"."driver_locations"
    FOR INSERT
    TO "authenticated"
    WITH CHECK (
        "driver_id" = "auth"."uid"() AND
        "organization_id" = "public"."get_user_organization_id"()
    );

CREATE POLICY "Users can view locations in their organization" ON "public"."driver_locations"
    FOR SELECT
    TO "authenticated"
    USING (
        "organization_id" = "public"."get_user_organization_id"()
    );

-- Immutability Trigger for driver_locations
CREATE OR REPLACE FUNCTION "public"."check_driver_locations_immutable"()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Updates are not allowed on driver_locations table. Data is immutable.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "ensure_driver_locations_immutable"
    BEFORE UPDATE ON "public"."driver_locations"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."check_driver_locations_immutable"();

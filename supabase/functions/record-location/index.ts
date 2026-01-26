
import { createClient } from "@supabase/supabase-js";
import { withLogging } from "../_shared/logger.ts";
import { authorizeUser } from "../_shared/auth.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => withLogging(req, async (req: Request) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

        // Use service key to bypass RLS for inserting into immutable table if needed,
        // OR use the user's token. 
        // Typically for strict RLS, we use the user's token.
        // However, we want to ensure organization_id is correct.
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        // 1. Authenticate User (Driver)
        let userId: string | null = null;
        let organizationId: string | null = null;

        const authHeader = req.headers.get('Authorization');
        if (authHeader) {
            const user = await authorizeUser(req);
            userId = user.id;

            // Get profile to find organization
            const { data: profile, error: profileError } = await supabaseAdmin
                .from('profiles')
                .select('organization_id')
                .eq('id', userId)
                .single();

            if (profileError || !profile) {
                throw new Error("User profile not found");
            }
            organizationId = profile.organization_id;
        } else {
            // TODO: Implement 3rd party API Key authentication here
            throw new Error("Unauthorized: Missing Authorization header");
        }

        if (!userId || !organizationId) {
            throw new Error("Unauthorized: Could not determine user context");
        }

        // 2. Parse Body
        const body = await req.json();
        const {
            trip_id,
            device_id,
            latitude,
            longitude,
            speed,
            heading,
            accuracy,
            altitude,
            timestamp
        } = body;

        if (!trip_id || !device_id || latitude === undefined || longitude === undefined) {
            throw new Error("Missing required fields: trip_id, device_id, latitude, longitude");
        }

        // 3. Insert Location
        // We use ST_SetSRID(ST_MakePoint(lon, lat), 4326)
        // For Supabase JS, we can pass the string representation for geography column
        // Format: 'SRID=4326;POINT(lon lat)'
        const locationString = `SRID=4326;POINT(${longitude} ${latitude})`;

        const { data, error } = await supabaseAdmin
            .from('driver_locations')
            .insert({
                trip_id,
                driver_id: userId,
                organization_id: organizationId,
                device_id,
                location: locationString,
                speed,
                heading,
                accuracy,
                altitude,
                timestamp: timestamp || new Date().toISOString()
            })
            .select('id')
            .single();

        if (error) {
            console.error("Error inserting location:", error);
            throw new Error(`Database error: ${error.message}`);
        }

        // 4. Update Truck/Driver current location cache (optional but useful)
        // We can update `trucks` table if we know the truck_id, or just rely on latest location query.
        // The `trips` table has `truck_id`, we could look it up.
        // For performance, we might skip this or do it in a background trigger.
        // But the schema had `current_location_lat` in `trucks`.
        // Let's update it if we can find the truck from the trip.
        // This is a "nice to have" optimization.

        // Find truck_id from trip
        const { data: trip } = await supabaseAdmin
            .from('trips')
            .select('truck_id')
            .eq('id', trip_id)
            .single();

        if (trip?.truck_id) {
            await supabaseAdmin
                .from('trucks')
                .update({
                    current_location_lat: latitude,
                    current_location_long: longitude, // Assuming column name based on lat existence
                    updated_at: new Date().toISOString()
                })
                .eq('id', trip.truck_id);
        }


        return new Response(
            JSON.stringify({ success: true, id: data.id }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Error recording location:", error);
        return new Response(
            JSON.stringify({ error: (error as any).message }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));

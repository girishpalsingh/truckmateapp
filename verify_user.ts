
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { config } from "./supabase/functions/_shared/config.ts";

const supabase = createClient(
    config.supabase.url!,
    config.supabase.serviceRoleKey!
);

async function verifyUserAndOrg(phoneNumber: string) {
    console.log(`Verifying user: ${phoneNumber}`);

    // 1. Get Profile
    const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("*")
        .eq("phone_number", phoneNumber)
        .single();

    if (profileError) {
        console.error("Error fetching profile:", profileError);
        return;
    }

    if (!profile) {
        console.error("Profile not found");
        return;
    }

    console.log("Profile found:", profile);

    if (!profile.organization_id) {
        console.error("Profile has no organization_id");
        return;
    }

    // 2. Get Organization
    const { data: org, error: orgError } = await supabase
        .from("organizations")
        .select("*")
        .eq("id", profile.organization_id)
        .single();

    if (orgError) {
        console.error("Error fetching organization:", orgError);
        return;
    }

    if (!org) {
        console.error("Organization not found");
        return;
    }

    console.log("Organization found:", org);
}

// Test with the seeded user
await verifyUserAndOrg("+15551234567");

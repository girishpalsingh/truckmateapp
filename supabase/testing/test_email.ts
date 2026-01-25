import { createClient } from "@supabase/supabase-js";
import { NotificationService } from "../functions/_shared/notification-service.ts";
import "https://deno.land/std@0.208.0/dotenv/load.ts"; // Auto-load .env

// Configuration
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SERVICE_ROLE_KEY) {
    console.error("Error: SUPABASE_SERVICE_ROLE_KEY is required.");
    console.error("Usage: deno run -A --env-file=.env supabase/testing/test_email.ts [email]");
    Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const notificationService = new NotificationService(supabase);

async function main() {
    console.log("Starting Email Notification Test...");

    // 1. Get test email from args or default
    // ... (previous code above is fine, replacing from line 22)
    const testEmail = Deno.args[0] || "delivered@resend.dev";

    // Default testing org
    const TEST_ORG_ID = "11111111-1111-1111-1111-111111111111";

    console.log(`Target Email: ${testEmail}`);

    // 2. Resolve User ID
    let userId: string | undefined;

    // A. Check Profiles first (Public DB access, robust against Auth API failures)
    const { data: existingProfile, error: profileLookupError } = await supabase
        .from("profiles")
        .select("id")
        .eq("email_address", testEmail)
        .single();

    if (existingProfile) {
        console.log(`Found existing Profile for ${testEmail}: ${existingProfile.id}`);
        userId = existingProfile.id;
    } else {
        if (profileLookupError && profileLookupError.code !== "PGRST116") {
            console.warn(`Error checking profiles: ${profileLookupError.message}`);
        }

        console.log("Profile not found locally. Checking Auth Users via Admin API...");

        try {
            // B. Check Auth Users (Admin API)
            const { data: usersData, error: listError } = await supabase.auth.admin.listUsers();

            if (listError) {
                console.error("Failed to list users via Admin API:", listError);
                throw listError;
            }

            const existingUser = usersData.users.find(u => u.email === testEmail);

            if (existingUser) {
                console.log(`Found existing Auth user for ${testEmail}: ${existingUser.id}`);
                userId = existingUser.id;
            } else {
                // C. Create User
                console.log("User not found in Auth, attempting to create...");
                const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
                    email: testEmail,
                    password: "TestPassword123!",
                    email_confirm: true
                });

                if (newUser?.user) {
                    userId = newUser.user.id;
                    console.log(`Created new test user: ${userId}`);
                } else if (createError) {
                    if (createError.message.includes("already been registered")) {
                        console.error("User registered in Auth but not found in listUsers (consistency issue). Cannot proceed without ID.");
                        Deno.exit(1);
                    } else {
                        console.error(`Could not create auth user: ${createError.message}`);
                        throw createError;
                    }
                }
            }
        } catch (err) {
            console.error("Critical: Auth Admin API failed. If you see a 500 error here, it means Supabase Auth service is struggling.", err);
            Deno.exit(1);
        }
    }

    if (!userId) {
        console.error("Failed to resolve a User ID. Exiting.");
        Deno.exit(1);
    }

    // Ensure Profile exists/is updated
    const { error: profileError } = await supabase
        .from("profiles")
        .upsert({
            id: userId,
            email_address: testEmail,
            full_name: "Test User",
            role: "driver",
            organization_id: TEST_ORG_ID
        });

    if (profileError) {
        console.error("Failed to update profile:", profileError);
        Deno.exit(1);
    }

    // 3. Send Notification
    console.log("Sending 'Email Test' notification via NotificationService...");

    try {
        await notificationService.sendNotification({
            userId: userId,
            organizationId: TEST_ORG_ID,
            title: "Test Email SDK",
            body: "This email was sent using the official Resend SDK integration in Supabase Edge Functions.",
            type: "system_alert",
            channels: ["email"]
        });

        console.log("✅ Notification command sent successfully.");
    } catch (err) {
        console.error("❌ Failed to send notification:", err);
        Deno.exit(1);
    }
}

main();

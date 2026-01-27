import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import { authorizeUser, corsHeaders } from "../_shared/auth.ts";



serve(async (req) => {
    // Handle CORS'
    console.log("Hello from process-rate-con-response!");
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // 1. Authorize User
        const user = await authorizeUser(req);

        // 2. Initialize Supabase Client (Service Role)
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // 3. Check User Role (Must be owner, manager, or dispatcher)
        const { data: profile, error: profileError } = await supabase
            .from("profiles")
            .select("role")
            .eq("id", user.id)
            .single();

        if (profileError || !profile) {
            console.error("Error fetching profile:", profileError);
            return new Response(JSON.stringify({ error: "Unauthorized: Profile not found" }), {
                status: 403,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // 4. Parse Request Body (Moved up for Auth check)
        const { rate_con_id, action, edits } = await req.json();

        if (!rate_con_id || !action) {
            return new Response(JSON.stringify({ error: "Missing rate_con_id or action" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const { role } = profile;
        let isAuthorized = ["owner", "manager", "dispatcher"].includes(role);

        // Allow driver if they created the rate con
        if (!isAuthorized && role === 'driver') {
            const { data: rc, error: rcAuthError } = await supabase
                .from('rate_confirmations')
                .select('created_by')
                .eq('id', rate_con_id)
                .single();

            if (!rcAuthError && rc && rc.created_by === user.id) {
                isAuthorized = true;
            } else {
                console.error(`Driver ${user.id} attempted to process RC ${rate_con_id} created by ${rc?.created_by}`);
            }
        }

        if (!isAuthorized) {
            console.error(`Unauthorized role: ${role}`);
            return new Response(JSON.stringify({ error: `Unauthorized: Role '${role}' cannot perform this action.` }), {
                status: 403,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        if (action === "reject") {
            // Handle Rejection
            const { error: updateError } = await supabase
                .from("rate_confirmations")
                .update({
                    status: "rejected",
                    updated_at: new Date().toISOString(),
                })
                .eq("id", rate_con_id);

            if (updateError) throw updateError;

            return new Response(JSON.stringify({ message: "Rate confirmation rejected successfully" }), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });

        } else if (action === "accept") {
            // Handle Acceptance

            // Call the transactional RPC
            console.log(`Calling approve_rate_con_transaction for ${rate_con_id} by user ${user.id}`);
            const { data: rpcResult, error: rpcError } = await supabase.rpc(
                'approve_rate_con_transaction',
                {
                    p_rate_con_id: rate_con_id,
                    p_edits: edits || null,
                    p_user_id: user.id
                }
            );

            if (rpcError) {
                console.error("RPC Error:", JSON.stringify(rpcError));
                throw rpcError;
            }

            console.log("RPC Result:", JSON.stringify(rpcResult));

            return new Response(JSON.stringify(rpcResult), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });

        } else {
            return new Response(JSON.stringify({ error: "Invalid action" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

    } catch (error) {
        console.error("Error processing rate con response:", error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});

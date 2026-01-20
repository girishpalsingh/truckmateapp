import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

export const getUserByPhone = async (supabase: SupabaseClient, phone: string) => {
    const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("*")
        .eq("phone_number", phone)
        .maybeSingle();

    if (profileError) {
        console.log("Profile error:", profileError);
        return { user: null, profile: null, error: profileError };
    }

    if (!profile) {
        console.log("Profile not found");
        return { user: null, profile: null, error: null };
    }

    console.log("Profile found:", profile.id);

    const { data: { user }, error } = await supabase.auth.admin.getUserById(profile.id);

    if (error) {
        console.log("User error:", error);
        return { user: null, profile: profile, error };
    }

    console.log("User found:", user);
    return { user, profile, error: null };
};

export const getOrganization = async (supabase: SupabaseClient, organizationId: string) => {
    const { data, error } = await supabase
        .from("organizations")
        .select("*")
        .eq("id", organizationId)
        .single();

    return { data, error };
};

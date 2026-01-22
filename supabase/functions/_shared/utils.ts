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

// Helper to parser numeric values robustly
export const parseNumeric = (val: any): number | null => {
    if (val === null || val === undefined) return null;
    if (typeof val === 'number') return val;
    if (typeof val === 'string') {
        const clean = val.replace(/[^0-9.-]/g, '');
        const parsed = parseFloat(clean);
        return isNaN(parsed) ? null : parsed;
    }
    return null;
};

// Helper to parse time string (HH:MM:SS 24h). Handles AM/PM conversion.
export const parseTime = (val: any): string | null => {
    if (!val || typeof val !== 'string') return null;

    let clean = val.trim().toUpperCase();
    const isPM = clean.includes('PM');
    const isAM = clean.includes('AM');
    const timeMatch = clean.match(/(\d{1,2}):(\d{2})(:(\d{2}))?/);

    if (timeMatch) {
        let hours = parseInt(timeMatch[1]);
        let minutes = parseInt(timeMatch[2]);
        let seconds = timeMatch[4] ? parseInt(timeMatch[4]) : 0;

        if (isPM && hours < 12) hours += 12;
        if (isAM && hours === 12) hours = 0;

        if (hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59 && seconds >= 0 && seconds <= 59) {
            return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
    }

    const simpleTime = /^([01]\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$/;
    if (simpleTime.test(clean)) return clean;

    return null;
};

// Helper to parse date string to YYYY-MM-DD
export const parseDate = (val: any): string | null => {
    if (!val || typeof val !== 'string') return null;
    const clean = val.trim();
    const date = new Date(clean);
    if (!isNaN(date.getTime())) {
        return date.toISOString().split('T')[0];
    }
    return null;
};

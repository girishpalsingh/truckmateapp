import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://hgwjghlyaseqrvkvknji.supabase.co';
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhnd2pnaGx5YXNlcXJ2a3ZrbmppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4NTExMDksImV4cCI6MjA4NDQyNzEwOX0.eDO8TLerhKqz9OouhlB-gFWsESEgQEY9h2Ek0ZbzmVM';

export const supabase = createClient(supabaseUrl, supabaseKey);

// Trip service functions
export async function getTrips(orgId: string, options?: { status?: string; limit?: number }) {
    const query = supabase
        .from('trips')
        .select(`*, load:loads(*), truck:trucks(truck_number), driver:profiles(full_name)`)
        .eq('organization_id', orgId)
        .order('created_at', { ascending: false });

    if (options?.status) query.eq('status', options.status);
    if (options?.limit) query.limit(options.limit);

    const { data, error } = await query;
    if (error) throw error;
    return data;
}

export async function getTripById(tripId: string) {
    const { data, error } = await supabase
        .from('trips')
        .select(`*, load:loads(*), truck:trucks(*), driver:profiles(*)`)
        .eq('id', tripId)
        .single();
    if (error) throw error;
    return data;
}

// Document service functions
export async function getDocuments(orgId: string, options?: { status?: string; tripId?: string }) {
    const query = supabase
        .from('documents')
        .select('*')
        .eq('organization_id', orgId)
        .order('created_at', { ascending: false });

    if (options?.status) query.eq('status', options.status);
    if (options?.tripId) query.eq('trip_id', options.tripId);

    const { data, error } = await query;
    if (error) throw error;
    return data;
}

export async function updateDocumentStatus(docId: string, status: string, reviewerId?: string) {
    const { error } = await supabase
        .from('documents')
        .update({ status, reviewed_by: reviewerId, reviewed_at: new Date().toISOString() })
        .eq('id', docId);
    if (error) throw error;
}

// Driver service functions
export async function getDrivers(orgId: string) {
    const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('organization_id', orgId)
        .eq('role', 'driver');
    if (error) throw error;
    return data;
}

// Expense service functions
export async function getExpenses(orgId: string, options?: { tripId?: string; category?: string }) {
    const query = supabase
        .from('expenses')
        .select(`*, trip:trips(origin_address, destination_address)`)
        .eq('organization_id', orgId)
        .order('date', { ascending: false });

    if (options?.tripId) query.eq('trip_id', options.tripId);
    if (options?.category) query.eq('category', options.category);

    const { data, error } = await query;
    if (error) throw error;
    return data;
}

// Invoice service functions
export async function getInvoices(orgId: string) {
    const { data, error } = await supabase
        .from('invoices')
        .select('*')
        .eq('organization_id', orgId)
        .order('created_at', { ascending: false });
    if (error) throw error;
    return data;
}

export async function generateInvoice(tripId: string) {
    const { data, error } = await supabase.functions.invoke('generate-invoice', {
        body: { trip_id: tripId }
    });
    if (error) throw error;
    return data;
}

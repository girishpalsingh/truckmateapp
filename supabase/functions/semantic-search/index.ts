// supabase/functions/semantic-search/index.ts
// Semantic Search Edge Function using pgvector

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SearchRequest {
    query: string;
    organization_id: string;
    document_types?: string[];
    date_from?: string;
    date_to?: string;
    limit?: number;
}

async function generateEmbedding(apiKey: string, text: string): Promise<number[]> {
    const response = await fetch("https://api.openai.com/v1/embeddings", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            model: "text-embedding-3-small",
            input: text,
        }),
    });

    if (!response.ok) {
        throw new Error("Failed to generate embedding");
    }

    const result = await response.json();
    return result.data?.[0]?.embedding || [];
}

async function parseNaturalLanguageQuery(apiKey: string, query: string): Promise<{
    searchTerms: string;
    filters: {
        states?: string[];
        dateRange?: { from?: string; to?: string };
        expenseTypes?: string[];
        documentTypes?: string[];
    };
}> {
    // Use Gemini to parse natural language into structured filters
    const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
        {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{
                    parts: [{
                        text: `Parse this trucking search query into structured filters. Extract:
- Search terms (key words to search for)
- State/jurisdiction filters (US state codes like TX, CA)
- Date range (parse relative dates like "December 2025", "last month")
- Expense types (fuel, tolls, food, lodging, etc.)
- Document types (rate_con, bol, fuel_receipt, etc.)

Query: "${query}"

Respond with JSON only:
{
  "searchTerms": "keywords to search",
  "filters": {
    "states": ["TX", "CA"],
    "dateRange": { "from": "2025-12-01", "to": "2025-12-31" },
    "expenseTypes": ["fuel"],
    "documentTypes": ["fuel_receipt"]
  }
}`
                    }]
                }],
                generationConfig: { temperature: 0.1 },
            }),
        }
    );

    const result = await response.json();
    const text = result.candidates?.[0]?.content?.parts?.[0]?.text;

    try {
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
            return JSON.parse(jsonMatch[0]);
        }
    } catch {
        // Fall back to simple search
    }

    return { searchTerms: query, filters: {} };
}

import { withLogging } from "../_shared/logger.ts";

serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const openaiKey = Deno.env.get("OPENAI_API_KEY")!;
        const geminiKey = Deno.env.get("GEMINI_API_KEY")!;

        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        const body: SearchRequest = await req.json();
        const { query, organization_id, document_types, limit = 20 } = body;

        if (!query || !organization_id) {
            return new Response(
                JSON.stringify({ error: "Query and organization_id are required" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Parse natural language query
        const parsed = await parseNaturalLanguageQuery(geminiKey, query);
        console.log("Parsed query:", parsed);

        // Generate embedding for semantic search
        const embedding = await generateEmbedding(openaiKey, parsed.searchTerms || query);

        // Semantic search using pgvector
        const { data: semanticResults, error: searchError } = await supabase.rpc(
            "search_documents",
            {
                org_id: organization_id,
                query_embedding: embedding,
                match_threshold: 0.7,
                match_count: limit,
            }
        );

        if (searchError) {
            console.error("Semantic search error:", searchError);
        }

        // Also do traditional search on expenses if filters suggest it
        let expenseResults: any[] = [];
        if (parsed.filters.expenseTypes || parsed.filters.states) {
            let expenseQuery = supabase
                .from("expenses")
                .select(`
          *,
          trip:trips(origin_address, destination_address, status)
        `)
                .eq("organization_id", organization_id);

            if (parsed.filters.expenseTypes?.length) {
                expenseQuery = expenseQuery.in("category", parsed.filters.expenseTypes);
            }

            if (parsed.filters.states?.length) {
                expenseQuery = expenseQuery.in("jurisdiction", parsed.filters.states);
            }

            if (parsed.filters.dateRange?.from) {
                expenseQuery = expenseQuery.gte("date", parsed.filters.dateRange.from);
            }

            if (parsed.filters.dateRange?.to) {
                expenseQuery = expenseQuery.lte("date", parsed.filters.dateRange.to);
            }

            const { data } = await expenseQuery.limit(limit);
            expenseResults = data || [];
        }

        // Get full document details for semantic results
        const documentIds = (semanticResults || []).map((r: any) => r.document_id);
        let documents: any[] = [];

        if (documentIds.length > 0) {
            const { data } = await supabase
                .from("documents")
                .select(`
          *,
          trip:trips(origin_address, destination_address)
        `)
                .in("id", documentIds);
            documents = data || [];
        }

        // Combine and format results
        const results = {
            query: query,
            parsed_query: parsed,
            documents: documents.map((doc: any) => ({
                id: doc.id,
                type: doc.type,
                ai_data: doc.ai_data,
                trip: doc.trip,
                created_at: doc.created_at,
                similarity: semanticResults?.find((r: any) => r.document_id === doc.id)?.similarity,
            })),
            expenses: expenseResults.map((exp: any) => ({
                id: exp.id,
                category: exp.category,
                amount: exp.amount,
                vendor_name: exp.vendor_name,
                jurisdiction: exp.jurisdiction,
                date: exp.date,
                trip: exp.trip,
            })),
            total_results: documents.length + expenseResults.length,
        };

        return new Response(
            JSON.stringify(results),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Search error:", error);
        return new Response(
            JSON.stringify({ error: error.message || "Search failed" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));

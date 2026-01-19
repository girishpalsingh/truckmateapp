// supabase/functions/process-document/index.ts
// Document Processing Edge Function with LLM Integration

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProcessRequest {
    document_id: string;
    document_type: "rate_con" | "bol" | "fuel_receipt" | "lumper_receipt" | "scale_ticket" | "detention_evidence" | "other";
    image_url: string;
    local_extraction?: string; // Text from on-device ML
}

interface LLMConfig {
    provider: "gemini" | "openai" | "claude";
    gemini_key?: string;
    openai_key?: string;
    claude_key?: string;
}

// Load prompts from storage or embedded
async function loadPrompt(documentType: string): Promise<string> {
    const prompts: Record<string, string> = {
        rate_con: `You are an expert document analyst specializing in trucking and logistics contracts. Analyze the provided Rate Confirmation document and extract all relevant fields including broker info, load details, financial terms, and identify dangerous clauses.`,
        bol: `You are an expert document analyst specializing in trucking logistics. Analyze the provided Bill of Lading and extract shipper info, consignee info, cargo details, and any exceptions noted.`,
        fuel_receipt: `You are an expert document analyst for trucking expenses. Extract vendor name, amount, gallons, jurisdiction state, and date from this fuel receipt. This is critical for IFTA reporting.`,
        lumper_receipt: `Extract the lumper fee amount, vendor name, date, and location from this lumper receipt.`,
        scale_ticket: `Extract the scale location, vehicle weight, date, and any overweight indicators from this scale ticket.`,
        detention_evidence: `Analyze this documentation for detention claim evidence. Extract arrival time, departure time, location, and any supporting details.`,
        other: `Analyze this document and extract all visible text and key information.`,
    };

    return prompts[documentType] || prompts.other;
}

async function callGemini(apiKey: string, prompt: string, imageBase64: string): Promise<any> {
    const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
        {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{
                    parts: [
                        { text: prompt + "\n\nRespond with valid JSON only." },
                        {
                            inline_data: {
                                mime_type: "image/jpeg",
                                data: imageBase64,
                            },
                        },
                    ],
                }],
                generationConfig: {
                    temperature: 0.1,
                    maxOutputTokens: 4096,
                },
            }),
        }
    );

    if (!response.ok) {
        throw new Error(`Gemini API error: ${response.status}`);
    }

    const result = await response.json();
    const text = result.candidates?.[0]?.content?.parts?.[0]?.text;

    // Parse JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
    }

    return { raw_text: text };
}

async function callOpenAI(apiKey: string, prompt: string, imageBase64: string): Promise<any> {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            model: "gpt-4o",
            messages: [
                {
                    role: "user",
                    content: [
                        { type: "text", text: prompt + "\n\nRespond with valid JSON only." },
                        {
                            type: "image_url",
                            image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
                        },
                    ],
                },
            ],
            max_tokens: 4096,
            temperature: 0.1,
        }),
    });

    if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.status}`);
    }

    const result = await response.json();
    const text = result.choices?.[0]?.message?.content;

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
    }

    return { raw_text: text };
}

async function callClaude(apiKey: string, prompt: string, imageBase64: string): Promise<any> {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            model: "claude-3-sonnet-20240229",
            max_tokens: 4096,
            messages: [
                {
                    role: "user",
                    content: [
                        {
                            type: "image",
                            source: {
                                type: "base64",
                                media_type: "image/jpeg",
                                data: imageBase64,
                            },
                        },
                        { type: "text", text: prompt + "\n\nRespond with valid JSON only." },
                    ],
                },
            ],
        }),
    });

    if (!response.ok) {
        throw new Error(`Claude API error: ${response.status}`);
    }

    const result = await response.json();
    const text = result.content?.[0]?.text;

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
    }

    return { raw_text: text };
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
        console.error("Embedding generation failed");
        return [];
    }

    const result = await response.json();
    return result.data?.[0]?.embedding || [];
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        const body: ProcessRequest = await req.json();
        const { document_id, document_type, image_url, local_extraction } = body;

        // Get organization's LLM config
        const { data: doc } = await supabase
            .from("documents")
            .select("organization_id")
            .eq("id", document_id)
            .single();

        if (!doc) {
            return new Response(
                JSON.stringify({ error: "Document not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const { data: org } = await supabase
            .from("organizations")
            .select("llm_provider")
            .eq("id", doc.organization_id)
            .single();

        const llmProvider = org?.llm_provider || "gemini";

        // Download image from Supabase Storage
        const { data: imageData, error: downloadError } = await supabase.storage
            .from("documents")
            .download(image_url);

        if (downloadError || !imageData) {
            return new Response(
                JSON.stringify({ error: "Failed to download document image" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Convert to base64
        const arrayBuffer = await imageData.arrayBuffer();
        const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));

        // Load appropriate prompt
        const prompt = await loadPrompt(document_type);

        // Call LLM based on provider
        let extractedData: any;
        const llmConfig: LLMConfig = {
            provider: llmProvider as any,
            gemini_key: Deno.env.get("GEMINI_API_KEY"),
            openai_key: Deno.env.get("OPENAI_API_KEY"),
            claude_key: Deno.env.get("CLAUDE_API_KEY"),
        };

        switch (llmProvider) {
            case "openai":
                if (!llmConfig.openai_key) throw new Error("OpenAI API key not configured");
                extractedData = await callOpenAI(llmConfig.openai_key, prompt, base64);
                break;
            case "claude":
                if (!llmConfig.claude_key) throw new Error("Claude API key not configured");
                extractedData = await callClaude(llmConfig.claude_key, prompt, base64);
                break;
            default:
                if (!llmConfig.gemini_key) throw new Error("Gemini API key not configured");
                extractedData = await callGemini(llmConfig.gemini_key, prompt, base64);
        }

        // Compare with local extraction if available
        if (local_extraction) {
            extractedData.local_extraction_comparison = {
                local_text: local_extraction,
                server_processed: true,
            };
        }

        // Calculate confidence based on extracted fields
        const fieldCount = Object.keys(extractedData.extracted_fields || extractedData).length;
        const confidence = Math.min(0.95, 0.5 + (fieldCount * 0.05));

        // Update document with extracted data
        await supabase
            .from("documents")
            .update({
                ai_data: extractedData,
                ai_confidence: confidence,
                dangerous_clauses: extractedData.dangerous_clauses || null,
                status: confidence > 0.7 ? "pending_review" : "pending_review",
                updated_at: new Date().toISOString(),
            })
            .eq("id", document_id);

        // Generate embeddings for semantic search
        const textContent = JSON.stringify(extractedData);
        if (llmConfig.openai_key && textContent.length > 0) {
            const embedding = await generateEmbedding(llmConfig.openai_key, textContent);

            if (embedding.length > 0) {
                await supabase.from("document_embeddings").insert({
                    document_id,
                    content: textContent.substring(0, 8000),
                    embedding,
                    metadata: { document_type, processed_at: new Date().toISOString() },
                });
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                document_id,
                extracted_data: extractedData,
                confidence,
                llm_provider: llmProvider,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Document processing error:", error);
        return new Response(
            JSON.stringify({ error: error.message || "Processing failed" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});

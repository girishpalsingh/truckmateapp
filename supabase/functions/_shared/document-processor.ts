import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { encode } from 'https://deno.land/std@0.168.0/encoding/base64.ts'
import { GoogleGenAI } from "npm:@google/genai";
import { config } from "./config.ts";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const GEMINI_API_KEY = config.llm.gemini.api_key;

if (!GEMINI_API_KEY) {
    console.error("CRITICAL: GEMINI_API_KEY is missing from config or environment variables!");
    throw new Error("GEMINI_API_KEY is not set");
}


const GEMINI_MODEL = config.llm.gemini.model;
const GEMINI_EMBEDDING_MODEL = "text-embedding-004";

const genAI = new GoogleGenAI({ apiKey: GEMINI_API_KEY });



import { EXTRACTION_PROMPTS as prompts } from "./prompts.ts";
import { processRateCon } from "./rate-con-processor.ts";
import mockResponse from "../mock_llm_response/response.json" with { type: "json" };

// Process image with Gemini
function loadPrompt(documentType: string): string {
    return prompts[documentType] || prompts["other"];
}

// Process image with Gemini
export async function processWithGemini(imageUrl: string, documentType: string, modelName: string): Promise<{
    extractedData: Record<string, unknown>;
    rawText: string;
    confidence: number;
}> {
    // Check for Mock LLM Mode
    if (config.development.mock_llm) {
        console.log("MOCK LLM MODE ENABLED: Returning mock response in 2 seconds...");
        await new Promise(resolve => setTimeout(resolve, 2000));

        console.log("Returning mock data:", JSON.stringify(mockResponse, null, 2));
        return {
            extractedData: mockResponse,
            rawText: JSON.stringify(mockResponse),
            confidence: 0.95
        };
    }

    const prompt = loadPrompt(documentType);

    console.log(`Using model: ${modelName} for document type: ${documentType}`);

    // Fetch image and convert to base64
    // Fix for local Docker development: replace localhost/127.0.0.1 with host.docker.internal
    let cleanImageUrl = imageUrl
        .replace('http://127.0.0.1:', 'http://host.docker.internal:')
        .replace('http://localhost:', 'http://host.docker.internal:')

    // Ensure URL is valid and encoded
    try {
        cleanImageUrl = new URL(cleanImageUrl).toString()
    } catch (e) {
        console.error(`Invalid Image URL cannot be parsed: ${cleanImageUrl}`, e)
        throw new Error(`Invalid Image URL: ${imageUrl}`)
    }

    console.log(`Fetching image from: ${cleanImageUrl}`)

    let imageResponse;
    try {
        imageResponse = await fetch(cleanImageUrl)
    } catch (e) {
        console.error(`Failed to fetch image from ${cleanImageUrl}:`, e)
        throw new Error(`Failed to download image: ${(e as any).message}`)
    }

    // Get content type from response or valid fallback
    const contentType = imageResponse.headers.get('content-type') || 'image/jpeg'
    console.log(`Detected MIME Type: ${contentType}`)

    const imageBuffer = await imageResponse.arrayBuffer()
    const base64Data = encode(imageBuffer)

    console.log(`Using Model in func: ${modelName}`);

    // Use New Gemini SDK
    // The new SDK uses client.models.generateContent
    const result = await genAI.models.generateContent({
        model: modelName,
        contents: [
            {
                parts: [
                    { text: prompt },
                    { inlineData: { mimeType: contentType, data: base64Data } }
                ]
            }
        ],
        config: {
            temperature: 1.0,
            maxOutputTokens: 25000,
            responseMimeType: "application/json",
            thinkingConfig: { includeThoughts: false, thinkingLevel: "minimal" }
        }
    });

    console.log('Gemini Result Keys:', Object.keys(result));

    if (result.usageMetadata) {
        console.log("Gemini Token Usage:", JSON.stringify(result.usageMetadata, null, 2));
    }

    console.log('Full Gemini Response:', JSON.stringify(result, null, 2));

    const textContent = result.candidates?.[0]?.content?.parts?.[0]?.text || '';
    if (!textContent && (result as any).text) {
        console.log("Found .text property/getter");
    }

    // Parse JSON from response
    let extractedData = {}
    try {
        // Try to parse directly first as we requested JSON mime type
        extractedData = JSON.parse(textContent)
    } catch (e) {
        // Fallback to regex match if needed
        const jsonMatch = textContent.match(/\{[\s\S]*\}/)
        if (jsonMatch) {
            try {
                extractedData = JSON.parse(jsonMatch[0])
            } catch (innerE) {
                // console.error('JSON parse error:', innerE)
            }
        }
    }

    // ERROR FIX: Ensure extractedData is always an Object, not an Array
    if (Array.isArray(extractedData)) {
        console.warn("AI returned an Array instead of an Object. Wrapping in { items: ... }");
        extractedData = { items: extractedData };
    }

    // Ensure it's not null or non-object primitives (like string/number if parse somehow allowed it)
    if (!extractedData || typeof extractedData !== 'object') {
        console.warn("AI returned non-object data. Defaulting to empty object.");
        extractedData = {};
    }

    return {
        extractedData,
        rawText: textContent,
        confidence: 0.85 // Gemini doesn't return confidence, using default
    }
}

// Generate embedding for semantic search
export async function generateEmbedding(text: string): Promise<number[]> {
    const result = await genAI.models.embedContent({
        model: GEMINI_EMBEDDING_MODEL,
        contents: [
            {
                parts: [
                    { text: text }
                ]
            }
        ]
    });
    return result.embeddings?.[0]?.values || [];
}

/**
 * Main orchestration function to process a document
 */
export async function processDocumentWithAI(
    documentId: string,
    imageUrl: string,
    documentType: string,
    organizationId?: string
) {

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // 1. Fetch document metadata (including uploaded_by)
    const { data: docData, error: docError } = await supabase
        .from('documents')
        .select('uploaded_by, organization_id')
        .eq('id', documentId)
        .single();

    if (docError) {
        console.error(`Error fetching document ${documentId}:`, docError);
    }

    const userId = docData?.uploaded_by || null;
    const effectiveOrgId = organizationId || docData?.organization_id;

    // Get organization's LLM preference
    let llmModel = GEMINI_MODEL
    console.log("Processing document with AI... using model: ", llmModel)
    // if (organizationId) {
    //     const { data: org } = await supabase
    //         .from('organizations')
    //         .select('llm_provider')
    //         .eq('id', organizationId)
    //         .single()
    //     if (org?.llm_provider) llmModel = org.llm_provider
    // }

    // Process document with AI
    const { extractedData, rawText, confidence } = await processWithGemini(imageUrl, documentType, llmModel)

    // Generate embedding for semantic search
    const searchText = JSON.stringify(extractedData) + ' ' + rawText
    const embedding = await generateEmbedding(searchText.slice(0, 8000))

    // Determine which column to update based on embedding dimension
    const updates: Record<string, any> = {
        ai_data: extractedData, // MATCHING INDEX.TS: ai_data
        // parsed_data: extractedData, // REMOVED to match index.ts preference
        ai_confidence: confidence, // MATCHING INDEX.TS
        dangerous_clauses: (extractedData as any).dangerous_clauses || null, // MATCHING INDEX.TS
        // ai_processed_at: new Date().toISOString(), // This is updated_at in index.ts, keeping standard
        updated_at: new Date().toISOString(),
        status: confidence > 0.7 ? "pending_review" : "pending_review", // MATCHING INDEX.TS logic
        title: (extractedData as any).broker_name
            ? (extractedData as any).broker_name
            : (extractedData as any).load_id
                ? `Load ${(extractedData as any).load_id}`
                : documentType.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase()) // Fallback to capitalized type
    }

    if (embedding.length === 768) {
        // updates.embedding_gemini_768 = embedding // Keeping this if schema supports it, but index.ts inserts into document_embeddings table
    } else if (embedding.length === 1536) {
        // updates.embedding_openai_1536 = embedding
    }

    // MATCHING INDEX.TS: Insert embedding into document_embeddings table instead of updating documents column directly?
    // index.ts does: 
    // await supabase.from("document_embeddings").insert({...})
    // document-processor.ts was doing: updates.embedding_gemini_768 = embedding

    // I should probably support both or switch to index.ts method if that's the new standard.
    // The user said "use document-processor.ts script to streamline operations".
    // I will stick to what document-processor.ts was doing BUT I will align column names that overlap.
    // However, index.ts was NOT updating embedding in the document row, but a separate table.

    // Let's UPDATE query to match index.ts updates:
    /*
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
    */

    // So I will use that. And I will add the embedding insert separately.

    const { data: updatedDoc, error: updateError } = await supabase
        .from('documents')
        .update(updates)
        .eq('id', documentId)
        .select()
        .single()

    if (updateError) throw updateError

    // Insert embedding if exists
    if (embedding.length > 0) {
        await supabase.from("document_embeddings").insert({
            document_id: documentId,
            content: JSON.stringify(extractedData).substring(0, 8000),
            embedding,
            metadata: { document_type: documentType, processed_at: new Date().toISOString() },
        });
    }

    // Update document record and return it
    // Update already happened above
    // const { data: updatedDoc, error: updateError } = await supabase...

    if (updateError) throw updateError

    // Post-Processing for Rate Confirmation
    let rateConId: string | null = null;
    console.log(`Checking Rate Con Processing: Type=${documentType}, OrgId=${effectiveOrgId}`);
    if (documentType === 'rate_con' && effectiveOrgId) {
        try {
            const dbRateCon = await processRateCon(documentId, extractedData, effectiveOrgId, userId);
            if (dbRateCon) {
                rateConId = dbRateCon.id;
                // Inject the DB UUID into extractedData so clients can easily find it?
                // Or just return it in the wrapping object.
                (extractedData as any).rate_con_db_id = rateConId;
            }
        } catch (e) {
            console.error("Error in processRateCon:", e);
        }
    }

    console.log("Gemini Raw Output:", rawText);

    return {
        updatedDoc,
        extractedData,
        rawText,
        confidence,
        modelUsed: llmModel,
        rateConId // Explicit return property
    }
}

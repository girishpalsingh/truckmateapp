// supabase/functions/generate-pdf/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import puppeteer from "npm:puppeteer-core@21.4.0";
import jwt from "npm:jsonwebtoken@9.0.0";
import { config } from "../_shared/config.ts";

const BROWSER_WS_URL = config.pdfservice.browserUrl;
const BROWSER_TOKEN = config.pdfservice.browserToken;

console.log(`[Init] PDF Service loaded. Target Browser: ${BROWSER_WS_URL}`);

// Setup Supabase Client (Service Role for Storage Uploads)
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
    try {
        // ------------------------------------------------------------------
        // 2. SECURITY GATEKEEPER
        // ------------------------------------------------------------------
        const authHeader = req.headers.get('Authorization') || "";
        const token = authHeader.replace("Bearer ", "");

        if (!token) {
            return new Response(JSON.stringify({ error: "Missing Authorization Token" }), {
                status: 401, headers: { "Content-Type": "application/json" }
            });
        }

        // Decode token to verify it is a "Service Role" (Internal Backend) call
        // We skip signature verification because the Supabase Gateway (Kong) has already verified it.
        // We just need to check the claims.
        const payload = jwt.decode(token) as { role: string } | null;

        if (!payload || payload.role !== 'service_role') {
            console.error(`[Auth Block] Attempted access by role: ${payload?.role}`);
            return new Response(JSON.stringify({ error: "Forbidden: Only internal services can use this." }), {
                status: 403, headers: { "Content-Type": "application/json" }
            });
        }

        // ------------------------------------------------------------------
        // 3. PARSE INPUT
        // ------------------------------------------------------------------
        const { html, css, bucketName, uploadPath } = await req.json();

        if (!html || !bucketName || !uploadPath) {
            return new Response(JSON.stringify({ error: "Missing required fields: html, bucketName, or uploadPath" }), {
                status: 400, headers: { "Content-Type": "application/json" }
            });
        }

        console.log(`[Render Start] Generating PDF for: ${uploadPath}`);

        // ------------------------------------------------------------------
        // 4. CONNECT TO REMOTE BROWSER
        // ------------------------------------------------------------------
        const connectionUrl = `${BROWSER_WS_URL}?token=${BROWSER_TOKEN}`;

        let browser;
        try {
            browser = await puppeteer.connect({
                browserWSEndpoint: connectionUrl,
            });
        } catch (e) {
            console.error("Failed to connect to Docker Browser:", e);
            throw new Error("PDF Renderer Service Unavailable");
        }

        const page = await browser.newPage();

        // ------------------------------------------------------------------
        // 5. RENDER PDF
        // ------------------------------------------------------------------
        // Inject CSS into Head to ensure it applies correctly
        const finalContent = css
            ? `<!DOCTYPE html><html><head><style>${css}</style></head><body>${html}</body></html>`
            : html;

        // 'networkidle0' waits until external resources (fonts, images) are loaded
        await page.setContent(finalContent, { waitUntil: "networkidle0" });

        const pdfBuffer = await page.pdf({
            format: "A4",
            printBackground: true, // Essential for colored badges/backgrounds
            margin: { top: "20px", bottom: "20px", left: "20px", right: "20px" },
        });

        await page.close();
        await browser.disconnect();

        // ------------------------------------------------------------------
        // 6. UPLOAD TO STORAGE
        // ------------------------------------------------------------------
        console.log(`[Upload] Saving to ${bucketName}/${uploadPath}`);

        const { data, error: uploadError } = await supabase.storage
            .from(bucketName)
            .upload(uploadPath, pdfBuffer, {
                contentType: "application/pdf",
                upsert: true,
            });

        if (uploadError) {
            console.error("[Upload Error]", uploadError);
            throw new Error(`Storage Upload Failed: ${uploadError.message}`);
        }

        // ------------------------------------------------------------------
        // 7. SUCCESS RESPONSE
        // ------------------------------------------------------------------
        // Construct the public URL (if bucket is public)
        const fullUrl = `${supabaseUrl}/storage/v1/object/public/${bucketName}/${data.path}`;

        return new Response(
            JSON.stringify({
                success: true,
                message: "PDF Generated Successfully",
                path: data.path,
                fullUrl: fullUrl
            }),
            { status: 200, headers: { "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("[Worker Error]", error);
        return new Response(
            JSON.stringify({ error: error.message || "Internal Server Error" }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});
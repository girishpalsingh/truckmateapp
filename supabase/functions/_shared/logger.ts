import { config } from "./config.ts";

export async function withLogging(
    req: Request,
    handler: (req: Request) => Promise<Response>,
): Promise<Response> {
    const start = performance.now();
    const method = req.method;
    const url = req.url;

    // Check if debug mode is enabled
    // We check both the config object (from app_config.json) and an environment variable
    const isDebug = config.development?.enabled === true || Deno.env.get("DEBUG") === "true";

    if (method === "OPTIONS") {
        return handler(req);
    }

    // [ENTRY] Log always or just in debug? 
    // Usually entry/exit is good to always have for tracing, but body logging should be debug only.
    // User asked: "so that in debug mode we get logs for each functions entry and exit point"
    // implies entry/exit might be noisy otherwise.
    // However, basic request logging is standard. Let's log ENTRY/EXIT if debug is on.

    if (isDebug) {
        console.log(`[ENTRY] ${method} ${url}`);
    } else {
        // Minimal log for production
        console.log(`[REQ] ${method} ${url}`);
    }

    // Try to Clone request to log body without consuming it
    // Note: If the request body stream is already consumed, this will fail.
    // We assume this is the first thing called in serve().
    if (isDebug) {
        try {
            const clone = req.clone();
            const reqBody = await clone.text();
            if (reqBody) {
                console.log(`[REQUEST BODY]:`, reqBody);
            }
        } catch (e) {
            console.warn(`[REQUEST] Could not read body:`, e);
        }
    }

    let res: Response;
    try {
        res = await handler(req);
    } catch (e) {
        console.error(`[ERROR] Uncaught exception in handler:`, e);
        const duration = performance.now() - start;
        if (isDebug) console.log(`[EXIT] ${method} ${url} - Status: 500 - Duration: ${duration.toFixed(2)}ms`);
        throw e; // Re-throw to let runtime handle it or correct response
    }

    const duration = performance.now() - start;

    if (isDebug) {
        console.log(`[EXIT] ${method} ${url} - Status: ${res.status} - Duration: ${duration.toFixed(2)}ms`);

        // Clone response to read body
        try {
            const resClone = res.clone();
            const resText = await resClone.text();
            console.log(`[RESPONSE BODY]`, resText);
        } catch (e) {
            console.warn(`[RESPONSE] Could not read response body:`, e);
        }
    } else {
        console.log(`[RES] ${res.status} - ${duration.toFixed(2)}ms`);
    }

    return res;
}

export async function withLogging(
    req: Request,
    handler: (req: Request) => Promise<Response>,
): Promise<Response> {
    const method = req.method;
    const url = req.url;

    if (method === "OPTIONS") {
        return handler(req);
    }

    console.log(`[REQUEST] ${method} ${url}`);

    // Try to Clone request to log body without consuming it
    // Note: If the request body stream is already consumed, this will fail.
    // We assume this is the first thing called in serve().
    let reqBody = "";
    try {
        const clone = req.clone();
        reqBody = await clone.text();
        if (reqBody) {
            console.log(`[REQUEST BODY]:`, reqBody);
        }
    } catch (e) {
        console.warn(`[REQUEST] Could not read body:`, e);
    }

    const res = await handler(req);

    // Clone response to read body
    try {
        const resClone = res.clone();
        const resText = await resClone.text();
        console.log(`[RESPONSE] ${res.status}`, resText);
    } catch (e) {
        console.warn(`[RESPONSE] Could not read response body:`, e);
        console.log(`[RESPONSE] ${res.status}`);
    }

    return res;
}

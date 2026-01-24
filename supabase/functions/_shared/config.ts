import appConfig from "../../../config/app_config.json" with { type: "json" };

export const config = {
    development: {
        enabled: appConfig.development.enabled,
        default_otp: appConfig.development.default_otp,
        skip_twilio: appConfig.development.skip_twilio,
        skip_email: appConfig.development.skip_email,
        mock_llm: appConfig.development.mock_llm,
    },
    supabase: {
        url: Deno.env.get("SUPABASE_URL") ?? appConfig.supabase.project_url,
        anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? appConfig.supabase.anon_key,
        serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? appConfig.supabase.service_role_key,
    },
    twilio: {
        account_sid: Deno.env.get("TWILIO_ACCOUNT_SID") ?? appConfig.twilio.account_sid,
        auth_token: Deno.env.get("TWILIO_AUTH_TOKEN") ?? appConfig.twilio.auth_token,
        phone_number: Deno.env.get("TWILIO_PHONE_NUMBER") ?? appConfig.twilio.phone_number,
    },
    resend: {
        api_key: Deno.env.get("RESEND_API_KEY") ?? appConfig.resend.api_key,
        from_email: Deno.env.get("RESEND_FROM_EMAIL") ?? appConfig.resend.from_email,
    },
    llm: {
        gemini: {
            api_key: Deno.env.get("GEMINI_API_KEY") ?? appConfig.llm.gemini.api_key,
            model: appConfig.llm.gemini.model,
        }
    },
    pdfservice: {
        browserUrl: Deno.env.get("BROWSER_WS_URL") ?? appConfig.pdfservice.browserUrl,
        browserToken: Deno.env.get("BROWSER_TOKEN") ?? appConfig.pdfservice.browserToken,
    }
};

console.log("LLM Config:", config.llm);

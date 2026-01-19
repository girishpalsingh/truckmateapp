# TruckMate Configuration

This file contains sensitive credentials. Add to .gitignore!

## Required Configuration

Update the `app_config.json` with your credentials:

### PowerSync
- `powersync.instance_url`: Your PowerSync instance URL
- `powersync.api_key`: Your PowerSync API key

### LLM (Gemini)
- `llm.gemini.api_key`: Google Gemini API key

### Twilio (for production OTP)
- `twilio.account_sid`: Twilio Account SID
- `twilio.auth_token`: Twilio Auth Token
- `twilio.phone_number`: Twilio phone number

### Resend (for email)
- `resend.api_key`: Resend API key

## Development Mode

When `development.enabled` is `true`:
- OTP verification uses `development.default_otp` (123456)
- Twilio SMS is skipped
- Email sending is skipped

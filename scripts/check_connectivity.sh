#!/bin/bash

CONFIG_FILE="config/app_config.json"

echo "🔍 Checking Supabase Connectivity..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: $CONFIG_FILE not found!"
    exit 1
fi

# Extract URL and Key using basics (assuming simple json structure, or we could use jq)
# Using python/node one-liner is safer if jq is missing, but let's try grep/sed for simplicity if jq is missing.
# Ideally use jq.

if command -v jq &> /dev/null; then
    URL=$(jq -r '.supabase.project_url' "$CONFIG_FILE")
    KEY=$(jq -r '.supabase.anon_key' "$CONFIG_FILE")
else
    # Fallback to grep/sed (fragile but works for this specific file format)
    URL=$(grep -o '"project_url": "[^"]*' "$CONFIG_FILE" | grep -o 'http[^"]*')
    KEY=$(grep -o '"anon_key": "[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
fi

echo "📂 Config loaded:"
echo "   URL: $URL"
echo "   Key: ${KEY:0:10}..."

if [ -z "$URL" ] || [ -z "$KEY" ]; then
    echo "❌ Failed to parse config. Is jq installed?"
    exit 1
fi

# Test connectivity
echo "⏳ Testing connection to $URL..."

# Simple curl to /rest/v1/ (standard PostgREST root)
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" "$URL/rest/v1/")

if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "404" ]; then
    # 200 or 404 means server responded (404 might be path not found but server reachable)
    # PostgREST root usually returns Swagger/OpenAPI spec or list of tables if configured.
    echo "✅ Connection Successful! (HTTP $RESPONSE)"
else
    echo "❌ Connection Failed! (HTTP $RESPONSE)"
    echo "   Running verbose curl for debug:"
    curl -v -H "apikey: $KEY" -H "Authorization: Bearer $KEY" "$URL/rest/v1/"
fi

echo ""
echo "☁️ Testing Edge Function (auth-otp)..."
FUNCTION_URL="$URL/functions/v1/auth-otp"
# Using a seeded test user phone number
PAYLOAD='{"action": "send", "phone_number": "+15551234567"}'

echo "   Invoking: $FUNCTION_URL"
# echo "   Payload: $PAYLOAD"

EF_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$PAYLOAD" "$FUNCTION_URL")

HTTP_CODE=$(echo "$EF_RESPONSE" | tail -n1)
BODY=$(echo "$EF_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Edge Function Success! (HTTP 200)"
    echo "   Response: $BODY"
else
    echo "❌ Edge Function Failed! (HTTP $HTTP_CODE)"
    echo "   Response: $BODY"
    echo "   (Make sure Supabase functions are served locally via 'supabase functions serve' or via the main start command)"
fi

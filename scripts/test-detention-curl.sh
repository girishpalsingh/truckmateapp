#!/bin/bash

# ============================================
# Detention Invoice Flow - Curl Test Script
# ============================================
# This script tests the detention invoice workflow using curl commands
#
# Prerequisites:
# - Local Supabase running on 54321
# - Test user with phone 15550000001 exists
# 
# Usage: ./test-detention-curl.sh

set -e

# Configuration
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
PHONE="15550000001"
OTP="123456"

echo "============================================"
echo "DETENTION INVOICE CURL TESTS"
echo "============================================"
echo "URL: $SUPABASE_URL"
echo ""

# ============================================
# Step 1: Send OTP
# ============================================
echo "📱 Step 1: Sending OTP..."
SEND_RESULT=$(curl -s -X POST "$SUPABASE_URL/functions/v1/auth-otp" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -d "{\"action\": \"send\", \"phone_number\": \"$PHONE\"}")

echo "   Response: $SEND_RESULT"
echo ""

# ============================================
# Step 2: Verify OTP
# ============================================
echo "🔐 Step 2: Verifying OTP..."
VERIFY_RESULT=$(curl -s -X POST "$SUPABASE_URL/functions/v1/auth-otp" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -d "{\"action\": \"verify\", \"phone_number\": \"$PHONE\", \"otp\": \"$OTP\"}")

# Extract access token
ACCESS_TOKEN=$(echo $VERIFY_RESULT | jq -r '.session.access_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    echo "Response: $VERIFY_RESULT"
    exit 1
fi

echo "   ✅ Got access token: ${ACCESS_TOKEN:0:50}..."
echo ""

# ============================================
# Step 3: Get user profile
# ============================================
echo "👤 Step 3: Getting user profile..."
PROFILE=$(curl -s "$SUPABASE_URL/rest/v1/profiles?select=id,organization_id" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json")

USER_ID=$(echo $PROFILE | jq -r '.[0].id // empty')
ORG_ID=$(echo $PROFILE | jq -r '.[0].organization_id // empty')

echo "   User ID: $USER_ID"
echo "   Org ID: $ORG_ID"
echo ""

# ============================================
# Step 4: Find a load
# ============================================
echo "🚛 Step 4: Finding a load..."
LOADS=$(curl -s "$SUPABASE_URL/rest/v1/loads?organization_id=eq.$ORG_ID&select=id,broker_load_id&limit=1" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json")

LOAD_ID=$(echo $LOADS | jq -r '.[0].id // empty')

if [ -z "$LOAD_ID" ]; then
    echo "   ⚠️  No loads found. Create test data first."
    exit 1
fi

echo "   Load ID: $LOAD_ID"
echo ""

# ============================================
# Step 5: Create detention record
# ============================================
echo "⏱️  Step 5: Creating detention record..."
START_TIME=$(date -u -v-3H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "-3 hours" +"%Y-%m-%dT%H:%M:%SZ")
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DETENTION_RESULT=$(curl -s -X POST "$SUPABASE_URL/rest/v1/detention_records" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"organization_id\": \"$ORG_ID\",
    \"load_id\": \"$LOAD_ID\",
    \"start_time\": \"$START_TIME\",
    \"start_location_lat\": 37.7749,
    \"start_location_lng\": -122.4194,
    \"end_time\": \"$END_TIME\",
    \"end_location_lat\": 37.7750,
    \"end_location_lng\": -122.4195
  }")

DETENTION_ID=$(echo $DETENTION_RESULT | jq -r '.[0].id // .id // empty')

if [ -z "$DETENTION_ID" ]; then
    echo "   ⚠️  Failed to create detention record"
    echo "   Response: $DETENTION_RESULT"
    exit 1
fi

echo "   ✅ Detention Record ID: $DETENTION_ID"
echo ""

# ============================================
# Step 6: Create detention invoice
# Now only requires detention_record_id - everything auto-calculated!
# ============================================
echo "📄 Step 6: Creating detention invoice..."
echo "   (Rate, hours, facility all auto-calculated from database)"
INVOICE_RESULT=$(curl -s -X POST "$SUPABASE_URL/functions/v1/create-detention-invoice" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"detention_record_id\": \"$DETENTION_ID\",
    \"send_email\": false
  }")

echo "   Response:"
echo "$INVOICE_RESULT" | jq .
echo ""

# Check result
SUCCESS=$(echo $INVOICE_RESULT | jq -r '.success // false')
if [ "$SUCCESS" = "true" ]; then
    PDF_URL=$(echo $INVOICE_RESULT | jq -r '.url // empty')
    INVOICE_NUMBER=$(echo $INVOICE_RESULT | jq -r '.invoice_number // empty')
    
    echo "============================================"
    echo "✅ TEST PASSED"
    echo "============================================"
    echo "Invoice Number: $INVOICE_NUMBER"
    echo "PDF URL: $PDF_URL"
    echo ""
    
    # Optional: Try to fetch the PDF
    if [ ! -z "$PDF_URL" ]; then
        echo "Downloading PDF to /tmp/detention_invoice.pdf..."
        curl -s -o /tmp/detention_invoice.pdf "$PDF_URL"
        if [ -f /tmp/detention_invoice.pdf ]; then
            echo "✅ PDF downloaded successfully"
            ls -la /tmp/detention_invoice.pdf
        fi
    fi
else
    echo "============================================"
    echo "❌ TEST FAILED"
    echo "============================================"
    echo "$INVOICE_RESULT"
    exit 1
fi

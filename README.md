# TruckMate

A dual-interface system for small trucking carriers, replacing Axle (payment) and Expensify (expense tracking).

## Project Structure

```
truckmateapp/
├── mobile/          # Flutter app (Android/iOS/Web)
├── dashboard/       # Next.js admin dashboard  
├── supabase/        # Database migrations & Edge Functions
├── api-tester/      # Browser tool for API testing
└── config/          # Configuration files
```

## Quick Start

### 1. Configure Supabase

Edit `config/app_config.json` with your API keys:
- PowerSync credentials
- Gemini API key
- Twilio credentials (optional for dev)
- Resend API key (optional for dev)

### 2. Apply Database Schema

```bash
cd supabase
supabase db push
```

### 3. Deploy Edge Functions

```bash
supabase functions deploy auth-otp
supabase functions deploy process-document
supabase functions deploy generate-invoice
supabase functions deploy semantic-search
supabase functions deploy send-email
```

### 4. Run Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

### 5. Run Dashboard

```bash
cd dashboard
npm install
npm run dev
```

## Tech Stack

- **Mobile**: Flutter + Riverpod + PowerSync
- **Dashboard**: Next.js + Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **AI**: Gemini Flash 3.0 / OpenAI / Claude
- **OCR**: ML Kit (Android) / VisionKit (iOS)

## Features

- OTP-based authentication
- Offline-first mobile app
- Document scanning with AI extraction
- IFTA expense tracking
- Invoice generation
- Semantic search across documents
- Dual-language support (English/Punjabi)

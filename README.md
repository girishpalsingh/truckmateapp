# TruckMate App

TruckMate is a comprehensive logistics and trucking management application designed to streamline operations for fleet owners and drivers. It leverages a modern tech stack with a **Flutter** mobile application and a **Supabase** backend to provide real-time updates, intelligent document processing, and efficient trip management.

## Architecture

*   **Mobile App**: Built with **Flutter**, supporting both Android and iOS. Implements a clean architecture with separate layers for Presentation (UI), Domain (Business Logic), and Data (Repositories/Services).
*   **Backend**: Powered by **Supabase**.
    *   **Database**: PostgreSQL with Row Level Security (RLS) for data protection.
    *   **Auth**: Secure phone number OTP authentication.
    *   **Storage**: Secure storage for documents (Rate Cons, BOLs, receipts).
    *   **Edge Functions**: Server-side logic for complex tasks like AI document analysis, PDF generation, and notifications.

## Key Features & User Flows

### 1. Authentication & Onboarding
*   **Phone Login**: Users sign in using their phone number via OTP verification.
*   **Role-Based Access**:
    *   **Fleet Owner/Dispatcher**: Full access to manage loads, drivers, and fleet documents.
    *   **Driver**: focused view for active trips, assigned loads, and document scanning.
*   **Profile Management**: Users can manage their profile details and preferences.

### 2. Rate Confirmation Management
The core workflow starts with a Rate Confirmation (Rate Con):
*   **Ingestion**:
    *   **Upload**: Users upload Rate Con PDFs or images.
    *   **AI Analysis**: The `process-rate-con-response` edge function (powered by Gemini Flash) analyzes the document to extract critical details (Pick-up/Drop-off locations, dates, rates, weight, commodities).
*   **Risk Analysis**:
    *   **Clause Detection**: The system automatically flags "danger" clauses (e.g., penalties, strict delivery windows).
    *   **Bilingual Support**: Risk clauses and titles are presented in both **English and Punjabi** for better accessibility.
*   **Review & Approval**:
    *   Users review extracted data and risk flags.
    *   **Approval**: Converting a Rate Con into an active **Load** and **Trip**.
    *   **Dispatcher Sheet**: Automatically generates a professional dispatch sheet PDF for the driver.

### 3. Trip & Load Management
Once a load is created, it moves to the execution phase:
*   **Active Trip Tracking**: Drivers have a dedicated view for their current active trip.
*   **Stops & Routing**:
    *   Visual timeline of stops (Pickup, Delivery, Fuel).
    *   **Location Tracking**: Real-time background location updates to track progress.
    *   **Stop Status**: Drivers update status (Arrived, Loading/Unloading, Departed).
*   **Detention Timer**: Built-in timer to track detention time at facilities, helpful for detention pay claims.
*   **Expenses**: Drivers can log trip-related expenses (fuel, tolls, repairs) directly against the trip.

### 4. Document Management
*   **Bill of Lading (BOL)**:
    *   Integrated scanner to capture BOLs upon delivery.
    *   AI processing to validate BOL details against the original Load/Rate Con.
*   **Document Scanner**: General-purpose scanner for receipts, certificates, etc.
*   **Pending Documents**: A reminder queue for missing essential documents (e.g., missing signed BOL after trip completion).
*   **Document Vault**: Centralized storage for all trip-related files.

### 5. Fleet Dashboard
*   **Overview**: A high-level view of active loads, revenue, and fleet status.
*   **Notifications**: Real-time alerts for new assignments, document issues, or status updates.

## Supabase Backend Functions

The backend logic is modularized into Supabase Edge Functions:

| Function Name | Description |
| :--- | :--- |
| `process-rate-con-response` | Parses Rate Confirmation documents using AI (Gemini). |
| `generate-dispatch-sheet` | Generates a specific PDF dispatch sheet for drivers from load data. |
| `process-document` | Generic entry point for processing uploaded documents. |
| `admin-organizations` | Manages organization hierarchy and data. |
| `auth-otp` | Handles custom OTP authentication flows. |
| `record-location` | Ingests and stores driver location pings. |
| `send-email` | Sends email notifications via Resend. |
| `semantic-search` | Enables search capabilities across documents/data. |

## Database Schema Highlights

*   `rate_confirmations`: Stores raw and parsed Rate Con data.
*   `loads`: Represents an accepted job, linking Rate Cons to Trips.
*   `trips`: The execution entity of a load, tracking driver progress.
*   `rc_risk_clauses`: Stores detected risk clauses (English & Punjabi).
*   `documents`: Central metadata table for all stored files.
*   `bill_of_ladings`: Structured data extracted from BOLs.
*   `profiles` & `organizations`: User and tenant management.

## Getting Started

1.  **Prerequisites**:
    *   Flutter SDK (Latest Stable)
    *   Supabase CLI (for local backend development)
2.  **Mobile App**:
    *   Navigate to `mobile/`.
    *   Run `flutter pub get`.
    *   Run `flutter run` to start the app on a simulator or device.
3.  **Backend**:
    *   Managed via Supabase CLI.
    *   Migrations in `supabase/migrations` define the schema.
    *   Functions in `supabase/functions` contain server-side logic.

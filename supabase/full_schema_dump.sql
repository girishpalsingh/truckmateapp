


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";






CREATE TYPE "public"."dispatch_assignment_status_enum" AS ENUM (
    'ACTIVE',
    'COMPLETED',
    'CANCELLED'
);


ALTER TYPE "public"."dispatch_assignment_status_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."dispatch_event_type_enum" AS ENUM (
    'SHEET_GENERATED',
    'SHEET_SENT_APP',
    'SHEET_VIEWED',
    'ACKNOWLEDGED',
    'REFUSED'
);


ALTER TYPE "public"."dispatch_event_type_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."document_status" AS ENUM (
    'pending_review',
    'approved',
    'rejected'
);


ALTER TYPE "public"."document_status" OWNER TO "postgres";


CREATE TYPE "public"."document_type" AS ENUM (
    'rate_con',
    'bol',
    'lumper_receipt',
    'fuel_receipt',
    'scale_ticket',
    'detention_evidence',
    'other'
);


ALTER TYPE "public"."document_type" OWNER TO "postgres";


CREATE TYPE "public"."expense_category" AS ENUM (
    'fuel',
    'tolls',
    'scale',
    'lumper',
    'repair',
    'maintenance',
    'food',
    'lodging',
    'fee',
    'detention_payout',
    'other'
);


ALTER TYPE "public"."expense_category" OWNER TO "postgres";


CREATE TYPE "public"."load_status" AS ENUM (
    'assigned',
    'picked_up',
    'delivered',
    'invoiced',
    'paid'
);


ALTER TYPE "public"."load_status" OWNER TO "postgres";


CREATE TYPE "public"."notification_event_enum" AS ENUM (
    'Before Contract signature',
    'Daily Check Call',
    'Status',
    'Detention Start',
    'Delivery Delay',
    'Delivery Done',
    'Pickup Delay',
    'Pickup Done',
    'Other'
);


ALTER TYPE "public"."notification_event_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."rate_con_status" AS ENUM (
    'under_review',
    'processing',
    'approved',
    'rejected'
);


ALTER TYPE "public"."rate_con_status" OWNER TO "supabase_admin";


CREATE TYPE "public"."stop_type_enum" AS ENUM (
    'Pickup',
    'Delivery'
);


ALTER TYPE "public"."stop_type_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."traffic_light_status" AS ENUM (
    'RED',
    'YELLOW',
    'GREEN'
);


ALTER TYPE "public"."traffic_light_status" OWNER TO "supabase_admin";


CREATE TYPE "public"."trailer_door_type_enum" AS ENUM (
    'SWING',
    'ROLL_UP'
);


ALTER TYPE "public"."trailer_door_type_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."trailer_status_enum" AS ENUM (
    'ACTIVE',
    'MAINTENANCE',
    'SOLD'
);


ALTER TYPE "public"."trailer_status_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."trailer_type_enum" AS ENUM (
    'DRY_VAN',
    'REEFER',
    'FLATBED',
    'STEP_DECK',
    'POWER_ONLY'
);


ALTER TYPE "public"."trailer_type_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."trigger_type_enum" AS ENUM (
    'Absolute',
    'Relative',
    'Conditional'
);


ALTER TYPE "public"."trigger_type_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."trip_status" AS ENUM (
    'deadhead',
    'active',
    'completed'
);


ALTER TYPE "public"."trip_status" OWNER TO "postgres";


CREATE TYPE "public"."truck_status_enum" AS ENUM (
    'ACTIVE',
    'MAINTENANCE',
    'SOLD'
);


ALTER TYPE "public"."truck_status_enum" OWNER TO "supabase_admin";


CREATE TYPE "public"."user_role" AS ENUM (
    'systemadmin',
    'orgadmin',
    'owner',
    'manager',
    'dispatcher',
    'driver'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    rc RECORD;
    new_load_id UUID;
BEGIN
    -- 1. Get the rate confirmation details
    SELECT * INTO rc FROM rate_confirmations WHERE id = rate_con_uuid;
    
    IF rc IS NULL THEN
        RAISE EXCEPTION 'Rate confirmation not found';
    END IF;

    -- 2. Update status to approved
    UPDATE rate_confirmations 
    SET status = 'approved', updated_at = NOW()
    WHERE id = rate_con_uuid;

    -- 3. Create the Load
    INSERT INTO loads (
        organization_id,
        broker_name,
        broker_mc_number,
        broker_load_id,
        primary_rate,
        payment_terms,
        commodity_type,
        weight_lbs,
        status,
        created_at,
        updated_at
    ) VALUES (
        rc.organization_id,
        rc.broker_name,
        rc.broker_mc_number,
        rc.rate_con_id,
        rc.total_rate_amount,  -- FIXED: Changed from total_amount to total_rate_amount
        rc.payment_terms,
        rc.commodity_name,
        rc.commodity_weight,
        'assigned',
        NOW(),
        NOW()
    )
    RETURNING id INTO new_load_id;
    
    RETURN new_load_id;
END;
$$;


ALTER FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb") OWNER TO "supabase_admin";


CREATE OR REPLACE FUNCTION "public"."calculate_trip_profit"("trip_uuid" "uuid") RETURNS TABLE("revenue" numeric, "expenses" numeric, "detention_revenue" numeric, "net_profit" numeric, "profit_margin" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  load_rate NUMERIC;
  load_fuel_surcharge NUMERIC;
  detention_rate NUMERIC;
  trip_detention_hours NUMERIC;
  total_expenses NUMERIC;
BEGIN
  -- Get load revenue
  SELECT l.primary_rate, l.fuel_surcharge, l.detention_rate_per_hour
  INTO load_rate, load_fuel_surcharge, detention_rate
  FROM trips t
  JOIN loads l ON t.load_id = l.id
  WHERE t.id = trip_uuid;
  
  -- Get detention hours
  SELECT t.detention_hours INTO trip_detention_hours
  FROM trips t WHERE t.id = trip_uuid;
  
  -- Calculate total expenses
  SELECT COALESCE(SUM(e.amount), 0) INTO total_expenses
  FROM expenses e WHERE e.trip_id = trip_uuid;
  
  RETURN QUERY SELECT
    COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) AS revenue,
    total_expenses AS expenses,
    COALESCE(detention_rate * trip_detention_hours, 0) AS detention_revenue,
    (COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) + 
     COALESCE(detention_rate * trip_detention_hours, 0) - total_expenses) AS net_profit,
    CASE WHEN COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) > 0
      THEN ((COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0) + 
             COALESCE(detention_rate * trip_detention_hours, 0) - total_expenses) /
            (COALESCE(load_rate, 0) + COALESCE(load_fuel_surcharge, 0))) * 100
      ELSE 0
    END AS profit_margin;
END;
$$;


ALTER FUNCTION "public"."calculate_trip_profit"("trip_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_org_id_from_path"("path" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Extract first segment of path (organization_id)
  RETURN (split_part(path, '/', 1))::uuid;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."get_org_id_from_path"("path" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_org_id_from_path"("path" "text") IS 'Extracts organization ID from document path. Path format: {org_id}/{trip_id}/{filename}';



CREATE OR REPLACE FUNCTION "public"."get_user_organization"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN (
    SELECT organization_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$;


ALTER FUNCTION "public"."get_user_organization"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_organization_id"() RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT organization_id FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."get_user_organization_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_role"() RETURNS "public"."user_role"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."get_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_full_name TEXT;
BEGIN
  -- Extract full name from metadata or default
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User');

  -- Insert into profiles
  INSERT INTO public.profiles (
    id,
    full_name,
    phone_number,
    email_address,
    role
  )
  VALUES (
    NEW.id,
    v_full_name,
    NEW.phone,
    NEW.email,
    'driver'::public.user_role
  )
  ON CONFLICT (id) DO UPDATE SET
    phone_number = EXCLUDED.phone_number,
    email_address = EXCLUDED.email_address,
    full_name = EXCLUDED.full_name,
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_system_admin"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT role = 'systemadmin' FROM profiles WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."is_system_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_audit_id uuid;
BEGIN
  INSERT INTO document_audit_log (
    document_id,
    organization_id,
    user_id,
    action,
    storage_path,
    metadata
  ) VALUES (
    p_document_id,
    p_organization_id,
    auth.uid(),
    p_action,
    p_storage_path,
    p_metadata
  )
  RETURNING id INTO v_audit_id;
  
  RETURN v_audit_id;
END;
$$;


ALTER FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text", "p_metadata" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text", "p_metadata" "jsonb") IS 'Logs a document access event. Call from Edge Functions for download/view/share/process events.';



CREATE OR REPLACE FUNCTION "public"."search_documents"("org_id" "uuid", "query_embedding" "public"."vector", "match_threshold" double precision DEFAULT 0.78, "match_count" integer DEFAULT 10) RETURNS TABLE("document_id" "uuid", "content" "text", "similarity" double precision, "metadata" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    de.document_id,
    de.content,
    1 - (de.embedding <=> query_embedding) AS similarity,
    de.metadata
  FROM document_embeddings de
  JOIN documents d ON de.document_id = d.id
  WHERE d.organization_id = org_id
    AND 1 - (de.embedding <=> query_embedding) > match_threshold
  ORDER BY de.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;


ALTER FUNCTION "public"."search_documents"("org_id" "uuid", "query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_log_document_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  PERFORM log_document_event(
    OLD.id,
    OLD.organization_id,
    'delete',
    OLD.image_url,
    jsonb_build_object(
      'type', OLD.type,
      'deleted_at', now()
    )
  );
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."trigger_log_document_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_log_document_upload"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  PERFORM log_document_event(
    NEW.id,
    NEW.organization_id,
    'upload',
    NEW.image_url,
    jsonb_build_object(
      'type', NEW.type,
      'status', NEW.status
    )
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_log_document_upload"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid",
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "table_name" "text",
    "record_id" "uuid",
    "old_data" "jsonb",
    "new_data" "jsonb",
    "ip_address" "inet",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."charges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_confirmation_id" "uuid" NOT NULL,
    "description" character varying(255),
    "amount" numeric(10,2),
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."charges" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."clause_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "risk_clause_id" "uuid" NOT NULL,
    "title" character varying(100),
    "description" "text",
    "trigger_type" "public"."trigger_type_enum",
    "start_event" "public"."notification_event_enum",
    "deadline_iso" timestamp with time zone,
    "relative_minutes_offset" integer,
    "original_clause_excerpt" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."clause_notifications" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."dispatch_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "load_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "driver_id" "uuid",
    "co_driver_id" "uuid",
    "truck_id" "uuid",
    "trailer_id" "uuid",
    "dispatcher_user_id" "uuid",
    "assigned_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "status" "public"."dispatch_assignment_status_enum" DEFAULT 'ACTIVE'::"public"."dispatch_assignment_status_enum"
);


ALTER TABLE "public"."dispatch_assignments" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."dispatch_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "load_id" "uuid" NOT NULL,
    "driver_id" "uuid",
    "event_type" "public"."dispatch_event_type_enum",
    "meta_data" "jsonb",
    "occurred_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."dispatch_events" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."document_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "document_id" "uuid",
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "storage_path" "text",
    "ip_address" "inet",
    "user_agent" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "document_audit_log_action_check" CHECK (("action" = ANY (ARRAY['upload'::"text", 'download'::"text", 'view'::"text", 'delete'::"text", 'share'::"text", 'process'::"text"])))
);


ALTER TABLE "public"."document_audit_log" OWNER TO "postgres";


COMMENT ON TABLE "public"."document_audit_log" IS 'Immutable audit trail for all document operations. Used for security compliance and debugging.';



CREATE TABLE IF NOT EXISTS "public"."document_embeddings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "document_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "embedding" "public"."vector"(1536),
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."document_embeddings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "trip_id" "uuid",
    "load_id" "uuid",
    "expense_id" "uuid",
    "type" "public"."document_type" NOT NULL,
    "image_url" "text" NOT NULL,
    "thumbnail_url" "text",
    "page_count" integer DEFAULT 1,
    "file_size_bytes" integer,
    "ai_data" "jsonb",
    "ai_confidence" numeric(3,2),
    "dangerous_clauses" "jsonb",
    "local_text_extraction" "text",
    "status" "public"."document_status" DEFAULT 'pending_review'::"public"."document_status",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "uploaded_by" "uuid",
    "title" "text"
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


COMMENT ON COLUMN "public"."documents"."title" IS 'Title of document';



CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "trip_id" "uuid",
    "category" "public"."expense_category" NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "vendor_name" "text",
    "jurisdiction" "text",
    "gallons" numeric(10,3),
    "price_per_gallon" numeric(10,3),
    "date" "date" DEFAULT CURRENT_DATE,
    "is_reimbursable" boolean DEFAULT false,
    "receipt_image_path" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facility_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "normalized_name" character varying(255),
    "address_hash" character varying(64),
    "full_address" "text",
    "access_notes_en" "text",
    "access_notes_pb" "text",
    "safety_requirements_en" "jsonb",
    "safety_requirements_pb" "jsonb",
    "amenities_en" "jsonb",
    "amenities_pb" "jsonb",
    "avg_dwell_time_minutes" integer,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."facility_profiles" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."ifta_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "quarter" "text" NOT NULL,
    "year" integer NOT NULL,
    "quarter_number" integer NOT NULL,
    "jurisdiction_data" "jsonb",
    "total_miles" integer,
    "total_gallons" numeric(10,2),
    "total_tax_due" numeric(10,2),
    "status" "text" DEFAULT 'draft'::"text",
    "pdf_path" "text",
    "generated_at" timestamp with time zone DEFAULT "now"(),
    "reviewed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "submitted_at" timestamp with time zone
);


ALTER TABLE "public"."ifta_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "trip_id" "uuid",
    "load_id" "uuid",
    "invoice_number" "text" NOT NULL,
    "issued_date" "date" DEFAULT CURRENT_DATE,
    "due_date" "date",
    "subtotal" numeric(10,2),
    "detention_charges" numeric(10,2) DEFAULT 0,
    "reimbursable_expenses" numeric(10,2) DEFAULT 0,
    "total_amount" numeric(10,2),
    "recipient_email" "text",
    "recipient_name" "text",
    "pdf_path" "text",
    "status" "text" DEFAULT 'draft'::"text",
    "sent_at" timestamp with time zone,
    "paid_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."load_dispatch_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "load_id" "uuid" NOT NULL,
    "fuel_plan" "jsonb",
    "total_planned_miles" numeric(10,2),
    "route_warnings_en" "text"[],
    "route_warnings_pb" "text"[],
    "driver_pickup_instructions_en" "text",
    "driver_pickup_instructions_pb" "text",
    "driver_delivery_instructions_en" "text",
    "driver_delivery_instructions_pb" "text",
    "special_handling_instructions_en" "text",
    "special_handling_instructions_pb" "text",
    "generated_sheet_url" "text",
    "qr_code_payload" "text",
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."load_dispatch_config" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."loads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "broker_name" "text",
    "broker_mc_number" "text",
    "broker_load_id" "text",
    "primary_rate" numeric(10,2),
    "fuel_surcharge" numeric(10,2) DEFAULT 0,
    "payment_terms" "text" DEFAULT 'Net 30'::"text",
    "detention_policy_hours" integer DEFAULT 2,
    "detention_rate_per_hour" numeric(10,2) DEFAULT 50,
    "commodity_type" "text",
    "weight_lbs" numeric(10,2),
    "pickup_address" "jsonb",
    "delivery_address" "jsonb",
    "notes" "text",
    "status" "public"."load_status" DEFAULT 'assigned'::"public"."load_status",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."loads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "title" "text" NOT NULL,
    "body" "text",
    "data" "jsonb",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "legal_entity_name" "text",
    "admin_id" "uuid",
    "registered_address" "jsonb",
    "mailing_address" "jsonb",
    "logo_image_link" "text",
    "tax_id" "text",
    "mc_dot_number" "text",
    "website" "text",
    "llm_provider" "text" DEFAULT 'gemini'::"text",
    "approval_email_address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."organizations"."is_active" IS 'Whether the organization is active and can have users log in';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "organization_id" "uuid",
    "role" "public"."user_role" DEFAULT 'driver'::"public"."user_role" NOT NULL,
    "full_name" "text" NOT NULL,
    "phone_number" "text",
    "email_address" "text",
    "address" "jsonb",
    "identity_document_id" "text",
    "preferred_language" "text" DEFAULT 'en'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_active" boolean DEFAULT true NOT NULL,
    "fcm_token" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."is_active" IS 'Whether the user account is active and can log in';



CREATE TABLE IF NOT EXISTS "public"."rate_con_dispatcher_instructions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_confirmation_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "title_en" "text",
    "title_punjab" "text",
    "description_en" "text",
    "description_punjab" "text",
    "trigger_type" character varying(50),
    "deadline_iso" timestamp with time zone,
    "relative_minutes_offset" integer,
    "original_clause" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."rate_con_dispatcher_instructions" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."rate_confirmations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_con_id" character varying(50) NOT NULL,
    "document_id" "uuid",
    "organization_id" "uuid" NOT NULL,
    "broker_name" character varying(255),
    "broker_mc_number" character varying(50),
    "broker_address" "text",
    "broker_phone" character varying(50),
    "broker_email" character varying(255),
    "carrier_name" character varying(255),
    "carrier_dot_number" character varying(50),
    "carrier_address" "text",
    "carrier_phone" character varying(50),
    "carrier_email" character varying(255),
    "carrier_equipment_type" character varying(100),
    "carrier_equipment_number" character varying(50),
    "total_rate_amount" numeric(10,2),
    "currency" character varying(3) DEFAULT 'USD'::character varying,
    "payment_terms" "text",
    "commodity_name" character varying(255),
    "commodity_weight" numeric(10,2),
    "commodity_unit" character varying(20),
    "pallet_count" integer,
    "overall_traffic_light" "public"."traffic_light_status",
    "status" character varying(20) DEFAULT 'under_review'::character varying,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."rate_confirmations" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."reference_numbers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_confirmation_id" "uuid" NOT NULL,
    "ref_type" character varying(50),
    "ref_value" character varying(255),
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."reference_numbers" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."risk_clauses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_confirmation_id" "uuid" NOT NULL,
    "clause_type" character varying(50),
    "traffic_light" "public"."traffic_light_status" NOT NULL,
    "clause_title" character varying(255),
    "clause_title_punjabi" "text",
    "danger_simple_language" "text",
    "danger_simple_punjabi" "text",
    "original_text" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."risk_clauses" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."stops" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rate_confirmation_id" "uuid" NOT NULL,
    "sequence_number" integer NOT NULL,
    "stop_type" "public"."stop_type_enum" NOT NULL,
    "address" "text",
    "contact_person" character varying(255),
    "phone" character varying(50),
    "email" character varying(255),
    "scheduled_arrival" timestamp with time zone,
    "scheduled_departure" timestamp with time zone,
    "date_raw" character varying(50),
    "time_raw" character varying(50),
    "special_instructions" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."stops" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."trailers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "trailer_number" character varying(20) NOT NULL,
    "vin" character varying(17),
    "license_plate" character varying(20),
    "license_plate_state" character varying(2),
    "length_feet" integer,
    "width_inches" integer DEFAULT 102,
    "height_inches" integer DEFAULT 110,
    "max_weight_lbs" integer DEFAULT 45000,
    "trailer_type" "public"."trailer_type_enum",
    "door_type" "public"."trailer_door_type_enum",
    "floor_type" character varying(20) DEFAULT 'WOOD'::character varying,
    "has_e_track" boolean DEFAULT false,
    "is_food_grade" boolean DEFAULT false,
    "reefer_unit_make" character varying(50),
    "reefer_engine_hours" numeric(10,1),
    "status" "public"."trailer_status_enum" DEFAULT 'ACTIVE'::"public"."trailer_status_enum",
    "current_location_lat" numeric(9,6),
    "current_location_lng" numeric(9,6),
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "trailers_length_feet_check" CHECK (("length_feet" = ANY (ARRAY[28, 48, 53])))
);


ALTER TABLE "public"."trailers" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "public"."trips" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "load_id" "uuid",
    "truck_id" "uuid",
    "driver_id" "uuid",
    "origin_address" "text",
    "destination_address" "text",
    "origin_coordinates" "jsonb",
    "destination_coordinates" "jsonb",
    "appointment_pickup" timestamp with time zone,
    "arrival_pickup" timestamp with time zone,
    "departure_pickup" timestamp with time zone,
    "appointment_delivery" timestamp with time zone,
    "arrival_delivery" timestamp with time zone,
    "departure_delivery" timestamp with time zone,
    "odometer_start" integer,
    "odometer_end" integer,
    "total_miles" integer GENERATED ALWAYS AS (
CASE
    WHEN (("odometer_end" IS NOT NULL) AND ("odometer_start" IS NOT NULL)) THEN ("odometer_end" - "odometer_start")
    ELSE NULL::integer
END) STORED,
    "fuel_gallons_total" numeric(10,2) DEFAULT 0,
    "detention_hours" numeric(5,2) DEFAULT 0,
    "notes" "text",
    "status" "public"."trip_status" DEFAULT 'active'::"public"."trip_status",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."trips" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."trucks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "truck_number" "text" NOT NULL,
    "make" "text",
    "model" "text",
    "year" integer,
    "vin" "text",
    "license_plate" "text",
    "current_odometer" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "license_plate_state" character varying(2),
    "fuel_type" character varying(20) DEFAULT 'DIESEL'::character varying,
    "is_carb_compliant" boolean DEFAULT false,
    "has_sleeper" boolean DEFAULT true,
    "eld_device_id" character varying(50),
    "status" "public"."truck_status_enum" DEFAULT 'ACTIVE'::"public"."truck_status_enum",
    "current_location_lat" numeric(9,6),
    "current_location_lng" numeric(9,6)
);


ALTER TABLE "public"."trucks" OWNER TO "postgres";


ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."charges"
    ADD CONSTRAINT "charges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clause_notifications"
    ADD CONSTRAINT "clause_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_load_id_status_key" UNIQUE ("load_id", "status");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."dispatch_events"
    ADD CONSTRAINT "dispatch_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."document_audit_log"
    ADD CONSTRAINT "document_audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."document_embeddings"
    ADD CONSTRAINT "document_embeddings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facility_profiles"
    ADD CONSTRAINT "facility_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ifta_reports"
    ADD CONSTRAINT "ifta_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."load_dispatch_config"
    ADD CONSTRAINT "load_dispatch_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."loads"
    ADD CONSTRAINT "loads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_phone_number_key" UNIQUE ("phone_number");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rate_con_dispatcher_instructions"
    ADD CONSTRAINT "rate_con_dispatcher_instructions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rate_confirmations"
    ADD CONSTRAINT "rate_confirmations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reference_numbers"
    ADD CONSTRAINT "reference_numbers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."risk_clauses"
    ADD CONSTRAINT "risk_clauses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stops"
    ADD CONSTRAINT "stops_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trailers"
    ADD CONSTRAINT "trailers_organization_id_trailer_number_key" UNIQUE ("organization_id", "trailer_number");



ALTER TABLE ONLY "public"."trailers"
    ADD CONSTRAINT "trailers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trips"
    ADD CONSTRAINT "trips_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."trucks"
    ADD CONSTRAINT "trucks_organization_id_truck_number_key" UNIQUE ("organization_id", "truck_number");



ALTER TABLE ONLY "public"."trucks"
    ADD CONSTRAINT "trucks_pkey" PRIMARY KEY ("id");



CREATE INDEX "document_embeddings_embedding_idx" ON "public"."document_embeddings" USING "ivfflat" ("embedding" "public"."vector_cosine_ops") WITH ("lists"='100');



CREATE INDEX "idx_audit_log_action" ON "public"."document_audit_log" USING "btree" ("action");



CREATE INDEX "idx_audit_log_created_at" ON "public"."document_audit_log" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_audit_log_doc_id" ON "public"."document_audit_log" USING "btree" ("document_id");



CREATE INDEX "idx_audit_log_org_id" ON "public"."document_audit_log" USING "btree" ("organization_id");



CREATE INDEX "idx_audit_log_user_id" ON "public"."document_audit_log" USING "btree" ("user_id");



CREATE INDEX "idx_audit_org" ON "public"."audit_log" USING "btree" ("organization_id");



CREATE INDEX "idx_audit_user" ON "public"."audit_log" USING "btree" ("user_id");



CREATE INDEX "idx_charges_rate_con" ON "public"."charges" USING "btree" ("rate_confirmation_id");



CREATE INDEX "idx_clause_notifications_risk_clause" ON "public"."clause_notifications" USING "btree" ("risk_clause_id");



CREATE INDEX "idx_documents_ai_data" ON "public"."documents" USING "gin" ("ai_data");



CREATE INDEX "idx_documents_org" ON "public"."documents" USING "btree" ("organization_id");



CREATE INDEX "idx_documents_status" ON "public"."documents" USING "btree" ("status");



CREATE INDEX "idx_documents_trip" ON "public"."documents" USING "btree" ("trip_id");



CREATE INDEX "idx_expenses_jurisdiction" ON "public"."expenses" USING "btree" ("jurisdiction");



CREATE INDEX "idx_expenses_org" ON "public"."expenses" USING "btree" ("organization_id");



CREATE INDEX "idx_expenses_trip" ON "public"."expenses" USING "btree" ("trip_id");



CREATE INDEX "idx_ifta_org_quarter" ON "public"."ifta_reports" USING "btree" ("organization_id", "year", "quarter_number");



CREATE INDEX "idx_invoices_org" ON "public"."invoices" USING "btree" ("organization_id");



CREATE INDEX "idx_loads_org" ON "public"."loads" USING "btree" ("organization_id");



CREATE INDEX "idx_loads_status" ON "public"."loads" USING "btree" ("status");



CREATE INDEX "idx_profiles_org" ON "public"."profiles" USING "btree" ("organization_id");



CREATE INDEX "idx_profiles_phone" ON "public"."profiles" USING "btree" ("phone_number");



CREATE INDEX "idx_rate_confirmations_doc" ON "public"."rate_confirmations" USING "btree" ("document_id");



CREATE INDEX "idx_rate_confirmations_org" ON "public"."rate_confirmations" USING "btree" ("organization_id");



CREATE INDEX "idx_rate_confirmations_rate_con_id" ON "public"."rate_confirmations" USING "btree" ("rate_con_id");



CREATE INDEX "idx_reference_numbers_rate_con" ON "public"."reference_numbers" USING "btree" ("rate_confirmation_id");



CREATE INDEX "idx_risk_clauses_rate_con" ON "public"."risk_clauses" USING "btree" ("rate_confirmation_id");



CREATE INDEX "idx_stops_rate_con" ON "public"."stops" USING "btree" ("rate_confirmation_id");



CREATE INDEX "idx_stops_sequence" ON "public"."stops" USING "btree" ("rate_confirmation_id", "sequence_number");



CREATE INDEX "idx_trips_driver" ON "public"."trips" USING "btree" ("driver_id");



CREATE INDEX "idx_trips_org" ON "public"."trips" USING "btree" ("organization_id");



CREATE INDEX "idx_trips_status" ON "public"."trips" USING "btree" ("status");



CREATE INDEX "idx_trips_truck" ON "public"."trips" USING "btree" ("truck_id");



CREATE INDEX "idx_trucks_org" ON "public"."trucks" USING "btree" ("organization_id");



CREATE OR REPLACE TRIGGER "document_delete_audit" BEFORE DELETE ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_log_document_delete"();



CREATE OR REPLACE TRIGGER "document_upload_audit" AFTER INSERT ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_log_document_upload"();



CREATE OR REPLACE TRIGGER "update_documents_updated_at" BEFORE UPDATE ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_expenses_updated_at" BEFORE UPDATE ON "public"."expenses" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_invoices_updated_at" BEFORE UPDATE ON "public"."invoices" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_loads_updated_at" BEFORE UPDATE ON "public"."loads" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_organizations_updated_at" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_rate_confirmations_updated_at" BEFORE UPDATE ON "public"."rate_confirmations" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_trips_updated_at" BEFORE UPDATE ON "public"."trips" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_trucks_updated_at" BEFORE UPDATE ON "public"."trucks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_log"
    ADD CONSTRAINT "audit_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."charges"
    ADD CONSTRAINT "charges_rate_confirmation_id_fkey" FOREIGN KEY ("rate_confirmation_id") REFERENCES "public"."rate_confirmations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clause_notifications"
    ADD CONSTRAINT "clause_notifications_risk_clause_id_fkey" FOREIGN KEY ("risk_clause_id") REFERENCES "public"."risk_clauses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_co_driver_id_fkey" FOREIGN KEY ("co_driver_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_dispatcher_user_id_fkey" FOREIGN KEY ("dispatcher_user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_trailer_id_fkey" FOREIGN KEY ("trailer_id") REFERENCES "public"."trailers"("id");



ALTER TABLE ONLY "public"."dispatch_assignments"
    ADD CONSTRAINT "dispatch_assignments_truck_id_fkey" FOREIGN KEY ("truck_id") REFERENCES "public"."trucks"("id");



ALTER TABLE ONLY "public"."dispatch_events"
    ADD CONSTRAINT "dispatch_events_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."dispatch_events"
    ADD CONSTRAINT "dispatch_events_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dispatch_events"
    ADD CONSTRAINT "dispatch_events_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."document_audit_log"
    ADD CONSTRAINT "document_audit_log_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."document_audit_log"
    ADD CONSTRAINT "document_audit_log_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."document_audit_log"
    ADD CONSTRAINT "document_audit_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."document_embeddings"
    ADD CONSTRAINT "document_embeddings_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facility_profiles"
    ADD CONSTRAINT "facility_profiles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "fk_admin" FOREIGN KEY ("admin_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ifta_reports"
    ADD CONSTRAINT "ifta_reports_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ifta_reports"
    ADD CONSTRAINT "ifta_reports_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."load_dispatch_config"
    ADD CONSTRAINT "load_dispatch_config_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."load_dispatch_config"
    ADD CONSTRAINT "load_dispatch_config_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loads"
    ADD CONSTRAINT "loads_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."rate_con_dispatcher_instructions"
    ADD CONSTRAINT "rate_con_dispatcher_instructions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rate_con_dispatcher_instructions"
    ADD CONSTRAINT "rate_con_dispatcher_instructions_rate_confirmation_id_fkey" FOREIGN KEY ("rate_confirmation_id") REFERENCES "public"."rate_confirmations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rate_confirmations"
    ADD CONSTRAINT "rate_confirmations_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."rate_confirmations"
    ADD CONSTRAINT "rate_confirmations_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reference_numbers"
    ADD CONSTRAINT "reference_numbers_rate_confirmation_id_fkey" FOREIGN KEY ("rate_confirmation_id") REFERENCES "public"."rate_confirmations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."risk_clauses"
    ADD CONSTRAINT "risk_clauses_rate_confirmation_id_fkey" FOREIGN KEY ("rate_confirmation_id") REFERENCES "public"."rate_confirmations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stops"
    ADD CONSTRAINT "stops_rate_confirmation_id_fkey" FOREIGN KEY ("rate_confirmation_id") REFERENCES "public"."rate_confirmations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trailers"
    ADD CONSTRAINT "trailers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trips"
    ADD CONSTRAINT "trips_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."trips"
    ADD CONSTRAINT "trips_load_id_fkey" FOREIGN KEY ("load_id") REFERENCES "public"."loads"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."trips"
    ADD CONSTRAINT "trips_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."trips"
    ADD CONSTRAINT "trips_truck_id_fkey" FOREIGN KEY ("truck_id") REFERENCES "public"."trucks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."trucks"
    ADD CONSTRAINT "trucks_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



CREATE POLICY "Drivers can manage own trips" ON "public"."trips" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND (("driver_id" = "auth"."uid"()) OR ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND (("driver_id" = "auth"."uid"()) OR ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))));



CREATE POLICY "Drivers can update load status" ON "public"."loads" FOR UPDATE TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = 'driver'::"public"."user_role"))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = 'driver'::"public"."user_role")));



CREATE POLICY "Managers can delete org profiles" ON "public"."profiles" FOR DELETE TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])) AND ("id" <> "auth"."uid"())));



CREATE POLICY "Managers can insert dispatch events" ON "public"."dispatch_events" FOR INSERT TO "authenticated" WITH CHECK (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Managers can insert profiles" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage IFTA reports" ON "public"."ifta_reports" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'orgadmin'::"public"."user_role"])))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage dispatch assignments" ON "public"."dispatch_assignments" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage facility profiles" ON "public"."facility_profiles" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage invoices" ON "public"."invoices" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'orgadmin'::"public"."user_role"])))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage load dispatch config" ON "public"."load_dispatch_config" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage loads" ON "public"."loads" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage rate con instructions" ON "public"."rate_con_dispatcher_instructions" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage trailers" ON "public"."trailers" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can manage trucks" ON "public"."trucks" TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Managers can update org profiles" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))) WITH CHECK ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Org admins can update own organization" ON "public"."organizations" FOR UPDATE TO "authenticated" USING ((("id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['orgadmin'::"public"."user_role", 'owner'::"public"."user_role"])))) WITH CHECK ((("id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['orgadmin'::"public"."user_role", 'owner'::"public"."user_role"]))));



CREATE POLICY "Service can insert audit logs" ON "public"."audit_log" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "System admins full access to organizations" ON "public"."organizations" TO "authenticated" USING ("public"."is_system_admin"()) WITH CHECK ("public"."is_system_admin"());



CREATE POLICY "System admins full access to profiles" ON "public"."profiles" TO "authenticated" USING ("public"."is_system_admin"()) WITH CHECK ("public"."is_system_admin"());



CREATE POLICY "Users can access own org charges" ON "public"."charges" USING (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"())))))) WITH CHECK (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"()))))));



CREATE POLICY "Users can access own org clause notifications" ON "public"."clause_notifications" USING (("risk_clause_id" IN ( SELECT "rc"."id"
   FROM ("public"."risk_clauses" "rc"
     JOIN "public"."rate_confirmations" "r" ON (("rc"."rate_confirmation_id" = "r"."id")))
  WHERE ("r"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"())))))) WITH CHECK (("risk_clause_id" IN ( SELECT "rc"."id"
   FROM ("public"."risk_clauses" "rc"
     JOIN "public"."rate_confirmations" "r" ON (("rc"."rate_confirmation_id" = "r"."id")))
  WHERE ("r"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"()))))));



CREATE POLICY "Users can access own org rate confirmations" ON "public"."rate_confirmations" USING (("organization_id" IN ( SELECT "profiles"."organization_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())))) WITH CHECK (("organization_id" IN ( SELECT "profiles"."organization_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



CREATE POLICY "Users can access own org reference numbers" ON "public"."reference_numbers" USING (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"())))))) WITH CHECK (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"()))))));



CREATE POLICY "Users can access own org risk clauses" ON "public"."risk_clauses" USING (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"())))))) WITH CHECK (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"()))))));



CREATE POLICY "Users can access own org stops" ON "public"."stops" USING (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"())))))) WITH CHECK (("rate_confirmation_id" IN ( SELECT "rate_confirmations"."id"
   FROM "public"."rate_confirmations"
  WHERE ("rate_confirmations"."organization_id" IN ( SELECT "profiles"."organization_id"
           FROM "public"."profiles"
          WHERE ("profiles"."id" = "auth"."uid"()))))));



CREATE POLICY "Users can create documents" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can create expenses" ON "public"."expenses" FOR INSERT TO "authenticated" WITH CHECK (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can update notifications for their organization" ON "public"."notifications" FOR UPDATE USING (("organization_id" IN ( SELECT "profiles"."organization_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



CREATE POLICY "Users can update own documents" ON "public"."documents" FOR UPDATE TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND (("trip_id" IN ( SELECT "trips"."id"
   FROM "public"."trips"
  WHERE ("trips"."driver_id" = "auth"."uid"()))) OR ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))));



CREATE POLICY "Users can update own expenses" ON "public"."expenses" FOR UPDATE TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND (("trip_id" IN ( SELECT "trips"."id"
   FROM "public"."trips"
  WHERE ("trips"."driver_id" = "auth"."uid"()))) OR ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'manager'::"public"."user_role", 'dispatcher'::"public"."user_role", 'orgadmin'::"public"."user_role"])))));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "Users can view notifications for their organization" ON "public"."notifications" FOR SELECT USING ((("organization_id" IN ( SELECT "profiles"."organization_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))) AND (("user_id" IS NULL) OR ("user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view org IFTA reports" ON "public"."ifta_reports" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org audit logs" ON "public"."audit_log" FOR SELECT TO "authenticated" USING ((("organization_id" = "public"."get_user_organization_id"()) AND ("public"."get_user_role"() = ANY (ARRAY['owner'::"public"."user_role", 'orgadmin'::"public"."user_role"]))));



CREATE POLICY "Users can view org dispatch assignments" ON "public"."dispatch_assignments" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org dispatch events" ON "public"."dispatch_events" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org document embeddings" ON "public"."document_embeddings" FOR SELECT TO "authenticated" USING (("document_id" IN ( SELECT "documents"."id"
   FROM "public"."documents"
  WHERE ("documents"."organization_id" = "public"."get_user_organization_id"()))));



CREATE POLICY "Users can view org documents" ON "public"."documents" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org expenses" ON "public"."expenses" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org facility profiles" ON "public"."facility_profiles" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org invoices" ON "public"."invoices" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org load dispatch config" ON "public"."load_dispatch_config" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org loads" ON "public"."loads" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org rate con instructions" ON "public"."rate_con_dispatcher_instructions" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org trailers" ON "public"."trailers" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org trips" ON "public"."trips" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view org trucks" ON "public"."trucks" FOR SELECT TO "authenticated" USING (("organization_id" = "public"."get_user_organization_id"()));



CREATE POLICY "Users can view own organization" ON "public"."organizations" FOR SELECT TO "authenticated" USING (("id" = "public"."get_user_organization_id"()));



ALTER TABLE "public"."audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."charges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clause_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dispatch_assignments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."dispatch_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."document_audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."document_embeddings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."facility_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ifta_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."load_dispatch_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."loads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "org_audit_read_policy" ON "public"."document_audit_log" FOR SELECT TO "authenticated" USING (("organization_id" = ( SELECT "profiles"."organization_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"()))));



ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rate_con_dispatcher_instructions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rate_confirmations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reference_numbers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."risk_clauses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "server_audit_insert_policy" ON "public"."document_audit_log" FOR INSERT TO "authenticated" WITH CHECK (false);



ALTER TABLE "public"."stops" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trailers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trips" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."trucks" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";































































































































































GRANT ALL ON FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb") TO "postgres";
GRANT ALL ON FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_rate_con_and_create_load"("rate_con_uuid" "uuid", "edits" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_trip_profit"("trip_uuid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_trip_profit"("trip_uuid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_trip_profit"("trip_uuid" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_org_id_from_path"("path" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_org_id_from_path"("path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_org_id_from_path"("path" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_organization"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_organization"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_organization"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_organization_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_system_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_system_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_system_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_document_event"("p_document_id" "uuid", "p_organization_id" "uuid", "p_action" "text", "p_storage_path" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_documents"("org_id" "uuid", "query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_documents"("org_id" "uuid", "query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_documents"("org_id" "uuid", "query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_log_document_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_log_document_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_log_document_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_log_document_upload"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_log_document_upload"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_log_document_upload"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";












GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";



GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";









GRANT ALL ON TABLE "public"."audit_log" TO "anon";
GRANT ALL ON TABLE "public"."audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."charges" TO "postgres";
GRANT ALL ON TABLE "public"."charges" TO "anon";
GRANT ALL ON TABLE "public"."charges" TO "authenticated";
GRANT ALL ON TABLE "public"."charges" TO "service_role";



GRANT ALL ON TABLE "public"."clause_notifications" TO "postgres";
GRANT ALL ON TABLE "public"."clause_notifications" TO "anon";
GRANT ALL ON TABLE "public"."clause_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."clause_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_assignments" TO "postgres";
GRANT ALL ON TABLE "public"."dispatch_assignments" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."dispatch_events" TO "postgres";
GRANT ALL ON TABLE "public"."dispatch_events" TO "anon";
GRANT ALL ON TABLE "public"."dispatch_events" TO "authenticated";
GRANT ALL ON TABLE "public"."dispatch_events" TO "service_role";



GRANT ALL ON TABLE "public"."document_audit_log" TO "anon";
GRANT ALL ON TABLE "public"."document_audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."document_audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."document_embeddings" TO "anon";
GRANT ALL ON TABLE "public"."document_embeddings" TO "authenticated";
GRANT ALL ON TABLE "public"."document_embeddings" TO "service_role";



GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT ALL ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";



GRANT ALL ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses" TO "service_role";



GRANT ALL ON TABLE "public"."facility_profiles" TO "postgres";
GRANT ALL ON TABLE "public"."facility_profiles" TO "anon";
GRANT ALL ON TABLE "public"."facility_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."facility_profiles" TO "service_role";



GRANT ALL ON TABLE "public"."ifta_reports" TO "anon";
GRANT ALL ON TABLE "public"."ifta_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."ifta_reports" TO "service_role";



GRANT ALL ON TABLE "public"."invoices" TO "anon";
GRANT ALL ON TABLE "public"."invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."invoices" TO "service_role";



GRANT ALL ON TABLE "public"."load_dispatch_config" TO "postgres";
GRANT ALL ON TABLE "public"."load_dispatch_config" TO "anon";
GRANT ALL ON TABLE "public"."load_dispatch_config" TO "authenticated";
GRANT ALL ON TABLE "public"."load_dispatch_config" TO "service_role";



GRANT ALL ON TABLE "public"."loads" TO "anon";
GRANT ALL ON TABLE "public"."loads" TO "authenticated";
GRANT ALL ON TABLE "public"."loads" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."rate_con_dispatcher_instructions" TO "postgres";
GRANT ALL ON TABLE "public"."rate_con_dispatcher_instructions" TO "anon";
GRANT ALL ON TABLE "public"."rate_con_dispatcher_instructions" TO "authenticated";
GRANT ALL ON TABLE "public"."rate_con_dispatcher_instructions" TO "service_role";



GRANT ALL ON TABLE "public"."rate_confirmations" TO "postgres";
GRANT ALL ON TABLE "public"."rate_confirmations" TO "anon";
GRANT ALL ON TABLE "public"."rate_confirmations" TO "authenticated";
GRANT ALL ON TABLE "public"."rate_confirmations" TO "service_role";



GRANT ALL ON TABLE "public"."reference_numbers" TO "postgres";
GRANT ALL ON TABLE "public"."reference_numbers" TO "anon";
GRANT ALL ON TABLE "public"."reference_numbers" TO "authenticated";
GRANT ALL ON TABLE "public"."reference_numbers" TO "service_role";



GRANT ALL ON TABLE "public"."risk_clauses" TO "postgres";
GRANT ALL ON TABLE "public"."risk_clauses" TO "anon";
GRANT ALL ON TABLE "public"."risk_clauses" TO "authenticated";
GRANT ALL ON TABLE "public"."risk_clauses" TO "service_role";



GRANT ALL ON TABLE "public"."stops" TO "postgres";
GRANT ALL ON TABLE "public"."stops" TO "anon";
GRANT ALL ON TABLE "public"."stops" TO "authenticated";
GRANT ALL ON TABLE "public"."stops" TO "service_role";



GRANT ALL ON TABLE "public"."trailers" TO "postgres";
GRANT ALL ON TABLE "public"."trailers" TO "anon";
GRANT ALL ON TABLE "public"."trailers" TO "authenticated";
GRANT ALL ON TABLE "public"."trailers" TO "service_role";



GRANT ALL ON TABLE "public"."trips" TO "anon";
GRANT ALL ON TABLE "public"."trips" TO "authenticated";
GRANT ALL ON TABLE "public"."trips" TO "service_role";



GRANT ALL ON TABLE "public"."trucks" TO "anon";
GRANT ALL ON TABLE "public"."trucks" TO "authenticated";
GRANT ALL ON TABLE "public"."trucks" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
































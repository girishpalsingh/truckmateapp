-- Idempotently repair the table structure
ALTER TABLE "public"."rate_con_clauses" 
ADD COLUMN IF NOT EXISTS "clause_title" text,
ADD COLUMN IF NOT EXISTS "clause_title_punjabi" text,
ADD COLUMN IF NOT EXISTS "notification_data" jsonb,
ADD COLUMN IF NOT EXISTS "notification_title" text,
ADD COLUMN IF NOT EXISTS "notification_description" text,
ADD COLUMN IF NOT EXISTS "notification_trigger_type" text,
ADD COLUMN IF NOT EXISTS "notification_deadline" date,
ADD COLUMN IF NOT EXISTS "notification_relative_offset" integer,
ADD COLUMN IF NOT EXISTS "notification_start_event" text;

-- Force schema cache reload again
NOTIFY pgrst, 'reload schema';

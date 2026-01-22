-- Drop the table to ensure clean state
DROP TABLE IF EXISTS "public"."rate_con_clauses";

-- Recreate the table with all required columns
CREATE TABLE "public"."rate_con_clauses" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "rate_con_id" uuid NOT NULL REFERENCES "public"."rate_cons"("id") ON DELETE CASCADE,
    "clause_type" text,
    "traffic_light" text,
    "clause_title" text,
    "clause_title_punjabi" text,
    "danger_simple_language" text,
    "danger_simple_punjabi" text,
    "original_text" text,
    "warning_en" text,
    "warning_pa" text,
    "notification_data" jsonb,
    "notification_title" text,
    "notification_description" text,
    "notification_trigger_type" text,
    "notification_deadline" date,
    "notification_relative_offset" integer,
    "notification_start_event" text,
    "created_at" timestamptz DEFAULT now(),
    PRIMARY KEY ("id")
);

-- Enable RLS
ALTER TABLE "public"."rate_con_clauses" ENABLE ROW LEVEL SECURITY;

-- Add permissive policy (can be restricted later if needed)
CREATE POLICY "Enable all access for authenticated users" ON "public"."rate_con_clauses"
AS PERMISSIVE FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Grant permissions
GRANT ALL ON TABLE "public"."rate_con_clauses" TO anon;
GRANT ALL ON TABLE "public"."rate_con_clauses" TO authenticated;
GRANT ALL ON TABLE "public"."rate_con_clauses" TO service_role;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

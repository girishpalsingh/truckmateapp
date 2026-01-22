ALTER TABLE "public"."rate_con_clauses"
ADD COLUMN "notification_title" text,
ADD COLUMN "notification_description" text,
ADD COLUMN "notification_trigger_type" text,
ADD COLUMN "notification_deadline" date, -- corresponds to deadline_iso YYYY-MM-DD
ADD COLUMN "notification_relative_offset" integer,
ADD COLUMN "notification_start_event" text;

NOTIFY pgrst, 'reload schema';

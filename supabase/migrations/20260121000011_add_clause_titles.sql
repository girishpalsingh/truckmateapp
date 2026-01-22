ALTER TABLE "public"."rate_con_clauses" 
ADD COLUMN "clause_title" text,
ADD COLUMN "clause_title_punjabi" text,
ADD COLUMN "notification_data" jsonb;

NOTIFY pgrst, 'reload schema';

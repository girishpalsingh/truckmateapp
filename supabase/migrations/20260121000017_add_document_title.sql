ALTER TABLE "public"."documents" 
ADD COLUMN "title" text;

NOTIFY pgrst, 'reload schema';

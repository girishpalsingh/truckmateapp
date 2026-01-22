COMMENT ON COLUMN "public"."rate_con_clauses"."clause_title" IS 'Title of the clause in English';
COMMENT ON COLUMN "public"."rate_con_clauses"."clause_title_punjabi" IS 'Title of the clause in Punjabi';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_data" IS 'Raw notification data JSON';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_title" IS 'Title for the push notification';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_description" IS 'Body/Description for the push notification';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_trigger_type" IS 'Type of trigger: Absolute, Relative, or Conditional';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_deadline" IS 'Absolute deadline date';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_relative_offset" IS 'Minutes offset for relative triggers';
COMMENT ON COLUMN "public"."rate_con_clauses"."notification_start_event" IS 'Event that starts the notification timer';

NOTIFY pgrst, 'reload schema';

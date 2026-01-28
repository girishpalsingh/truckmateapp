-- Rename risk clause columns in rc_risk_clauses table
-- title_en -> clause_title
-- title_punjabi -> clause_title_punjabi
-- explanation_en -> danger_simple_language_english
-- explanation_punjabi -> danger_simple_language_punjabi

ALTER TABLE public.rc_risk_clauses
RENAME COLUMN title_en TO clause_title;

ALTER TABLE public.rc_risk_clauses
RENAME COLUMN title_punjabi TO clause_title_punjabi;

ALTER TABLE public.rc_risk_clauses
RENAME COLUMN explanation_en TO danger_simple_language_english;

ALTER TABLE public.rc_risk_clauses
RENAME COLUMN explanation_punjabi TO danger_simple_language_punjabi;

-- Force schema cache reload
NOTIFY pgrst, 'reload schema';

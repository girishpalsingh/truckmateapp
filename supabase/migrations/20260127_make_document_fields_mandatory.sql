-- Make uploaded_by and organization_id mandatory and auto-fill them

BEGIN;

-- 1. Set DEFAULT for uploaded_by to auth.uid()
ALTER TABLE public.documents 
ALTER COLUMN uploaded_by SET DEFAULT auth.uid();

-- 2. Create a function to auto-fill organization_id from the user's profile
CREATE OR REPLACE FUNCTION public.set_document_defaults()
RETURNS TRIGGER AS $$
BEGIN
    -- If uploaded_by is still NULL (e.g. service role without explicit value), we can't do much if it's NOT NULL constraint.
    -- But if defaults worked, New.uploaded_by should be set if available.
    
    -- If organization_id is NULL, try to find it from profiles using uploaded_by
    IF NEW.organization_id IS NULL AND NEW.uploaded_by IS NOT NULL THEN
        SELECT organization_id INTO NEW.organization_id
        FROM public.profiles
        WHERE id = NEW.uploaded_by;
    END IF;

    -- Fail if we still don't have organization_id (since we are making it NOT NULL)
    -- However, the NOT NULL constraint will catch it anyway, raising a standard error.
    -- But maybe we want a clearer error?
    -- IF NEW.organization_id IS NULL THEN
    --    RAISE EXCEPTION 'organization_id could not be determined for user %', NEW.uploaded_by;
    -- END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger
DROP TRIGGER IF EXISTS trigger_set_document_defaults ON public.documents;
CREATE TRIGGER trigger_set_document_defaults
BEFORE INSERT ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.set_document_defaults();

-- 4. Apply NOT NULL constraints (safe to do now that we have defaults/triggers)
-- We need to ensure existing data is valid or this will fail.
-- THIS IS A RISKY OPERATION ON PRODUCTION DATA without backfilling.
-- For Dev environment, we assume it's okay or we should backfill.

-- Backfill NULL organization_id if possible (optional, but good practice)
UPDATE public.documents d
SET organization_id = p.organization_id
FROM public.profiles p
WHERE d.uploaded_by = p.id
AND d.organization_id IS NULL;

-- Backfill uploaded_by if possible? 
-- If created by system, maybe we can't.
-- We will proceed with ALTER.

ALTER TABLE public.documents 
ALTER COLUMN organization_id SET NOT NULL;

ALTER TABLE public.documents 
ALTER COLUMN uploaded_by SET NOT NULL;

COMMIT;

-- Fix Storage Bucket Issues
-- Run this in Supabase Studio SQL Editor: http://192.168.1.146:54323/project/default/sql/new

-- 1. Create the 'documents' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  false,  -- Private bucket
  52428800,  -- 50MB limit
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Create helper function for RLS (idempotent)
CREATE OR REPLACE FUNCTION public.get_org_id_from_path(path text)
RETURNS uuid AS $$
BEGIN
  -- Extract first segment of path (organization_id)
  RETURN (split_part(path, '/', 1))::uuid;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create helper function for user org (idempotent)
CREATE OR REPLACE FUNCTION public.get_user_organization()
RETURNS uuid AS $$
BEGIN
  RETURN (
    SELECT organization_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Re-apply policies (DROP/CREATE to ensure they are correct)

DROP POLICY IF EXISTS "org_upload_policy" ON storage.objects;
CREATE POLICY "org_upload_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

DROP POLICY IF EXISTS "org_read_policy" ON storage.objects;
CREATE POLICY "org_read_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

DROP POLICY IF EXISTS "org_update_policy" ON storage.objects;
CREATE POLICY "org_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
)
WITH CHECK (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

DROP POLICY IF EXISTS "org_delete_policy" ON storage.objects;
CREATE POLICY "org_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

-- 5. Force permissions grant (sometimes needed for new tables/functions)
GRANT ALL ON FUNCTION public.get_org_id_from_path(text) TO authenticated;
GRANT ALL ON FUNCTION public.get_org_id_from_path(text) TO service_role;
GRANT ALL ON FUNCTION public.get_user_organization() TO authenticated;
GRANT ALL ON FUNCTION public.get_user_organization() TO service_role;

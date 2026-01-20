-- Storage Configuration for Organization-Isolated Document Storage
-- Each organization's documents are stored in a shared bucket but isolated by path prefix

-- Create the main documents bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  false,  -- Private bucket - access controlled via RLS
  52428800,  -- 50MB limit per file
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- Helper function to extract organization_id from storage path
-- Path format: {organization_id}/{trip_id}/{filename}
-- Helper function to extract organization_id from storage path
-- Path format: {organization_id}/{trip_id}/{filename}
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

-- Helper function to get user's organization
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

-- Policy: Users can only upload to their organization's folder
CREATE POLICY "org_upload_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

-- Policy: Users can only read their organization's documents
CREATE POLICY "org_read_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

-- Policy: Users can only update their organization's documents
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

-- Policy: Users can only delete their organization's documents
CREATE POLICY "org_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  public.get_org_id_from_path(name) = public.get_user_organization()
);

-- Add index hint as comment for path-based queries
COMMENT ON FUNCTION public.get_org_id_from_path IS 
  'Extracts organization ID from document path. Path format: {org_id}/{trip_id}/{filename}';

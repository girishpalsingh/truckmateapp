-- Document Audit Trail
-- Logs all document access events for security and compliance

-- Create audit log table
CREATE TABLE IF NOT EXISTS document_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES documents(id) ON DELETE SET NULL,
  organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (action IN ('upload', 'download', 'view', 'delete', 'share', 'process')),
  storage_path text,
  ip_address inet,
  user_agent text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_audit_log_org_id ON document_audit_log(organization_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_doc_id ON document_audit_log(document_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON document_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON document_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON document_audit_log(action);

-- RLS: Users can only see audit logs for their organization
ALTER TABLE document_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_audit_read_policy"
ON document_audit_log FOR SELECT
TO authenticated
USING (
  organization_id = (
    SELECT organization_id FROM profiles WHERE id = auth.uid()
  )
);

-- Only allow inserts via server functions (no direct client insert)
CREATE POLICY "server_audit_insert_policy"
ON document_audit_log FOR INSERT
TO authenticated
WITH CHECK (false); -- Block direct inserts, only via functions

-- Function to log document events (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION log_document_event(
  p_document_id uuid,
  p_organization_id uuid,
  p_action text,
  p_storage_path text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS uuid AS $$
DECLARE
  v_audit_id uuid;
BEGIN
  INSERT INTO document_audit_log (
    document_id,
    organization_id,
    user_id,
    action,
    storage_path,
    metadata
  ) VALUES (
    p_document_id,
    p_organization_id,
    auth.uid(),
    p_action,
    p_storage_path,
    p_metadata
  )
  RETURNING id INTO v_audit_id;
  
  RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function to auto-log document inserts
CREATE OR REPLACE FUNCTION trigger_log_document_upload()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_document_event(
    NEW.id,
    NEW.organization_id,
    'upload',
    NEW.image_url,
    jsonb_build_object(
      'type', NEW.type,
      'status', NEW.status
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function to auto-log document deletes
CREATE OR REPLACE FUNCTION trigger_log_document_delete()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_document_event(
    OLD.id,
    OLD.organization_id,
    'delete',
    OLD.image_url,
    jsonb_build_object(
      'type', OLD.type,
      'deleted_at', now()
    )
  );
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS document_upload_audit ON documents;
CREATE TRIGGER document_upload_audit
  AFTER INSERT ON documents
  FOR EACH ROW
  EXECUTE FUNCTION trigger_log_document_upload();

DROP TRIGGER IF EXISTS document_delete_audit ON documents;
CREATE TRIGGER document_delete_audit
  BEFORE DELETE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION trigger_log_document_delete();

-- Grant execute permission on the log function
GRANT EXECUTE ON FUNCTION log_document_event TO authenticated;

-- Comment for documentation
COMMENT ON TABLE document_audit_log IS 'Immutable audit trail for all document operations. Used for security compliance and debugging.';
COMMENT ON FUNCTION log_document_event IS 'Logs a document access event. Call from Edge Functions for download/view/share/process events.';

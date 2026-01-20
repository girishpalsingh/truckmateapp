-- Add is_active column to organizations table
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- Add comment for documentation
COMMENT ON COLUMN organizations.is_active IS 'Whether the organization is active and can have users log in';

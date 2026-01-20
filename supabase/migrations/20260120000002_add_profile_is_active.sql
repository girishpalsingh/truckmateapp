-- Add is_active column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- Add comment for documentation
COMMENT ON COLUMN profiles.is_active IS 'Whether the user account is active and can log in';

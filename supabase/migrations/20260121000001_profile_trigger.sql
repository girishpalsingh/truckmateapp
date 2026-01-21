-- Migration: Create profile trigger on user creation
-- Purpose: Auto-create profile with email and phone when user is added to auth.users

-- ============================================
-- 1. Helper function to ensure profiles table has correct columns
-- ============================================

-- (Optional) If you are unsure if columns exist, you can add them. 
-- In this migration flow, we assume they were added/modified in previous steps or base schema.
-- But we will ensure the function handles the insert correctly.

-- ============================================
-- 2. Function to handle new user creation
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_full_name TEXT;
BEGIN
  -- Extract full name from metadata or default
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User');

  -- Insert into profiles
  INSERT INTO public.profiles (
    id,
    full_name,
    phone_number,
    email_address,
    role
  )
  VALUES (
    NEW.id,
    v_full_name,
    NEW.phone,
    NEW.email,
    'driver'::public.user_role
  )
  ON CONFLICT (id) DO UPDATE SET
    phone_number = EXCLUDED.phone_number,
    email_address = EXCLUDED.email_address,
    full_name = EXCLUDED.full_name,
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================
-- 3. Trigger on auth.users
-- ============================================

-- safely drop existing trigger to avoid duplicates/errors
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 4. Backfill existing users
-- ============================================

INSERT INTO public.profiles (id, full_name, phone_number, email_address, role)
SELECT 
  u.id,
  COALESCE(u.raw_user_meta_data->>'full_name', 'User'),
  u.phone,
  u.email,
  'driver'::user_role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;


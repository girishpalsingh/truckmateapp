-- Add FCM token to profiles table
-- Ideally, we might want a separate table for multiple devices per user,
-- but for now, we'll store a single current token per user profile for simplicity.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'fcm_token') THEN
        ALTER TABLE public.profiles 
        ADD COLUMN fcm_token TEXT;
    END IF;
END $$;

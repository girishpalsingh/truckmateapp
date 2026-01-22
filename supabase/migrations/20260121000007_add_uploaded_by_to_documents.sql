-- Add uploaded_by column to documents table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'uploaded_by') THEN
        ALTER TABLE public.documents 
        ADD COLUMN uploaded_by uuid REFERENCES auth.users(id);
    END IF;
END $$;

-- Update notifications RLS to allow users to view their own notifications
-- First, drop the existing policy if it exists (or we can use CREATE OR REPLACE if supported, but DROP is safer for policies usually)
DROP POLICY IF EXISTS "Users can view notifications for their organization" ON public.notifications;

CREATE POLICY "Users can view notifications for their organization"
    ON public.notifications
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM public.profiles 
            WHERE id = auth.uid()
        )
        AND (
            user_id IS NULL -- Global org notifications
            OR 
            user_id = auth.uid() -- Targeted notifications
        )
    );

-- Migration: Allow authenticated users to create loads
-- Purpose: Enable drivers/dispatchers to create loads when approving rate confirmations
-- This fixes the 42501 error when calling RateConService.approveRateCon (client-side)

-- Add INSERT policy for loads
CREATE POLICY "Users can create loads"
  ON public.loads FOR INSERT
  TO authenticated
  WITH CHECK (organization_id = get_user_organization_id());

-- Reload schema cache to apply changes immediately
NOTIFY pgrst, 'reload schema';

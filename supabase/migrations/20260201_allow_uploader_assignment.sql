-- Allow drivers to manage dispatch assignments if they uploaded the rate confirmation
-- Linking path: dispatch_assignments.load_id -> loads.active_rate_con_id -> rate_confirmations.rc_id AND rate_confirmations.created_by = auth.uid()

SET ROLE supabase_admin;

DROP POLICY IF EXISTS "Drivers can manage dispatch assignments if uploader" ON "public"."dispatch_assignments";

CREATE POLICY "Drivers can manage dispatch assignments if uploader"
ON "public"."dispatch_assignments"
FOR ALL
TO "authenticated"
USING (
  (
    -- Check if the current user is a driver (optional optimization, but policy applies to 'authenticated' so helpful)
    -- Actually, we can just check ownership directly. If they own it, they can assign it.
    auth.uid() IN (
      SELECT rc.created_by
      FROM loads l
      JOIN rate_confirmations rc ON rc.rc_id = l.active_rate_con_id
      WHERE l.id = dispatch_assignments.load_id
      -- Note: for INSERT, 'load_id' refers to the new row's load_id
    )
  )
)
WITH CHECK (
  (
    auth.uid() IN (
      SELECT rc.created_by
      FROM loads l
      JOIN rate_confirmations rc ON rc.rc_id = l.active_rate_con_id
      WHERE l.id = dispatch_assignments.load_id
    )
  )
);

RESET ROLE;

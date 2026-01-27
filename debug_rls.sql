-- Check user profile
SELECT id, role, organization_id FROM profiles WHERE id = '33743c0a-c156-4c87-bc21-382a91f89a60';

-- Check policies
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename = 'dispatch_assignments';

-- Check if helper functions work
SELECT get_user_role(); -- This will run as the current sql user (postgres), effectively useless unless we impersonate, but good to know if it exists.

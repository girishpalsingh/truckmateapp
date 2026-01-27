DO $$
BEGIN
    -- Update policy for dispatch_assignments to allow 'driver' role
    DROP POLICY IF EXISTS "Managers can manage dispatch assignments" ON public.dispatch_assignments;
    
    CREATE POLICY "Managers and drivers can manage dispatch assignments" 
    ON public.dispatch_assignments 
    FOR ALL 
    TO authenticated 
    USING (
        organization_id = get_user_organization_id() 
        AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin', 'driver')
    )
    WITH CHECK (
        organization_id = get_user_organization_id() 
        AND get_user_role() IN ('owner', 'manager', 'dispatcher', 'orgadmin', 'driver')
    );
END $$;

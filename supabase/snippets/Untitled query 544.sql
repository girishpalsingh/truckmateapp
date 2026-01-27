DO $$ begin    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loads' AND column_name = 'load_id') then        ALTER TABLE loads RENAME COLUMN load_id TO id;
    END IF;
    END $$;

    ALTER TABLE dispatch_assignments DROP CONSTRAINT IF EXISTS dispatch_assignments_load_id_fkey;
    ALTER TABLE dispatch_assignments ADD CONSTRAINT dispatch_assignments_load_id_fkey FOREIGN KEY (load_id) REFERENCES loads(id) ON DELETE CASCADE;

    ALTER TABLE dispatch_events DROP CONSTRAINT IF EXISTS dispatch_events_load_id_fkey;
    ALTER TABLE dispatch_events ADD CONSTRAINT dispatch_events_load_id_fkey FOREIGN KEY (load_id) REFERENCES loads(id) ON DELETE CASCADE;

    ALTER TABLE load_dispatch_config DROP CONSTRAINT IF EXISTS load_dispatch_config_load_id_fkey;
    ALTER TABLE load_dispatch_config ADD CONSTRAINT load_dispatch_config_load_id_fkey FOREIGN KEY (load_id) REFERENCES loads(id) ON DELETE CASCADE;

    NOTIFY pgrst, 'reload schema';
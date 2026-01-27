import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

const DB_URL = Deno.env.get("SUPABASE_DB_URL") || "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

async function main() {
    const client = new Client(DB_URL);
    await client.connect();

    try {
        console.log("Connected to DB.");

        // Switch to owner role
        await client.queryArray("SET ROLE supabase_admin");
        console.log("Switched to role 'supabase_admin'");

        console.log("Attempting fix...");

        await client.queryArray(`
            DO $$ 
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                            WHERE table_name = 'rate_confirmations' AND column_name = 'rate_con_id') THEN
                    ALTER TABLE public.rate_confirmations ADD COLUMN rate_con_id VARCHAR(50);
                    RAISE NOTICE 'Added rate_con_id column';
                ELSE
                    RAISE NOTICE 'rate_con_id column already exists';
                END IF;
            END $$;
        `);

        // Force schema cache reload
        await client.queryArray(`NOTIFY pgrst, 'reload schema';`);

        console.log("Fix applied successfully.");
    } catch (e) {
        console.error("Error applying fix:", e);
    } finally {
        await client.end();
    }
}

main();

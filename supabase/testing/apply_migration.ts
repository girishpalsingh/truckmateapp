import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

const DB_URL = Deno.env.get("SUPABASE_DB_URL") || "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

async function main() {
    console.log("Reading migration file...");
    const sql = await Deno.readTextFile("supabase/migrations/20260127_create_loads_table.sql");

    const client = new Client(DB_URL);
    await client.connect();

    try {
        console.log("Connected to DB. Applying migration...");

        // We might need to split statements if the driver doesn't support multiple stats at once (postgres.js usually does support simple multiple statements string)
        await client.queryArray(sql);

        console.log("Migration applied successfully.");
    } catch (e) {
        console.error("Error applying migration:", e);
    } finally {
        await client.end();
    }
}

main();

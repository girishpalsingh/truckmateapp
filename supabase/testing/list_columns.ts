import { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";

const DB_URL = Deno.env.get("SUPABASE_DB_URL") || "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

async function main() {
    const client = new Client(DB_URL);
    await client.connect();

    try {
        console.log("Connected to DB.");

        const rows = await client.queryObject(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'loads'
            ORDER BY ordinal_position;
        `);

        console.log("Columns in loads:");
        console.table(rows.rows);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        await client.end();
    }
}

main();

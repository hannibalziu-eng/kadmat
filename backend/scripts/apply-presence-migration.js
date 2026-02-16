
import { supabaseAdmin } from '../src/config/supabase.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function applyPresenceMigration() {
    console.log('🔄 Applying Presence Migration (Add last_seen column)...');

    const migrationPath = path.join(__dirname, '../migrations/17_add_presence_columns.sql');

    try {
        const sql = fs.readFileSync(migrationPath, 'utf8');

        // Split by semicolon to run statements individually if needed, 
        // but exec_sql usually handles blocks.
        // Let's try running the whole block.

        console.log('📝 Reading SQL from:', migrationPath);

        const { error } = await supabaseAdmin.rpc('exec_sql', {
            sql_query: sql
        });

        if (error) {
            console.error('❌ Error applying migration via RPC:', error.message);
            console.log('\n⚠️  If `exec_sql` RPC is missing, please run the following SQL manually in Supabase Dashboard -> SQL Editor:\n');
            console.log(sql);
        } else {
            console.log('✅ Successfully applied migration!');
        }

    } catch (err) {
        console.error('❌ Error reading/executing migration:', err.message);
    }
}

applyPresenceMigration();

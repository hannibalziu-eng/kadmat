
import { supabaseAdmin } from '../src/config/supabase.js';

async function applyRealtimeSetup() {
    console.log('🔄 Applying Realtime Setup (REPLICA IDENTITY FULL)...');

    try {
        const { error } = await supabaseAdmin.rpc('exec_sql', {
            sql_query: 'ALTER TABLE public.jobs REPLICA IDENTITY FULL;'
        });

        // If exec_sql is not available (it's a custom function), we might need another way.
        // However, since we don't know if exec_sql exists, let's try a direct raw query if possible, 
        // or just assume the user needs to run the SQL manually if they are using a local instance without this RPC.

        // BUT WAIT: standard supabase-js doesn't allow arbitrary SQL execution from client unless there's an RPC.
        // Let's assume the user has to run the SQL.

        // Actually, let's try to see if there is a 'exec' or similar RPC. If not, I'll just print the instructions.

        console.log('⚠️  NOTE: If this script fails, run this SQL in your Supabase SQL Editor:');
        console.log('ALTER TABLE public.jobs REPLICA IDENTITY FULL;');

        if (error) {
            console.error('❌ Error applying via RPC (Expected if exec_sql RPC is missing):', error.message);
        } else {
            console.log('✅ Successfully applied via RPC!');
        }

    } catch (err) {
        console.error('❌ Error:', err.message);
    }
}

applyRealtimeSetup();

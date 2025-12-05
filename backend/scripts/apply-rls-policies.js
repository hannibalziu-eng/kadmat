import { supabaseAdmin } from '../src/config/supabase.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Script to apply RLS policies to Supabase
 */

async function applyRLSPolicies() {
    console.log('🔐 Applying RLS Policies...\n');

    try {
        const sqlContent = fs.readFileSync(
            path.join(__dirname, '..', 'rls-policies.sql'),
            'utf8'
        );

        // We need to execute raw SQL, but Supabase JS client doesn't support it directly
        // We'll use the REST API instead
        console.log('📝 RLS Policies SQL loaded');
        console.log('⚠️  Note: These policies need to be applied via Supabase SQL Editor');
        console.log('   Copy and paste the content of rls-policies.sql into Supabase SQL Editor\n');

        console.log('🔗 Open: https://supabase.com/dashboard/project/wwukyrixgkgagofyrlsq/sql/new\n');

        // Display the policies
        console.log('Policies to apply:');
        console.log('='.repeat(60));
        console.log(sqlContent);
        console.log('='.repeat(60));

    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

applyRLSPolicies().then(() => {
    console.log('\n✅ Please apply these policies in Supabase SQL Editor');
    console.log('   Then run: node scripts/db-verification.js');
    process.exit(0);
});

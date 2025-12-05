import { supabase, supabaseAdmin } from '../src/config/supabase.js';

/**
 * Database Verification Script
 * Checks if all tables, triggers, and functions are properly set up
 */

const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    reset: '\x1b[0m'
};

async function checkTable(tableName) {
    try {
        const { data, error } = await supabase.from(tableName).select('*').limit(1);
        if (error) {
            console.log(`${colors.red}✗${colors.reset} Table '${tableName}': ${error.message}`);
            return false;
        }
        console.log(`${colors.green}✓${colors.reset} Table '${tableName}' exists and is accessible`);
        return true;
    } catch (error) {
        console.log(`${colors.red}✗${colors.reset} Table '${tableName}': ${error.message}`);
        return false;
    }
}

async function checkServices() {
    try {
        const { data, error } = await supabase.from('services').select('count');
        if (error) {
            console.log(`${colors.red}✗${colors.reset} Services check failed: ${error.message}`);
            return false;
        }

        const { count } = await supabase
            .from('services')
            .select('*', { count: 'exact', head: true });

        if (count === 0) {
            console.log(`${colors.yellow}⚠${colors.reset} Services table is empty. Run seed-data.sql`);
            return false;
        }

        console.log(`${colors.green}✓${colors.reset} Services table has ${count} services`);
        return true;
    } catch (error) {
        console.log(`${colors.red}✗${colors.reset} Services check failed: ${error.message}`);
        return false;
    }
}

async function checkTrigger() {
    try {
        // Create a test user and check if wallet is auto-created
        const testEmail = `test-trigger-${Date.now()}@example.com`;

        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email: testEmail,
            password: 'test123456',
            email_confirm: true,
            user_metadata: {
                phone: '1234567890',
                full_name: 'Trigger Test User',
                user_type: 'customer'
            }
        });

        if (authError) {
            console.log(`${colors.red}✗${colors.reset} Trigger test: Cannot create user - ${authError.message}`);
            return false;
        }

        const userId = authData.user.id;

        // Wait a bit for trigger to execute
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Check if user was created in public.users
        const { data: userData, error: userError } = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .single();

        // Check if wallet was created
        const { data: walletData, error: walletError } = await supabase
            .from('wallets')
            .select('*')
            .eq('user_id', userId)
            .single();

        // Cleanup test user
        await supabaseAdmin.auth.admin.deleteUser(userId);

        if (userError || !userData) {
            console.log(`${colors.red}✗${colors.reset} Trigger 'handle_new_user' failed: User not created in public.users`);
            return false;
        }

        if (walletError || !walletData) {
            console.log(`${colors.red}✗${colors.reset} Trigger 'handle_new_user' failed: Wallet not auto-created`);
            return false;
        }

        console.log(`${colors.green}✓${colors.reset} Trigger 'handle_new_user' is working correctly`);
        return true;

    } catch (error) {
        console.log(`${colors.red}✗${colors.reset} Trigger test failed: ${error.message}`);
        return false;
    }
}

async function checkFunction() {
    try {
        // Test get_nearby_technicians function
        const { data, error } = await supabase.rpc('get_nearby_technicians', {
            lat: 24.7136,
            long: 46.6753,
            radius_meters: 5000
        });

        if (error) {
            console.log(`${colors.red}✗${colors.reset} Function 'get_nearby_technicians': ${error.message}`);
            return false;
        }

        console.log(`${colors.green}✓${colors.reset} Function 'get_nearby_technicians' exists and works`);
        return true;
    } catch (error) {
        console.log(`${colors.red}✗${colors.reset} Function check failed: ${error.message}`);
        return false;
    }
}

async function runVerification() {
    console.log('\n🔍 Database Verification Report\n');
    console.log('================================\n');

    const results = {
        tables: true,
        services: true,
        trigger: true,
        function: true
    };

    // Check Tables
    console.log('📋 Checking Tables...');
    results.tables = await checkTable('users') && results.tables;
    results.tables = await checkTable('wallets') && results.tables;
    results.tables = await checkTable('services') && results.tables;
    results.tables = await checkTable('jobs') && results.tables;
    results.tables = await checkTable('wallet_transactions') && results.tables;
    console.log('');

    // Check Services
    console.log('🛠️  Checking Services Data...');
    results.services = await checkServices();
    console.log('');

    // Check Triggers
    console.log('⚡ Checking Triggers...');
    results.trigger = await checkTrigger();
    console.log('');

    // Check Functions
    console.log('🔧 Checking Functions...');
    results.function = await checkFunction();
    console.log('');

    // Summary
    console.log('================================');
    console.log('📊 Summary:\n');

    const allPassed = Object.values(results).every(r => r);

    if (allPassed) {
        console.log(`${colors.green}✅ All checks passed! Database is ready.${colors.reset}\n`);
        process.exit(0);
    } else {
        console.log(`${colors.red}❌ Some checks failed. Please fix the issues above.${colors.reset}\n`);

        if (!results.services) {
            console.log(`${colors.yellow}💡 To fix: Run 'psql $DATABASE_URL -f seed-data.sql'${colors.reset}`);
        }
        if (!results.trigger) {
            console.log(`${colors.yellow}💡 To fix: Re-run 'database-schema.sql' to recreate triggers${colors.reset}`);
        }

        console.log('');
        process.exit(1);
    }
}

runVerification().catch(error => {
    console.error(`${colors.red}Fatal error:${colors.reset}`, error);
    process.exit(1);
});

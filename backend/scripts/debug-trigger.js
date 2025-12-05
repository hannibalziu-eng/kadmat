import { supabaseAdmin } from '../src/config/supabase.js';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Script to debug trigger functionality
 * This will help identify why handle_new_user trigger isn't working
 */

async function debugTrigger() {
    console.log('🔍 Debugging Trigger "handle_new_user"...\n');

    try {
        // Step 1: Create a test user
        const testEmail = `trigger-debug-${Date.now()}@example.com`;
        console.log(`Step 1: Creating test user with email: ${testEmail}`);

        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email: testEmail,
            password: 'test123456',
            email_confirm: true,
            user_metadata: {
                phone: '1234567890',
                full_name: 'Trigger Debug User',
                user_type: 'customer'
            }
        });

        if (authError) {
            console.log(`❌ Failed to create auth user: ${authError.message}`);
            return;
        }

        const userId = authData.user.id;
        console.log(`✅ Auth user created with ID: ${userId}\n`);

        // Step 2: Wait for trigger to execute
        console.log('Step 2: Waiting 2 seconds for trigger to execute...');
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Step 3: Check if user exists in public.users
        console.log('Step 3: Checking if user exists in public.users...');
        const { data: userData, error: userError } = await supabaseAdmin
            .from('users')
            .select('*')
            .eq('id', userId);

        if (userError) {
            console.log(`❌ Error querying public.users: ${userError.message}`);
        } else if (!userData || userData.length === 0) {
            console.log(`❌ User NOT found in public.users`);
            console.log(`   This means the trigger is not executing or failing silently.\n`);

            // Try to manually insert the user to test if it's a permissions issue
            console.log('Step 4: Testing manual insertion...');
            const { error: insertError } = await supabaseAdmin
                .from('users')
                .insert({
                    id: userId,
                    email: testEmail,
                    phone: '1234567890',
                    full_name: 'Trigger Debug User',
                    user_type: 'customer'
                });

            if (insertError) {
                console.log(`❌ Manual insertion failed: ${insertError.message}`);
                console.log(`   This indicates a permissions or schema issue.\n`);
            } else {
                console.log(`✅ Manual insertion succeeded!`);
                console.log(`   This means the trigger itself is the problem.\n`);
            }
        } else {
            console.log(`✅ User found in public.users:`);
            console.log(`   ID: ${userData[0].id}`);
            console.log(`   Email: ${userData[0].email}`);
            console.log(`   Full Name: ${userData[0].full_name}\n`);
        }

        // Step 5: Check if wallet was created
        console.log('Step 5: Checking if wallet was created...');
        const { data: walletData, error: walletError } = await supabaseAdmin
            .from('wallets')
            .select('*')
            .eq('user_id', userId);

        if (walletError) {
            console.log(`❌ Error querying wallets: ${walletError.message}`);
        } else if (!walletData || walletData.length === 0) {
            console.log(`❌ Wallet NOT found for user`);
        } else {
            console.log(`✅ Wallet found:`);
            console.log(`   Balance: ${walletData[0].balance} ${walletData[0].currency}\n`);
        }

        // Cleanup
        console.log('Step 6: Cleaning up test user...');
        await supabaseAdmin.auth.admin.deleteUser(userId);
        console.log('✅ Test user deleted\n');

        // Summary
        console.log('='.repeat(50));
        console.log('DIAGNOSIS SUMMARY:');
        console.log('='.repeat(50));

        if (userData && userData.length > 0 && walletData && walletData.length > 0) {
            console.log('✅ Trigger is working correctly!');
        } else if (!userData || userData.length === 0) {
            console.log('❌ ISSUE: Trigger not creating user in public.users');
            console.log('\nPossible causes:');
            console.log('1. Trigger not created or not enabled');
            console.log('2. Trigger function has an error');
            console.log('3. RLS policies blocking the insert');
            console.log('\nSolution: Check Supabase SQL Editor for trigger logs');
            console.log('Or manually execute: SELECT * FROM auth.users WHERE email LIKE \'%trigger-debug%\'');
        } else {
            console.log('⚠️  User created but wallet missing');
            console.log('The trigger partially works but wallet creation fails');
        }
        console.log('');

    } catch (error) {
        console.error('Fatal error during debug:', error);
    }
}

debugTrigger().then(() => {
    process.exit(0);
}).catch(error => {
    console.error('Script failed:', error);
    process.exit(1);
});

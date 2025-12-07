import { supabaseAdmin } from './src/config/supabase.js';

const TECH_EMAIL = 'techtest@test.com';

async function upgradeTechnician() {
    try {
        console.log('🔍 Finding user...');
        // 1. Get User ID from Auth
        const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers();

        if (listError) throw listError;

        const user = users.find(u => u.email === TECH_EMAIL);

        if (!user) {
            console.error('❌ User not found!');
            return;
        }

        console.log('✅ User found:', user.id);

        // 2. Update Public Users Table
        console.log('🔄 Updating public.users table...');
        const { error: updateError } = await supabaseAdmin
            .from('users')
            .update({
                user_type: 'technician',
                metadata: {
                    service_id: 'a72136c3-7055-4da5-aeab-5a072a3fc742'
                }
            })
            .eq('id', user.id);

        if (updateError) throw updateError;
        console.log('✅ User role updated to technician');

        // 3. Update Wallet Balance
        console.log('💰 Updating wallet balance...');
        const { error: walletError } = await supabaseAdmin
            .from('wallets')
            .upsert({
                user_id: user.id,
                balance: 100.00,
                currency: 'SAR'
            }, { onConflict: 'user_id' });

        if (walletError) throw walletError;
        console.log('✅ Wallet balance set to 100.00 SAR');

        console.log('🎉 Upgrade Complete!');
        process.exit(0);

    } catch (error) {
        console.error('❌ Upgrade Failed:', error);
        process.exit(1);
    }
}

upgradeTechnician();

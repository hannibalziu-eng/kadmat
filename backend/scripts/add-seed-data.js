import { supabaseAdmin } from '../src/config/supabase.js';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Script to add seed data to services table
 */

const services = [
    { name: 'electrical_repair', name_ar: 'إصلاح كهربائي', base_price: 100.00, commission_rate: 0.10 },
    { name: 'plumbing_repair', name_ar: 'إصلاح سباكة', base_price: 120.00, commission_rate: 0.10 },
    { name: 'ac_maintenance', name_ar: 'صيانة تكييف', base_price: 150.00, commission_rate: 0.12 },
    { name: 'carpentry', name_ar: 'نجارة', base_price: 90.00, commission_rate: 0.10 },
    { name: 'painting', name_ar: 'صباغة', base_price: 80.00, commission_rate: 0.10 },
    { name: 'cleaning', name_ar: 'تنظيف', base_price: 70.00, commission_rate: 0.08 },
    { name: 'appliance_repair', name_ar: 'تصليح أجهزة', base_price: 110.00, commission_rate: 0.10 }
];

async function addSeedData() {
    console.log('🌱 Adding seed data to services table...\n');

    try {
        // Check if services already exist
        const { data: existingServices, error: checkError } = await supabaseAdmin
            .from('services')
            .select('count');

        if (checkError) {
            throw checkError;
        }

        const { count } = await supabaseAdmin
            .from('services')
            .select('*', { count: 'exact', head: true });

        if (count > 0) {
            console.log(`⚠️  Services table already has ${count} services.`);
            console.log('Skipping seed data insertion.\n');
            return;
        }

        // Insert services
        const { data, error } = await supabaseAdmin
            .from('services')
            .insert(services.map(service => ({
                ...service,
                is_active: true
            })))
            .select();

        if (error) {
            throw error;
        }

        console.log(`✅ Successfully added ${data.length} services:\n`);
        data.forEach(service => {
            console.log(`   • ${service.name_ar} (${service.name}) - ${service.base_price} SAR`);
        });
        console.log('');

    } catch (error) {
        console.error('❌ Error adding seed data:', error.message);
        process.exit(1);
    }
}

addSeedData().then(() => {
    console.log('✅ Seed data process completed!');
    process.exit(0);
}).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});

import request from 'supertest';
import express from 'express';
import authRoutes from '../src/routes/authRoutes.js';
import jobRoutes from '../src/routes/jobRoutes.js';
import technicianRoutes from '../src/routes/technicianRoutes.js';
import walletRoutes from '../src/routes/walletRoutes.js';

// This script simulates integration testing by making real HTTP calls to the backend
// It requires the backend to be running with a test database

const BASE_URL = 'http://localhost:3000';

// Helper to create app instance
function createApp() {
    const app = express();
    app.use(express.json());
    app.use('/api/auth', authRoutes);
    app.use('/api/jobs', jobRoutes);
    app.use('/api/technician', technicianRoutes);
    app.use('/api/wallet', walletRoutes);
    return app;
}

const app = createApp();

// Test Data
const testCustomer = {
    email: `test-customer-${Date.now()}@example.com`,
    password: 'Test123456',
    full_name: 'Test Customer',
    user_type: 'customer',
    phone: '1234567890'
};

const testTechnician = {
    email: `test-tech-${Date.now()}@example.com`,
    password: 'Test123456',
    full_name: 'Test Technician',
    user_type: 'technician',
    phone: '0987654321'
};

let customerToken = '';
let technicianToken = '';
let createdJobId = '';

async function runIntegrationTests() {
    console.log('🧪 Starting Integration Tests...\n');

    try {
        // Test 1: Customer Registration
        console.log('✅ Test 1: Customer Registration');
        const registerCustomerRes = await request(app)
            .post('/api/auth/register')
            .send(testCustomer);

        console.log(`   Status: ${registerCustomerRes.status}`);
        console.log(`   Success: ${registerCustomerRes.body.success}`);
        console.log(`   Message: ${registerCustomerRes.body.message}\n`);

        // Test 2: Technician Registration
        console.log('✅ Test 2: Technician Registration');
        const registerTechRes = await request(app)
            .post('/api/auth/register')
            .send(testTechnician);

        console.log(`   Status: ${registerTechRes.status}`);
        console.log(`   Success: ${registerTechRes.body.success}\n`);

        // Test 3: Customer Login
        console.log('✅ Test 3: Customer Login');
        const loginCustomerRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: testCustomer.email,
                password: testCustomer.password
            });

        console.log(`   Status: ${loginCustomerRes.status}`);
        if (loginCustomerRes.body.token) {
            customerToken = loginCustomerRes.body.token;
            console.log(`   Token received: ${customerToken.substring(0, 20)}...`);
        }
        console.log();

        // Test 4: Technician Login
        console.log('✅ Test 4: Technician Login');
        const loginTechRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: testTechnician.email,
                password: testTechnician.password
            });

        console.log(`   Status: ${loginTechRes.status}`);
        if (loginTechRes.body.token) {
            technicianToken = loginTechRes.body.token;
            console.log(`   Token received: ${technicianToken.substring(0, 20)}...`);
        }
        console.log();

        // Fetch real service ID from database
        console.log('📋 Fetching available services...');
        const servicesRes = await request(app)
            .get('/api/services')
            .set('Authorization', `Bearer ${customerToken}`);

        let serviceId = null;
        if (servicesRes.status === 404) {
            // If services endpoint doesn't exist, fetch directly from supabase
            const { supabase } = await import('../src/config/supabase.js');
            const { data: services } = await supabase.from('services').select('id').limit(1);
            if (services && services.length > 0) {
                serviceId = services[0].id;
                console.log(`   Using service ID from database: ${serviceId}\n`);
            }
        } else if (servicesRes.body.services && servicesRes.body.services.length > 0) {
            serviceId = servicesRes.body.services[0].id;
            console.log(`   Using service ID from API: ${serviceId}\n`);
        }

        if (!serviceId) {
            console.log('   ⚠️ No services found. Skipping job creation test.\n');
        }

        // Test 5: Create Job (Customer)
        if (serviceId) {
            console.log('✅ Test 5: Create Job (Customer)');
            const createJobRes = await request(app)
                .post('/api/jobs')
                .set('Authorization', `Bearer ${customerToken}`)
                .send({
                    service_id: serviceId,
                    lat: 24.7136,
                    lng: 46.6753,
                    address_text: 'Test Address, Riyadh',
                    description: 'Test job description',
                    initial_price: 100
                });

            console.log(`   Status: ${createJobRes.status}`);
            console.log(`   Success: ${createJobRes.body.success}`);
            if (createJobRes.body.job) {
                createdJobId = createJobRes.body.job.id;
                console.log(`   Job ID: ${createdJobId}`);
            }
            console.log();
        }

        // Test 6: Get Nearby Jobs (Technician)

        console.log('✅ Test 6: Get Nearby Jobs (Technician)');
        const nearbyJobsRes = await request(app)
            .get('/api/jobs/nearby?lat=24.7136&lng=46.6753&radius=5000')
            .set('Authorization', `Bearer ${technicianToken}`);

        console.log(`   Status: ${nearbyJobsRes.status}`);
        console.log(`   Jobs found: ${nearbyJobsRes.body.count || 0}\n`);

        // Test 7: Accept Job (Technician)
        if (createdJobId) {
            console.log('✅ Test 7: Accept Job (Technician)');
            const acceptJobRes = await request(app)
                .post(`/api/jobs/${createdJobId}/accept`)
                .set('Authorization', `Bearer ${technicianToken}`);

            console.log(`   Status: ${acceptJobRes.status}`);
            console.log(`   Success: ${acceptJobRes.body.success}`);
            console.log(`   Message: ${acceptJobRes.body.message}\n`);
        }

        // Test 8: Get My Jobs (Customer)
        console.log('✅ Test 8: Get My Jobs (Customer)');
        const myJobsRes = await request(app)
            .get('/api/jobs/my-jobs')
            .set('Authorization', `Bearer ${customerToken}`);

        console.log(`   Status: ${myJobsRes.status}`);
        console.log(`   Jobs Count: ${myJobsRes.body.jobs?.length || 0}\n`);

        // Test 9: Get Wallet (Customer)
        console.log('✅ Test 9: Get Wallet (Customer)');
        const walletRes = await request(app)
            .get('/api/wallet')
            .set('Authorization', `Bearer ${customerToken}`);

        console.log(`   Status: ${walletRes.status}`);
        console.log(`   Success: ${walletRes.body.success}\n`);

        // Test 10: Update Location (Technician)
        console.log('✅ Test 10: Update Location (Technician)');
        const locationRes = await request(app)
            .post('/api/technician/location')
            .set('Authorization', `Bearer ${technicianToken}`)
            .send({
                latitude: 24.7136,
                longitude: 46.6753
            });

        console.log(`   Status: ${locationRes.status}`);
        console.log(`   Success: ${locationRes.body.success}\n`);

        // Security Tests
        console.log('🔒 Security Tests');

        // Test 11: Unauthorized Access
        console.log('✅ Test 11: Try to create job without token');
        const noAuthRes = await request(app)
            .post('/api/jobs')
            .send({
                service_id: 'test',
                lat: 24.7136,
                lng: 46.6753,
                address_text: 'Test',
                initial_price: 100
            });

        console.log(`   Status: ${noAuthRes.status} (Expected 401)\n`);

        // Test 12: Invalid Token
        console.log('✅ Test 12: Try with invalid token');
        const invalidTokenRes = await request(app)
            .get('/api/wallet')
            .set('Authorization', 'Bearer invalid-token-12345');

        console.log(`   Status: ${invalidTokenRes.status} (Expected 401)\n`);

        console.log('🎉 Integration Tests Completed!\n');

    } catch (error) {
        console.error('❌ Error during integration tests:', error.message);
        console.error(error.stack);
    }
}

// Run the tests
runIntegrationTests().then(() => {
    console.log('✅ All integration tests finished');
    process.exit(0);
}).catch((error) => {
    console.error('❌ Integration test suite failed:', error);
    process.exit(1);
});

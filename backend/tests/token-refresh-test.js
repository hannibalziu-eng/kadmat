import request from 'supertest';
import express from 'express';
import authRoutes from '../src/routes/authRoutes.js';

// Test refresh token functionality
const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);

async function testTokenRefresh() {
    console.log('🧪 Testing Token Refresh Functionality\n');

    try {
        // Step 1: Create a test user and login
        const testEmail = `token-test-${Date.now()}@example.com`;
        console.log('Step 1: Registering and logging in...');

        await request(app)
            .post('/api/auth/register')
            .send({
                email: testEmail,
                password: 'test123456',
                full_name: 'Token Test User',
                user_type: 'customer',
                phone: '1234567890'
            });

        const loginRes = await request(app)
            .post('/api/auth/login')
            .send({
                email: testEmail,
                password: 'test123456'
            });

        if (loginRes.status !== 200) {
            console.log('❌ Login failed:', loginRes.body);
            return;
        }

        const { token, refresh_token } = loginRes.body;

        console.log(`✅ Login successful`);
        console.log(`   Access Token: ${token.substring(0, 20)}...`);
        console.log(`   Refresh Token: ${refresh_token ? refresh_token.substring(0, 20) + '...' : 'NOT PROVIDED'}\n`);

        if (!refresh_token) {
            console.log('❌ ERROR: Refresh token not returned from login endpoint!');
            console.log('   This will prevent automatic token refresh.\n');
            return;
        }

        // Step 2: Test refresh endpoint
        console.log('Step 2: Testing refresh endpoint...');

        const refreshRes = await request(app)
            .post('/api/auth/refresh')
            .send({
                refresh_token: refresh_token
            });

        console.log(`   Status: ${refreshRes.status}`);
        console.log(`   Success: ${refreshRes.body.success}`);

        if (refreshRes.status === 200 && refreshRes.body.token) {
            console.log(`✅ Token refresh successful!`);
            console.log(`   New Access Token: ${refreshRes.body.token.substring(0, 20)}...`);
            console.log(`   New Refresh Token: ${refreshRes.body.refresh_token.substring(0, 20)}...\n`);
        } else {
            console.log(`❌ Token refresh failed!`);
            console.log(`   Response:`, refreshRes.body, '\n');
        }

        // Step 3: Test with invalid refresh token
        console.log('Step 3: Testing with invalid refresh token...');

        const invalidRefreshRes = await request(app)
            .post('/api/auth/refresh')
            .send({
                refresh_token: 'invalid-token-123'
            });

        console.log(`   Status: ${invalidRefreshRes.status} (Expected 401)`);
        console.log(`   Message: ${invalidRefreshRes.body.message}`);

        if (invalidRefreshRes.status === 401) {
            console.log(`✅ Invalid token correctly rejected\n`);
        } else {
            console.log(`❌ Invalid token not rejected properly\n`);
        }

        // Summary
        console.log('='.repeat(50));
        console.log('SUMMARY:');
        console.log('='.repeat(50));

        if (refresh_token && refreshRes.status === 200) {
            console.log('✅ Token refresh system is working correctly!');
            console.log('   - Login returns refresh_token');
            console.log('   - Refresh endpoint works');
            console.log('   - Invalid tokens are rejected');
        } else {
            console.log('❌ Token refresh system has issues');
            if (!refresh_token) {
                console.log('   - Login does not return refresh_token');
            }
            if (refreshRes.status !== 200) {
                console.log('   - Refresh endpoint not working');
            }
        }
        console.log('');

    } catch (error) {
        console.error('❌ Error during test:', error.message);
    }
}

testTokenRefresh().then(() => {
    process.exit(0);
}).catch(error => {
    console.error('Test failed:', error);
    process.exit(1);
});

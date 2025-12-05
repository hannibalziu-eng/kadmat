import request from 'supertest';
import express from 'express';
import authRoutes from '../src/routes/authRoutes.js';

// Simple load testing script to measure response times under concurrent requests
const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);

const CONCURRENT_REQUESTS = 10;
const TOTAL_ITERATIONS = 5;

async function measureResponseTime(endpoint, method, data = null) {
    const start = Date.now();
    try {
        if (method === 'POST') {
            await request(app).post(endpoint).send(data);
        } else {
            await request(app).get(endpoint);
        }
        return Date.now() - start;
    } catch (error) {
        return Date.now() - start;
    }
}

async function runLoadTest() {
    console.log('⚡ Starting Load Tests...\n');
    console.log(`Configuration: ${CONCURRENT_REQUESTS} concurrent requests x ${TOTAL_ITERATIONS} iterations\n`);

    const results = {
        login: [],
        register: []
    };

    // Test 1: Login Endpoint Load
    console.log('📊 Test 1: Login Endpoint Load Test');
    for (let i = 0; i < TOTAL_ITERATIONS; i++) {
        const promises = [];
        for (let j = 0; j < CONCURRENT_REQUESTS; j++) {
            promises.push(measureResponseTime('/api/auth/login', 'POST', {
                email: `test${j}@example.com`,
                password: 'test123456'
            }));
        }
        const times = await Promise.all(promises);
        results.login.push(...times);
        console.log(`   Iteration ${i + 1}: Avg ${Math.round(times.reduce((a, b) => a + b, 0) / times.length)}ms`);
    }

    // Calculate statistics for login
    const loginAvg = results.login.reduce((a, b) => a + b, 0) / results.login.length;
    const loginMin = Math.min(...results.login);
    const loginMax = Math.max(...results.login);
    const loginMedian = results.login.sort((a, b) => a - b)[Math.floor(results.login.length / 2)];

    console.log(`\n   📈 Login Statistics:`);
    console.log(`      Average: ${Math.round(loginAvg)}ms`);
    console.log(`      Min: ${loginMin}ms`);
    console.log(`      Max: ${loginMax}ms`);
    console.log(`      Median: ${loginMedian}ms\n`);

    // Test 2: Registration Endpoint Load
    console.log('📊 Test 2: Registration Endpoint Load Test');
    for (let i = 0; i < TOTAL_ITERATIONS; i++) {
        const promises = [];
        for (let j = 0; j < CONCURRENT_REQUESTS; j++) {
            promises.push(measureResponseTime('/api/auth/register', 'POST', {
                email: `newuser${Date.now()}-${j}@example.com`,
                password: 'test123456',
                full_name: 'Test User',
                user_type: 'customer',
                phone: '1234567890'
            }));
        }
        const times = await Promise.all(promises);
        results.register.push(...times);
        console.log(`   Iteration ${i + 1}: Avg ${Math.round(times.reduce((a, b) => a + b, 0) / times.length)}ms`);
    }

    // Calculate statistics for registration
    const regAvg = results.register.reduce((a, b) => a + b, 0) / results.register.length;
    const regMin = Math.min(...results.register);
    const regMax = Math.max(...results.register);
    const regMedian = results.register.sort((a, b) => a - b)[Math.floor(results.register.length / 2)];

    console.log(`\n   📈 Registration Statistics:`);
    console.log(`      Average: ${Math.round(regAvg)}ms`);
    console.log(`      Min: ${regMin}ms`);
    console.log(`      Max: ${regMax}ms`);
    console.log(`      Median: ${regMedian}ms\n`);

    // Performance Assessment
    console.log('🎯 Performance Assessment:');
    if (loginAvg < 500) {
        console.log('   ✅ Login response times are excellent (<500ms)');
    } else if (loginAvg < 1000) {
        console.log('   ⚠️  Login response times are acceptable (500-1000ms)');
    } else {
        console.log('   ❌ Login response times need optimization (>1000ms)');
    }

    if (regAvg < 1000) {
        console.log('   ✅ Registration response times are excellent (<1s)');
    } else if (regAvg < 2000) {
        console.log('   ⚠️  Registration response times are acceptable (1-2s)');
    } else {
        console.log('   ❌ Registration response times need optimization (>2s)');
    }

    console.log('\n✅ Load Tests Completed!\n');
}

runLoadTest().then(() => {
    process.exit(0);
}).catch((error) => {
    console.error('❌ Load test failed:', error);
    process.exit(1);
});

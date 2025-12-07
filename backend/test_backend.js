const API_URL = 'http://localhost:3000/api';
const EMAIL = 'usertest@test.com';
const PASSWORD = '12345678';

async function testBackend() {
    try {
        // 1. Login
        console.log('Logging in...');
        const loginRes = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: EMAIL, password: PASSWORD })
        });

        const loginData = await loginRes.json();
        if (!loginRes.ok) throw new Error(loginData.message || 'Login failed');

        const token = loginData.token;
        console.log('Login successful. Token:', token.substring(0, 20) + '...');

        // 2. Get Services
        console.log('Fetching services...');
        const servicesRes = await fetch(`${API_URL}/services`, {
            headers: { Authorization: `Bearer ${token}` }
        });

        const servicesData = await servicesRes.json();
        if (!servicesRes.ok) throw new Error(servicesData.message || 'Get Services failed');

        if (servicesData.services.length === 0) {
            console.error('No services found!');
            return;
        }

        const serviceId = servicesData.services[0].id;
        console.log('Using Service ID:', serviceId);

        // 3. Create Job
        console.log('Creating job...');
        const jobRes = await fetch(`${API_URL}/jobs`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${token}`
            },
            body: JSON.stringify({
                service_id: serviceId,
                lat: 24.7136,
                lng: 46.6753,
                address_text: 'موقعي الحالي',
                initial_price: 0,
                description: 'تجربة طلب من السكربت'
            })
        });

        const jobData = await jobRes.json();
        if (!jobRes.ok) throw new Error(jobData.message || 'Create Job failed');

        console.log('Job created successfully:', jobData);

    } catch (error) {
        console.error('Test Failed:', error.message);
    }
}

testBackend();

const API_URL = 'http://localhost:3000/api';
const TECH_EMAIL = 'techtest@test.com';
const TECH_PASSWORD = 'password123';

async function createTechnician() {
    try {
        // 1. Register Technician
        console.log('Registering technician...');
        const registerRes = await fetch(`${API_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email: TECH_EMAIL,
                password: TECH_PASSWORD,
                full_name: 'Test Technician',
                phone: '0555555555'
                // role: 'technician', // Role cannot be set publicly
                // service_id: 'a72136c3-7055-4da5-aeab-5a072a3fc742'
            })
        });

        const registerData = await registerRes.json();

        if (!registerRes.ok) {
            if (registerData.message === 'User already exists') {
                console.log('Technician already exists. Logging in...');
            } else {
                throw new Error(registerData.message || 'Registration failed');
            }
        } else {
            console.log('Technician registered successfully:', registerData);
        }

        // 2. Login to get ID
        const loginRes = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: TECH_EMAIL, password: TECH_PASSWORD })
        });

        const loginData = await loginRes.json();
        if (!loginRes.ok) throw new Error(loginData.message || 'Login failed');

        console.log('Technician Login Successful!');
        console.log('------------------------------------------------');
        console.log('📧 Email:    ', TECH_EMAIL);
        console.log('🔑 Password: ', TECH_PASSWORD);
        console.log('------------------------------------------------');

    } catch (error) {
        console.error('Setup Failed:', error.message);
    }
}

createTechnician();

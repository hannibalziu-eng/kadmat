const API_URL = 'http://localhost:3000/api';
const TECH_EMAIL = 'techtest@test.com';
const TECH_PASSWORD = 'password123';

async function verifyTechnician() {
    try {
        // Login
        console.log('Logging in as technician...');
        const loginRes = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: TECH_EMAIL, password: TECH_PASSWORD })
        });

        const loginData = await loginRes.json();
        if (!loginRes.ok) throw new Error(loginData.message || 'Login failed');

        const user = loginData.user;
        console.log('------------------------------------------------');
        console.log('User Profile Check:');
        console.log('ID:', user.id);
        console.log('Email:', user.email);
        // Supabase often puts custom fields in user_metadata or directly on the object depending on the auth response structure
        // But our backend /login might return the DB user object merged.
        // Let's inspect the whole object
        console.log('User Object:', JSON.stringify(user, null, 2));
        console.log('------------------------------------------------');

        // Check specific fields
        const userType = user.user_type || user.user_metadata?.user_type;
        const serviceId = user.metadata?.service_id || user.user_metadata?.service_id;

        if (userType === 'technician') {
            console.log('✅ SUCCESS: User is a Technician');
        } else {
            console.log('❌ FAILURE: User is still a', userType);
        }

    } catch (error) {
        console.error('Verification Failed:', error.message);
    }
}

verifyTechnician();

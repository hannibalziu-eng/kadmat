/**
 * Test Helpers (Mock-based)
 * Uses mocked Supabase for reliable testing
 */

// Mock user data for testing
export const MOCK_USERS = {
    customer: {
        id: 'mock-customer-id-001',
        email: 'customer@kadmat.test',
        user_type: 'customer',
        full_name: 'Test Customer',
        token: 'mock-customer-token-001'
    },
    technician: {
        id: 'mock-technician-id-001',
        email: 'technician@kadmat.test',
        user_type: 'technician',
        full_name: 'Test Technician',
        token: 'mock-technician-token-001'
    }
};

export function getMockCustomer() {
    return { ...MOCK_USERS.customer };
}

export function getMockTechnician() {
    return { ...MOCK_USERS.technician };
}

// Cleanup is a no-op for mocks
export async function cleanupUser(userId) {
    // No-op for mock tests
    return;
}

// For backwards compatibility
export async function createUserAndLogin(user) {
    // Return mock data instead of hitting real Supabase
    const mockUser = user.user_type === 'technician'
        ? getMockTechnician()
        : getMockCustomer();

    return {
        id: mockUser.id,
        email: mockUser.email,
        token: mockUser.token
    };
}

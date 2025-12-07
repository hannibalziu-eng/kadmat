import Joi from 'joi';
import { supabaseAdmin, supabase } from '../config/supabase.js';

// Validation Schemas
const registerSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(6).required(),
    phone: Joi.string().required(),
    full_name: Joi.string().required(),
    full_name: Joi.string().required(),
    user_type: Joi.string().valid('customer', 'technician').default('customer'),
    service_id: Joi.string().optional()
});

const loginSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required()
});

export const register = async (req, res) => {
    try {
        // 1. Validate Input
        const { error, value } = registerSchema.validate(req.body);
        if (error) return res.status(400).json({ success: false, message: error.details[0].message });

        const { email, password, phone, full_name, user_type, service_id } = value;

        // 2. Create User in Supabase Auth
        // The database trigger 'handle_new_user' will automatically create the user profile and wallet
        const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true, // Auto confirm for now
            user_metadata: { phone, full_name, user_type, service_id }
        });

        if (authError) {
            return res.status(400).json({ success: false, message: authError.message });
        }

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            user: {
                id: authUser.user.id,
                email: authUser.user.email,
                user_metadata: authUser.user.user_metadata
            }
        });

    } catch (error) {
        console.error('Register Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

export const login = async (req, res) => {
    try {
        // 1. Validate Input
        const { error, value } = loginSchema.validate(req.body);
        if (error) return res.status(400).json({ success: false, message: error.details[0].message });

        const { email, password } = value;

        // 2. Sign In with Supabase
        const { data, error: signInError } = await supabase.auth.signInWithPassword({
            email,
            password
        });

        if (signInError) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        // 3. Get User Profile & Wallet Balance
        const { data: userProfile, error: profileError } = await supabase
            .from('users')
            .select('*, wallet:wallets(balance, currency)')
            .eq('id', data.user.id)
            .single();

        if (profileError) {
            return res.status(500).json({ success: false, message: 'Error fetching user profile' });
        }

        res.json({
            success: true,
            message: 'Login successful',
            token: data.session.access_token,
            refresh_token: data.session.refresh_token,
            expires_at: data.session.expires_at,
            user: userProfile
        });

    } catch (error) {
        console.error('Login Error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
};

export const refreshToken = async (req, res) => {
    try {
        const { refresh_token } = req.body;

        if (!refresh_token) {
            return res.status(400).json({ success: false, message: 'Refresh token is required' });
        }

        // Use Supabase to refresh the session
        const { data, error } = await supabase.auth.refreshSession({ refresh_token });

        if (error) {
            return res.status(401).json({ success: false, message: 'Invalid or expired refresh token' });
        }

        // Return new access token and refresh token
        res.json({
            success: true,
            token: data.session.access_token,
            refresh_token: data.session.refresh_token,
            expires_at: data.session.expires_at
        });

    } catch (error) {
        console.error('Refresh Token Error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
};

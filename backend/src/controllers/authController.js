import Joi from 'joi';
import { supabaseAdmin, supabase } from '../config/supabase.js';
import { responseFormatter, ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';

// Validation Schemas
const registerSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(6).required(),
    phone: Joi.string().required(),
    full_name: Joi.string().required(),
    user_type: Joi.string().valid('customer', 'technician').default('customer'),
    service_id: Joi.string().optional(),
    document_urls: Joi.array().items(Joi.string().uri()).optional()
});

const loginSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required()
});

export const register = async (req, res) => {
    try {
        // 1. Validate Input
        const { error, value } = registerSchema.validate(req.body);
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const { email, password, phone, full_name, user_type, service_id, document_urls } = value;

        // 2. Create User in Supabase Auth
        // The database trigger 'handle_new_user' will automatically create the user profile and wallet
        const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true, // Auto confirm for now
            user_metadata: {
                phone,
                full_name,
                user_type,
                service_id,
                document_urls // Store documents in metadata
            }
        });

        if (authError) {
            const formatted = responseFormatter.error(
                ERROR_CODES.INVALID_INPUT,
                authError.message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const user = {
            id: authUser.user.id,
            email: authUser.user.email,
            user_metadata: authUser.user.user_metadata
        };

        return res.status(201).json({
            ...responseFormatter.success({ user }, 'User registered successfully'),
            user
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
        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                error.details[0].message,
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        const { email, password } = value;

        // 2. Sign In with Supabase
        const { data, error: signInError } = await supabase.auth.signInWithPassword({
            email,
            password
        });

        if (signInError) {
            const formatted = responseFormatter.error(
                ERROR_CODES.UNAUTHORIZED,
                'Invalid credentials',
                HTTP_STATUS.UNAUTHORIZED
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        // 3. Get User Profile & Wallet Balance
        const { data: userProfile, error: profileError } = await supabase
            .from('users')
            .select('*, wallet:wallets(balance, currency)')
            .eq('id', data.user.id)
            .single();

        if (profileError) {
            const formatted = responseFormatter.error(
                ERROR_CODES.DATABASE_ERROR,
                'Error fetching user profile',
                HTTP_STATUS.INTERNAL_SERVER_ERROR
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        return res.json({
            ...responseFormatter.success({
                token: data.session.access_token,
                refresh_token: data.session.refresh_token,
                expires_at: data.session.expires_at,
                user: userProfile
            }, 'Login successful'),
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
            const formatted = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                'Refresh token is required',
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        // Use Supabase to refresh the session
        const { data, error } = await supabase.auth.refreshSession({ refresh_token });

        if (error) {
            const formatted = responseFormatter.error(
                ERROR_CODES.UNAUTHORIZED,
                'Invalid or expired refresh token',
                HTTP_STATUS.UNAUTHORIZED
            );
            return res.status(formatted.statusCode).json(formatted.response);
        }

        return res.json({
            ...responseFormatter.success({
                token: data.session.access_token,
                refresh_token: data.session.refresh_token,
                expires_at: data.session.expires_at
            }),
            token: data.session.access_token,
            refresh_token: data.session.refresh_token,
            expires_at: data.session.expires_at
        });

    } catch (error) {
        console.error('Refresh Token Error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
};

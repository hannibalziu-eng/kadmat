import jwt from 'jsonwebtoken';

export const protect = async (req, res, next) => {
    let token;

    if (
        req.headers.authorization &&
        req.headers.authorization.startsWith('Bearer')
    ) {
        try {
            // Get token from header
            token = req.headers.authorization.split(' ')[1];

            // Verify token
            // Note: In a real production app with Supabase, you might verify this against Supabase's public key
            // or use supabase.auth.getUser(token).
            // For simplicity and speed, we trust the token if it's signed by Supabase (we need the JWT secret for this)
            // OR we just use getUser() which is safer.

            // Let's use the safest way: Ask Supabase if this token is valid.
            const { supabase } = await import('../config/supabase.js');

            const { data: { user }, error } = await supabase.auth.getUser(token);

            if (error || !user) {
                return res.status(401).json({ success: false, message: 'Not authorized, token failed' });
            }

            // Attach user to request
            req.user = user;
            next();
        } catch (error) {
            console.error(error);
            res.status(401).json({ success: false, message: 'Not authorized' });
        }
    }

    if (!token) {
        res.status(401).json({ success: false, message: 'Not authorized, no token' });
    }
};

export default protect;

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

            // Verify token using Supabase
            const { supabase } = await import('../config/supabase.js');

            const { data: { user }, error } = await supabase.auth.getUser(token);

            if (error || !user) {
                return res.status(401).json({ success: false, message: 'Not authorized, token failed' });
            }

            // Attach user to request
            req.user = user;
            return next(); // ✅ Added return
        } catch (error) {
            console.error(error);
            return res.status(401).json({ success: false, message: 'Not authorized' }); // ✅ Added return
        }
    }

    // ✅ Added return
    return res.status(401).json({ success: false, message: 'Not authorized, no token' });
};

export default protect;


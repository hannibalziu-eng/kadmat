const TRANSIENT_AUTH_ERROR_CODES = new Set([
    'ECONNRESET',
    'ETIMEDOUT',
    'UND_ERR_CONNECT_TIMEOUT',
]);

function isTransientAuthLookupError(error) {
    if (!error) return false;

    const message = String(error.message || '').toLowerCase();
    const causeCode = error.cause?.code;

    return (
        message.includes('fetch failed') ||
        message.includes('econnreset') ||
        message.includes('timeout') ||
        TRANSIENT_AUTH_ERROR_CODES.has(causeCode)
    );
}

async function resolveSupabaseUser(supabase, token) {
    const maxAttempts = 2;
    let lastError = null;
    let lastUser = null;

    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        const { data: { user } = {}, error } = await supabase.auth.getUser(token);
        lastUser = user || null;
        lastError = error || null;

        if (user && !error) {
            return { user, error: null };
        }

        if (!isTransientAuthLookupError(error) || attempt === maxAttempts) {
            return { user: lastUser, error: lastError };
        }

        await new Promise((resolve) => setTimeout(resolve, 150));
    }

    return { user: lastUser, error: lastError };
}

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

            const { user, error } = await resolveSupabaseUser(supabase, token);

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

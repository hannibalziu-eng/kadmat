import validator from 'validator';

/**
 * Sanitize input middleware
 * Escapes HTML entities and trims whitespace from string inputs
 */
export const sanitizeInput = (req, res, next) => {
    if (req.body) {
        Object.keys(req.body).forEach(key => {
            if (typeof req.body[key] === 'string') {
                // Escape HTML entities
                req.body[key] = validator.escape(req.body[key]);
                // Trim whitespace
                req.body[key] = req.body[key].trim();
            }
        });
    }

    if (req.query) {
        Object.keys(req.query).forEach(key => {
            if (typeof req.query[key] === 'string') {
                req.query[key] = validator.escape(req.query[key]);
            }
        });
    }

    next();
};

export default sanitizeInput;

import validator from 'validator';

/**
 * Sanitize input middleware.
 *
 * The API serves JSON to native/web clients, so mutating request payloads via
 * HTML escaping is destructive for data like URLs and rich text. Normalize
 * whitespace only and preserve the original value otherwise.
 */
function normalizeValue(value) {
    if (typeof value === 'string') {
        return validator.trim(value);
    }

    if (Array.isArray(value)) {
        return value.map(normalizeValue);
    }

    if (value && typeof value === 'object') {
        return Object.fromEntries(
            Object.entries(value).map(([key, nestedValue]) => [key, normalizeValue(nestedValue)]),
        );
    }

    return value;
}

export const sanitizeInput = (req, res, next) => {
    if (req.body) {
        req.body = normalizeValue(req.body);
    }

    if (req.query) {
        req.query = normalizeValue(req.query);
    }

    next();
};

export default sanitizeInput;

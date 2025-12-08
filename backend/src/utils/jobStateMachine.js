/**
 * Job State Machine
 * Defines valid state transitions and rules
 */

export const JOB_STATES = {
    PENDING: 'pending',
    SEARCHING: 'searching',
    ACCEPTED: 'accepted',
    PRICE_PENDING: 'price_pending',
    IN_PROGRESS: 'in_progress',
    COMPLETED: 'completed',
    RATED: 'rated',
    CANCELLED: 'cancelled',
    NO_TECHNICIAN: 'no_technician_found'
};

/**
 * Valid state transitions
 * Format: { currentState: [validNextStates...] }
 */
export const VALID_TRANSITIONS = {
    [JOB_STATES.PENDING]: [
        JOB_STATES.SEARCHING,
        JOB_STATES.ACCEPTED,
        JOB_STATES.CANCELLED,
        JOB_STATES.NO_TECHNICIAN
    ],
    [JOB_STATES.SEARCHING]: [
        JOB_STATES.ACCEPTED,
        JOB_STATES.CANCELLED,
        JOB_STATES.NO_TECHNICIAN
    ],
    [JOB_STATES.ACCEPTED]: [
        JOB_STATES.PRICE_PENDING,
        JOB_STATES.CANCELLED
    ],
    [JOB_STATES.PRICE_PENDING]: [
        JOB_STATES.IN_PROGRESS,
        JOB_STATES.CANCELLED
    ],
    [JOB_STATES.IN_PROGRESS]: [
        JOB_STATES.COMPLETED,
        JOB_STATES.CANCELLED
    ],
    [JOB_STATES.COMPLETED]: [
        JOB_STATES.RATED
    ],
    [JOB_STATES.RATED]: [],
    [JOB_STATES.CANCELLED]: [],
    [JOB_STATES.NO_TECHNICIAN]: [
        JOB_STATES.PENDING,     // Allows retry
        JOB_STATES.ACCEPTED     // ✅ Allow technicians to accept from this state
    ]
};

/**
 * Check if transition is valid
 * @param {string} fromStatus - Current job status
 * @param {string} toStatus - Desired job status
 * @returns {boolean} - true if transition is allowed
 */
export function isValidTransition(fromStatus, toStatus) {
    if (!VALID_TRANSITIONS[fromStatus]) {
        return false;
    }
    return VALID_TRANSITIONS[fromStatus].includes(toStatus);
}

/**
 * Get valid next states for current status
 * @param {string} currentStatus - Current job status
 * @returns {string[]} - Array of valid next states
 */
export function getValidNextStates(currentStatus) {
    return VALID_TRANSITIONS[currentStatus] || [];
}

/**
 * Validate state transition with detailed error
 * @param {string} fromStatus - Current job status
 * @param {string} toStatus - Desired job status
 * @throws {Error} - If transition is not valid
 */
export function validateTransition(fromStatus, toStatus) {
    if (!isValidTransition(fromStatus, toStatus)) {
        const validStates = getValidNextStates(fromStatus);
        const message = validStates.length > 0
            ? `Cannot transition job from '${fromStatus}' to '${toStatus}'. Valid states: ${validStates.join(', ')}`
            : `Job in '${fromStatus}' state cannot be modified`;

        const error = new Error(message);
        error.code = 'INVALID_STATUS_TRANSITION';
        error.currentStatus = fromStatus;
        error.attemptedStatus = toStatus;
        error.validStates = validStates;
        throw error;
    }
}

/**
 * Get state description (for user-friendly messages)
 */
export const STATE_DESCRIPTIONS = {
    [JOB_STATES.PENDING]: 'في انتظار قبول من فني',
    [JOB_STATES.SEARCHING]: 'جاري البحث عن فني',
    [JOB_STATES.ACCEPTED]: 'تم قبول الطلب',
    [JOB_STATES.PRICE_PENDING]: 'في انتظار موافقتك على السعر',
    [JOB_STATES.IN_PROGRESS]: 'جاري تنفيذ الخدمة',
    [JOB_STATES.COMPLETED]: 'اكتملت الخدمة',
    [JOB_STATES.RATED]: 'تم تقييم الخدمة',
    [JOB_STATES.CANCELLED]: 'تم إلغاء الطلب',
    [JOB_STATES.NO_TECHNICIAN]: 'لم يتم العثور على فني متاح'
};

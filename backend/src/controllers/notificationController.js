import { supabaseAdmin } from '../config/supabase.js';
import { createAppError } from '../utils/appError.js';
import { ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';
import { trackNotificationLifecycleEvents } from '../services/notificationTelemetryService.js';

function buildNotificationsPayload({ notifications, count, page, limit }) {
    const total = count || 0;
    const currentPage = page || 1;
    const totalPages = Math.ceil(total / limit) || 0;

    return {
        success: true,
        data: {
            notifications,
            count: notifications.length,
            total,
            page: currentPage,
            totalPages,
        },
        notifications,
        count: notifications.length,
        total,
        page: currentPage,
        totalPages,
    };
}

/**
 * Get user's notifications with pagination
 */
export const getNotifications = async (req, res) => {
    try {
        const userId = req.user.id;
        const { page = 1, limit = 20, unread_only = false } = req.query;

        const pageNum = parseInt(page, 10) || 1;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50);
        const offset = (pageNum - 1) * limitNum;

        let query = supabaseAdmin
            .from('notifications')
            .select('*', { count: 'exact' })
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .range(offset, offset + limitNum - 1);

        if (unread_only === 'true') {
            query = query.eq('is_read', false);
        }

        const { data: notifications, error, count } = await query;

        if (error) throw error;

        return res.json(
            buildNotificationsPayload({
                notifications: notifications || [],
                count,
                page: pageNum,
                limit: limitNum,
            })
        );

    } catch (error) {
        console.error('Get Notifications Error:', error);
        return res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Get unread notifications count
 */
export const getUnreadCount = async (req, res) => {
    try {
        const userId = req.user.id;

        const { count, error } = await supabaseAdmin
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', userId)
            .eq('is_read', false);

        if (error) throw error;

        const unreadCount = count || 0;
        return res.json({
            success: true,
            data: {
                unread_count: unreadCount,
            },
            unread_count: unreadCount,
        });

    } catch (error) {
        console.error('Get Unread Count Error:', error);
        return res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Mark notification as read
 */
export const markAsRead = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params;

        const { error } = await supabaseAdmin
            .from('notifications')
            .update({ is_read: true })
            .eq('id', id)
            .eq('user_id', userId);

        if (error) throw error;

        return res.json({ success: true, message: 'تم تحديث الإشعار' });

    } catch (error) {
        console.error('Mark As Read Error:', error);
        return res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Mark all notifications as read
 */
export const markAllAsRead = async (req, res) => {
    try {
        const userId = req.user.id;

        const { error } = await supabaseAdmin
            .from('notifications')
            .update({ is_read: true })
            .eq('user_id', userId)
            .eq('is_read', false);

        if (error) throw error;

        return res.json({ success: true, message: 'تم تحديث جميع الإشعارات' });

    } catch (error) {
        console.error('Mark All As Read Error:', error);
        return res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Delete a notification
 */
export const deleteNotification = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params;

        const { error } = await supabaseAdmin
            .from('notifications')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);

        if (error) throw error;

        return res.json({ success: true, message: 'تم حذف الإشعار' });

    } catch (error) {
        console.error('Delete Notification Error:', error);
        return res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Update user's FCM token
 */
export const updateFCMToken = async (req, res) => {
    const userId = req.user.id;
    const rawToken = req.body?.fcmToken;
    const fcmToken = typeof rawToken === 'string' ? rawToken.trim() : '';

    if (fcmToken.length < 100) {
        throw createAppError('FCM token is invalid', {
            statusCode: HTTP_STATUS.BAD_REQUEST,
            code: ERROR_CODES.VALIDATION_FAILED,
            details: { field: 'fcmToken' },
        });
    }

    const { error } = await supabaseAdmin
        .from('users')
        .update({ fcm_token: fcmToken })
        .eq('id', userId);

    if (error) {
        throw createAppError(error.message || 'Failed to update FCM token', {
            statusCode: HTTP_STATUS.INTERNAL_SERVER_ERROR,
            code: ERROR_CODES.DATABASE_ERROR,
        });
    }

    return res.json({
        success: true,
        data: {
            fcm_token: fcmToken,
        },
        message: 'Token updated successfully',
    });
};

export const trackLifecycle = async (req, res) => {
    const stage = typeof req.body?.stage === 'string' ? req.body.stage.trim() : '';
    const requestId = typeof req.body?.requestId === 'string' ? req.body.requestId.trim() : '';
    const eventType = typeof req.body?.eventType === 'string' ? req.body.eventType.trim() : '';

    if (!stage || !requestId || !eventType) {
        throw createAppError('Lifecycle payload is invalid', {
            statusCode: HTTP_STATUS.BAD_REQUEST,
            code: ERROR_CODES.VALIDATION_FAILED,
        });
    }

    const aggregate = await trackNotificationLifecycleEvents([req.body], {
        fallbackUserId: req.user?.id || null,
        fallbackSource: 'mobile_client',
        persist: true,
    });

    return res.json({
        success: true,
        requestId: req.requestId,
        ...aggregate,
    });
};

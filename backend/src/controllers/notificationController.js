import { supabase } from '../config/supabase.js';

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

        let query = supabase
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

        res.json({
            success: true,
            count: notifications.length,
            total: count,
            page: pageNum,
            totalPages: Math.ceil((count || 0) / limitNum),
            notifications
        });

    } catch (error) {
        console.error('Get Notifications Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Get unread notifications count
 */
export const getUnreadCount = async (req, res) => {
    try {
        const userId = req.user.id;

        const { count, error } = await supabase
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', userId)
            .eq('is_read', false);

        if (error) throw error;

        res.json({ success: true, unread_count: count || 0 });

    } catch (error) {
        console.error('Get Unread Count Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Mark notification as read
 */
export const markAsRead = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params;

        const { error } = await supabase
            .from('notifications')
            .update({ is_read: true })
            .eq('id', id)
            .eq('user_id', userId);

        if (error) throw error;

        res.json({ success: true, message: 'تم تحديث الإشعار' });

    } catch (error) {
        console.error('Mark As Read Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Mark all notifications as read
 */
export const markAllAsRead = async (req, res) => {
    try {
        const userId = req.user.id;

        const { error } = await supabase
            .from('notifications')
            .update({ is_read: true })
            .eq('user_id', userId)
            .eq('is_read', false);

        if (error) throw error;

        res.json({ success: true, message: 'تم تحديث جميع الإشعارات' });

    } catch (error) {
        console.error('Mark All As Read Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

/**
 * Delete a notification
 */
export const deleteNotification = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params;

        const { error } = await supabase
            .from('notifications')
            .delete()
            .eq('id', id)
            .eq('user_id', userId);

        if (error) throw error;

        res.json({ success: true, message: 'تم حذف الإشعار' });

    } catch (error) {
        console.error('Delete Notification Error:', error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
};

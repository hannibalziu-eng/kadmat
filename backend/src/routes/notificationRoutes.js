import express from 'express';
import {
    getNotifications,
    getUnreadCount,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    updateFCMToken
} from '../controllers/notificationController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// All routes are protected
router.use(protect);

// Get notifications with pagination
router.get('/', getNotifications);

// Get unread count
router.get('/unread-count', getUnreadCount);

// Mark all as read
router.post('/mark-all-read', markAllAsRead);

// Mark single as read
router.post('/:id/read', markAsRead);

// Delete notification
router.delete('/:id', deleteNotification);

// Update FCM Token
router.post('/fcm-token', updateFCMToken);

export default router;

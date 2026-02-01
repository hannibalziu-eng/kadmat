import express from 'express';
import {
    getMessages,
    sendMessage,
    markAsRead,
    getUnreadCount,
    getConversations
} from '../controllers/messageController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// All routes require authentication
router.use(protect);

// ============================================
// Messages Routes
// ============================================

/**
 * GET /api/messages/conversations
 * Get all conversations (chats) for current user
 */
router.get('/conversations', getConversations);

/**
 * GET /api/messages/unread-count
 * Get total unread message count
 */
router.get('/unread-count', getUnreadCount);

/**
 * GET /api/messages/:jobId
 * Get all messages for a specific job
 */
router.get('/:jobId', getMessages);

/**
 * POST /api/messages/:jobId
 * Send a new message in a job
 * Body: { content: string }
 */
router.post('/:jobId', sendMessage);

/**
 * PATCH /api/messages/:jobId/read
 * Mark all messages in a job as read
 */
router.patch('/:jobId/read', markAsRead);

export default router;

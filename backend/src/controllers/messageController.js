import Joi from 'joi';
import { supabase } from '../config/supabase.js';
import { responseFormatter, ERROR_CODES, HTTP_STATUS } from '../utils/responseFormatter.js';
import { sendPushNotification } from '../services/fcmService.js';

// ============================================
// Validation Schemas
// ============================================
const sendMessageSchema = Joi.object({
    content: Joi.string().max(1000).required().messages({
        'string.empty': 'محتوى الرسالة مطلوب',
        'string.max': 'الرسالة طويلة جداً (الحد الأقصى 1000 حرف)'
    })
});

// ============================================
// 1. Get Messages for a Job
// ============================================
export const getMessages = async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user.id;

        // First, verify user is participant in this job
        const { data: job, error: jobError } = await supabase
            .from('jobs')
            .select('customer_id, technician_id')
            .eq('id', jobId)
            .maybeSingle();

        if (jobError || !job) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.JOB_NOT_FOUND,
                'الطلب غير موجود',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(statusCode).json(response);
        }

        // Check if user is customer or technician
        if (job.customer_id !== userId && job.technician_id !== userId) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.UNAUTHORIZED,
                'غير مصرح لك بعرض هذه الرسائل',
                HTTP_STATUS.FORBIDDEN
            );
            return res.status(statusCode).json(response);
        }

        // Get messages with sender info
        const { data: messages, error } = await supabase
            .from('messages')
            .select(`
                id,
                job_id,
                sender_id,
                receiver_id,
                content,
                is_read,
                created_at,
                read_at,
                sender:users!sender_id(id, full_name, profile_image_url)
            `)
            .eq('job_id', jobId)
            .order('created_at', { ascending: true });

        if (error) throw error;

        return res.json(responseFormatter.success(messages));
    } catch (error) {
        console.error('Get Messages Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'حدث خطأ أثناء جلب الرسائل'
        );
        return res.status(statusCode).json(response);
    }
};

// ============================================
// 2. Send Message
// ============================================
export const sendMessage = async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user.id;

        // Validate input
        const { error: validationError, value } = sendMessageSchema.validate(req.body);
        if (validationError) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.VALIDATION_FAILED,
                validationError.details[0].message
            );
            return res.status(statusCode).json(response);
        }

        // Get job to find receiver
        const { data: job, error: jobError } = await supabase
            .from('jobs')
            .select('customer_id, technician_id, status')
            .eq('id', jobId)
            .maybeSingle();

        if (jobError || !job) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.JOB_NOT_FOUND,
                'الطلب غير موجود',
                HTTP_STATUS.NOT_FOUND
            );
            return res.status(statusCode).json(response);
        }

        // Check if user is participant
        const isCustomer = job.customer_id === userId;
        const isTechnician = job.technician_id === userId;

        if (!isCustomer && !isTechnician) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.UNAUTHORIZED,
                'غير مصرح لك بإرسال رسائل في هذا الطلب',
                HTTP_STATUS.FORBIDDEN
            );
            return res.status(statusCode).json(response);
        }

        // Check job status - must have technician assigned
        if (!job.technician_id) {
            const { response, statusCode } = responseFormatter.error(
                ERROR_CODES.INVALID_STATUS_TRANSITION,
                'لا يمكن الدردشة قبل قبول فني للطلب',
                HTTP_STATUS.BAD_REQUEST
            );
            return res.status(statusCode).json(response);
        }

        // Determine receiver (the other party)
        const receiverId = isCustomer ? job.technician_id : job.customer_id;

        // Insert message
        const { data: message, error } = await supabase
            .from('messages')
            .insert({
                job_id: jobId,
                sender_id: userId,
                receiver_id: receiverId,
                content: value.content
            })
            .select(`
                id,
                job_id,
                sender_id,
                receiver_id,
                content,
                is_read,
                created_at,
                sender:users!sender_id(id, full_name, profile_image_url)
            `)
            .single();

        if (error) throw error;

        return res.status(HTTP_STATUS.CREATED).json(
            responseFormatter.success(message, 'تم إرسال الرسالة')
        );

        // Send Push Notification asynchronously (don't await)
        sendPushNotification(receiverId, {
            title: 'رسالة جديدة 💬',
            body: `${message.sender.full_name}: ${message.content.substring(0, 50)}${message.content.length > 50 ? '...' : ''}`,
            data: {
                type: 'chat_message',
                job_id: jobId,
                sender_id: userId
            }
        });
    } catch (error) {
        console.error('Send Message Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'حدث خطأ أثناء إرسال الرسالة'
        );
        return res.status(statusCode).json(response);
    }
};

// ============================================
// 3. Mark Messages as Read
// ============================================
export const markAsRead = async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user.id;

        // Use the database function for atomic update
        const { data, error } = await supabase
            .rpc('mark_messages_as_read', {
                p_job_id: jobId,
                p_user_id: userId
            });

        if (error) throw error;

        return res.json(
            responseFormatter.success({ updated_count: data }, 'تم تحديد الرسائل كمقروءة')
        );
    } catch (error) {
        console.error('Mark as Read Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'حدث خطأ أثناء تحديث حالة القراءة'
        );
        return res.status(statusCode).json(response);
    }
};

// ============================================
// 4. Get Unread Count
// ============================================
export const getUnreadCount = async (req, res) => {
    try {
        const userId = req.user.id;

        // Get total unread count
        const { data: totalCount, error: totalError } = await supabase
            .rpc('get_unread_count', { p_user_id: userId });

        if (totalError) throw totalError;

        // Get unread count by job
        const { data: byJob, error: byJobError } = await supabase
            .rpc('get_unread_count_by_job', { p_user_id: userId });

        if (byJobError) throw byJobError;

        return res.json(responseFormatter.success({
            total: totalCount || 0,
            by_job: byJob || []
        }));
    } catch (error) {
        console.error('Get Unread Count Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'حدث خطأ أثناء جلب عدد الرسائل'
        );
        return res.status(statusCode).json(response);
    }
};

// ============================================
// 5. Get Conversation List (All chats for user)
// ============================================
export const getConversations = async (req, res) => {
    try {
        const userId = req.user.id;

        // Get all jobs where user is participant and has messages
        const { data: jobs, error } = await supabase
            .from('jobs')
            .select(`
                id,
                status,
                customer:users!customer_id(id, full_name, profile_image_url),
                technician:users!technician_id(id, full_name, profile_image_url),
                service:services(id, name)
            `)
            .or(`customer_id.eq.${userId},technician_id.eq.${userId}`)
            .not('technician_id', 'is', null)
            .order('created_at', { ascending: false });

        if (error) throw error;

        // Get unread counts for each job
        const { data: unreadCounts } = await supabase
            .rpc('get_unread_count_by_job', { p_user_id: userId });

        // Merge unread counts with jobs
        const conversations = jobs.map(job => {
            const unreadInfo = unreadCounts?.find(u => u.job_id === job.id);
            const otherUser = job.customer?.id === userId ? job.technician : job.customer;

            return {
                job_id: job.id,
                status: job.status,
                service_name: job.service?.name,
                other_user: otherUser,
                unread_count: unreadInfo?.unread_count || 0
            };
        });

        return res.json(responseFormatter.success(conversations));
    } catch (error) {
        console.error('Get Conversations Error:', error);
        const { response, statusCode } = responseFormatter.error(
            ERROR_CODES.DATABASE_ERROR,
            'حدث خطأ أثناء جلب المحادثات'
        );
        return res.status(statusCode).json(response);
    }
};

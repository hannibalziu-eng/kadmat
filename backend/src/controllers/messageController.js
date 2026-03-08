import Joi from 'joi';
import { supabaseAdmin } from '../config/supabase.js';
import {
  responseFormatter,
  ERROR_CODES,
  HTTP_STATUS,
} from '../utils/responseFormatter.js';
import { sendPushNotification } from '../services/fcmService.js';
import {
  canUseJobCommunication,
  communicationDeniedDetails,
} from '../utils/jobCommunication.js';

const jobConversationSelect = `
  id,
  status,
  accepted_bid_id,
  customer_id,
  technician_id,
  customer:users!customer_id(id, full_name, profile_image_url, phone),
  technician:users!technician_id(id, full_name, profile_image_url, phone),
  service:services!service_id(id, name, name_ar)
`;

const messageSelect = `
  id,
  job_id,
  sender_id,
  receiver_id,
  content,
  is_read,
  created_at,
  read_at,
  sender:users!sender_id(id, full_name, profile_image_url)
`;

const sendMessageSchema = Joi.object({
  content: Joi.string().max(1000).required().messages({
    'string.empty': 'محتوى الرسالة مطلوب',
    'string.max': 'الرسالة طويلة جداً (الحد الأقصى 1000 حرف)',
  }),
});

function sendError(res, code, message, options) {
  const { response, statusCode } = responseFormatter.error(code, message, options);
  return res.status(statusCode).json(response);
}

async function loadJobForParticipant(jobId, userId) {
  const { data: job, error } = await supabaseAdmin
    .from('jobs')
    .select(jobConversationSelect)
    .eq('id', jobId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!job) {
    return { error: 'not_found' };
  }

  const isParticipant = job.customer_id === userId || job.technician_id === userId;
  if (!isParticipant) {
    return { error: 'forbidden', job };
  }

  return { job };
}

function ensureCommunicationEligibility(job) {
  if (canUseJobCommunication(job)) {
    return null;
  }

  return {
    code: ERROR_CODES.COMMUNICATION_NOT_AVAILABLE,
    message: 'التواصل متاح فقط بعد قبول العرض',
    options: {
      statusCode: HTTP_STATUS.FORBIDDEN,
      details: communicationDeniedDetails(job),
    },
  };
}

async function getUnreadRowsForEligibleJobs(userId, jobIds) {
  if (jobIds.length === 0) {
    return [];
  }

  const { data, error } = await supabaseAdmin
    .from('messages')
    .select('job_id')
    .eq('receiver_id', userId)
    .eq('is_read', false)
    .in('job_id', jobIds);

  if (error) {
    throw error;
  }

  return data ?? [];
}

async function getLatestMessages(jobIds) {
  if (jobIds.length === 0) {
    return new Map();
  }

  const { data, error } = await supabaseAdmin
    .from('messages')
    .select('job_id, content, created_at')
    .in('job_id', jobIds)
    .order('created_at', { ascending: false });

  if (error) {
    throw error;
  }

  const latestByJob = new Map();
  for (const row of data ?? []) {
    if (!latestByJob.has(row.job_id)) {
      latestByJob.set(row.job_id, {
        content: row.content,
        created_at: row.created_at,
      });
    }
  }

  return latestByJob;
}

export const getMessages = async (req, res) => {
  try {
    const { jobId } = req.params;
    const userId = req.user.id;

    const { job, error } = await loadJobForParticipant(jobId, userId);
    if (error === 'not_found') {
      return sendError(
        res,
        ERROR_CODES.JOB_NOT_FOUND,
        'الطلب غير موجود',
        HTTP_STATUS.NOT_FOUND,
      );
    }
    if (error === 'forbidden') {
      return sendError(
        res,
        ERROR_CODES.UNAUTHORIZED,
        'غير مصرح لك بعرض هذه الرسائل',
        HTTP_STATUS.FORBIDDEN,
      );
    }

    const communicationError = ensureCommunicationEligibility(job);
    if (communicationError) {
      return sendError(
        res,
        communicationError.code,
        communicationError.message,
        communicationError.options,
      );
    }

    const { data: messages, error: messagesError } = await supabaseAdmin
      .from('messages')
      .select(messageSelect)
      .eq('job_id', jobId)
      .order('created_at', { ascending: true });

    if (messagesError) {
      throw messagesError;
    }

    return res.json(responseFormatter.success(messages ?? []));
  } catch (error) {
    console.error('Get Messages Error:', error);
    return sendError(
      res,
      ERROR_CODES.DATABASE_ERROR,
      'حدث خطأ أثناء جلب الرسائل',
    );
  }
};

export const sendMessage = async (req, res) => {
  try {
    const { jobId } = req.params;
    const userId = req.user.id;
    const { error: validationError, value } = sendMessageSchema.validate(req.body);

    if (validationError) {
      return sendError(
        res,
        ERROR_CODES.VALIDATION_FAILED,
        validationError.details[0].message,
      );
    }

    const { job, error } = await loadJobForParticipant(jobId, userId);
    if (error === 'not_found') {
      return sendError(
        res,
        ERROR_CODES.JOB_NOT_FOUND,
        'الطلب غير موجود',
        HTTP_STATUS.NOT_FOUND,
      );
    }
    if (error === 'forbidden') {
      return sendError(
        res,
        ERROR_CODES.UNAUTHORIZED,
        'غير مصرح لك بإرسال رسائل في هذا الطلب',
        HTTP_STATUS.FORBIDDEN,
      );
    }

    const communicationError = ensureCommunicationEligibility(job);
    if (communicationError) {
      return sendError(
        res,
        communicationError.code,
        communicationError.message,
        communicationError.options,
      );
    }

    const isCustomer = job.customer_id === userId;
    const receiverId = isCustomer ? job.technician_id : job.customer_id;
    if (!receiverId) {
      return sendError(
        res,
        ERROR_CODES.COMMUNICATION_NOT_AVAILABLE,
        'التواصل غير متاح لهذا الطلب حالياً',
        {
          statusCode: HTTP_STATUS.FORBIDDEN,
          details: communicationDeniedDetails(job),
        },
      );
    }

    const { data: message, error: insertError } = await supabaseAdmin
      .from('messages')
      .insert({
        job_id: jobId,
        sender_id: userId,
        receiver_id: receiverId,
        content: value.content.trim(),
      })
      .select(messageSelect)
      .single();

    if (insertError) {
      throw insertError;
    }

    void sendPushNotification(receiverId, {
      title: 'رسالة جديدة',
      body: `${message.sender?.full_name ?? 'مستخدم'}: ${message.content.substring(0, 50)}${message.content.length > 50 ? '...' : ''}`,
      data: {
        type: 'chat_message',
        job_id: jobId,
        sender_id: userId,
      },
    }).catch((pushError) => {
      console.error('Send Message Push Error:', pushError);
    });

    return res
      .status(HTTP_STATUS.CREATED)
      .json(responseFormatter.success(message, 'تم إرسال الرسالة'));
  } catch (error) {
    console.error('Send Message Error:', error);
    return sendError(
      res,
      ERROR_CODES.DATABASE_ERROR,
      'حدث خطأ أثناء إرسال الرسالة',
    );
  }
};

export const markAsRead = async (req, res) => {
  try {
    const { jobId } = req.params;
    const userId = req.user.id;

    const { job, error } = await loadJobForParticipant(jobId, userId);
    if (error === 'not_found') {
      return sendError(
        res,
        ERROR_CODES.JOB_NOT_FOUND,
        'الطلب غير موجود',
        HTTP_STATUS.NOT_FOUND,
      );
    }
    if (error === 'forbidden') {
      return sendError(
        res,
        ERROR_CODES.UNAUTHORIZED,
        'غير مصرح لك بتحديث هذه الرسائل',
        HTTP_STATUS.FORBIDDEN,
      );
    }

    const communicationError = ensureCommunicationEligibility(job);
    if (communicationError) {
      return sendError(
        res,
        communicationError.code,
        communicationError.message,
        communicationError.options,
      );
    }

    const now = new Date().toISOString();
    const { data: updatedRows, error: updateError } = await supabaseAdmin
      .from('messages')
      .update({
        is_read: true,
        read_at: now,
      })
      .eq('job_id', jobId)
      .eq('receiver_id', userId)
      .eq('is_read', false)
      .select('id');

    if (updateError) {
      throw updateError;
    }

    return res.json(
      responseFormatter.success(
        { updated_count: updatedRows?.length ?? 0 },
        'تم تحديد الرسائل كمقروءة',
      ),
    );
  } catch (error) {
    console.error('Mark as Read Error:', error);
    return sendError(
      res,
      ERROR_CODES.DATABASE_ERROR,
      'حدث خطأ أثناء تحديث حالة القراءة',
    );
  }
};

export const getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: jobs, error: jobsError } = await supabaseAdmin
      .from('jobs')
      .select('id, status, accepted_bid_id')
      .or(`customer_id.eq.${userId},technician_id.eq.${userId}`);

    if (jobsError) {
      throw jobsError;
    }

    const eligibleJobIds = (jobs ?? [])
      .filter((job) => canUseJobCommunication(job))
      .map((job) => job.id);

    const unreadRows = await getUnreadRowsForEligibleJobs(userId, eligibleJobIds);
    const byJob = new Map();
    for (const row of unreadRows) {
      byJob.set(row.job_id, (byJob.get(row.job_id) ?? 0) + 1);
    }

    return res.json(
      responseFormatter.success({
        total: unreadRows.length,
        by_job: Array.from(
          byJob.entries(),
          ([jobId, unreadCount]) => ({
            job_id: jobId,
            unread_count: unreadCount,
          }),
        ),
      }),
    );
  } catch (error) {
    console.error('Get Unread Count Error:', error);
    return sendError(
      res,
      ERROR_CODES.DATABASE_ERROR,
      'حدث خطأ أثناء جلب عدد الرسائل',
    );
  }
};

export const getConversations = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: jobs, error } = await supabaseAdmin
      .from('jobs')
      .select(jobConversationSelect)
      .or(`customer_id.eq.${userId},technician_id.eq.${userId}`)
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    const eligibleJobs = (jobs ?? []).filter((job) => {
      const otherUser =
        job.customer?.id === userId ? job.technician : job.customer;
      return canUseJobCommunication(job) && otherUser != null;
    });

    const eligibleJobIds = eligibleJobs.map((job) => job.id);
    const [latestMessages, unreadRows] = await Promise.all([
      getLatestMessages(eligibleJobIds),
      getUnreadRowsForEligibleJobs(userId, eligibleJobIds),
    ]);

    const unreadByJob = new Map();
    for (const row of unreadRows) {
      unreadByJob.set(row.job_id, (unreadByJob.get(row.job_id) ?? 0) + 1);
    }

    const conversations = eligibleJobs.map((job) => {
      const otherUser =
        job.customer?.id === userId ? job.technician : job.customer;
      const latestMessage = latestMessages.get(job.id);

      return {
        job_id: job.id,
        status: job.status,
        service_name: job.service?.name_ar ?? job.service?.name ?? null,
        other_user: otherUser,
        unread_count: unreadByJob.get(job.id) ?? 0,
        last_message: latestMessage?.content ?? null,
        last_message_at: latestMessage?.created_at ?? null,
      };
    });

    return res.json(responseFormatter.success(conversations));
  } catch (error) {
    console.error('Get Conversations Error:', error);
    return sendError(
      res,
      ERROR_CODES.DATABASE_ERROR,
      'حدث خطأ أثناء جلب المحادثات',
    );
  }
};

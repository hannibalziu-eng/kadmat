/**
 * FCM Push Notification Service
 * Sends push notifications via Firebase Cloud Messaging
 */

import admin from 'firebase-admin';
import { supabaseAdmin } from '../config/supabase.js';

// Initialize Firebase Admin (only once)
let firebaseApp = null;

export function initializeFirebase() {
    if (firebaseApp) return;

    // Check for service account credentials
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;

    if (!serviceAccount) {
        console.warn('⚠️  FIREBASE_SERVICE_ACCOUNT not set - Push notifications disabled');
        return;
    }

    try {
        firebaseApp = admin.initializeApp({
            credential: admin.credential.cert(JSON.parse(serviceAccount))
        });
        console.log('✅ Firebase Admin initialized');
    } catch (error) {
        console.error('❌ Failed to initialize Firebase:', error.message);
    }
}

/**
 * Send push notification to a single user
 * @param {string} userId - User ID to send notification to
 * @param {object} notification - { title, body, data }
 */
export async function sendPushNotification(userId, { title, body, data = {} }) {
    if (!firebaseApp) {
        console.log('📵 Firebase not initialized - skipping push');
        return { success: false, reason: 'firebase_not_initialized' };
    }

    try {
        // Get user's FCM token from database
        const { data: user, error } = await supabaseAdmin
            .from('users')
            .select('fcm_token')
            .eq('id', userId)
            .single();

        if (error || !user?.fcm_token) {
            console.log(`📵 No FCM token for user ${userId}`);
            return { success: false, reason: 'no_fcm_token' };
        }

        // Send the notification
        const message = {
            token: user.fcm_token,
            notification: {
                title,
                body
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'kadmat_notifications'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        };

        const response = await admin.messaging().send(message);
        console.log(`✅ Push sent to ${userId}: ${response}`);
        return { success: true, messageId: response };

    } catch (error) {
        console.error(`❌ Push failed for ${userId}:`, error.message);

        // Handle invalid token
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
            // Clear invalid token
            await supabaseAdmin
                .from('users')
                .update({ fcm_token: null })
                .eq('id', userId);
        }

        return { success: false, error: error.message };
    }
}

/**
 * Send push notifications to multiple users
 * @param {string[]} userIds - Array of user IDs
 * @param {object} notification - { title, body, data }
 */
export async function sendBulkPushNotifications(userIds, { title, body, data = {} }) {
    if (!firebaseApp) {
        console.log('📵 Firebase not initialized - skipping bulk push');
        return { success: false, sent: 0 };
    }

    try {
        // Get FCM tokens for all users
        const { data: users, error } = await supabaseAdmin
            .from('users')
            .select('id, fcm_token')
            .in('id', userIds)
            .not('fcm_token', 'is', null);

        if (error || !users?.length) {
            console.log(`📵 No FCM tokens for users: ${userIds}`);
            return { success: false, sent: 0 };
        }

        // Build messages
        const messages = users.map(user => ({
            token: user.fcm_token,
            notification: { title, body },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'kadmat_notifications'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default'
                    }
                }
            }
        }));

        // Send all in batch (max 500 per request)
        const batchSize = 500;
        let totalSent = 0;
        let totalFailed = 0;

        for (let i = 0; i < messages.length; i += batchSize) {
            const batch = messages.slice(i, i + batchSize);
            const response = await admin.messaging().sendEach(batch);

            totalSent += response.successCount;
            totalFailed += response.failureCount;

            // Log failures for debugging
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    console.log(`📵 Failed: ${users[i + idx].id} - ${resp.error?.message}`);
                }
            });
        }

        console.log(`✅ Bulk push: ${totalSent} sent, ${totalFailed} failed`);
        return { success: true, sent: totalSent, failed: totalFailed };

    } catch (error) {
        console.error('❌ Bulk push failed:', error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Send job notification to nearby technicians (with push)
 */
export async function notifyTechniciansWithPush(jobId, technicians) {
    if (!technicians?.length) return;

    const userIds = technicians.map(t => t.id);

    // Send push notifications
    await sendBulkPushNotifications(userIds, {
        title: 'وظيفة جديدة متاحة 🔔',
        body: 'طلب خدمة جديد بالقرب منك',
        data: {
            type: 'new_job_offer',
            job_id: jobId
        }
    });
}

/**
 * Send notification when technician accepts job (to customer)
 */
export async function notifyJobAccepted(jobId, customerId, technicianName) {
    await sendPushNotification(customerId, {
        title: 'تم قبول طلبك! ✅',
        body: `الفني ${technicianName} سيقوم بخدمتك`,
        data: {
            type: 'job_accepted',
            job_id: jobId
        }
    });
}

/**
 * Send notification for price request (to customer)
 */
export async function notifyPriceRequest(jobId, customerId, price) {
    await sendPushNotification(customerId, {
        title: 'عرض سعر جديد 💰',
        body: `الفني أرسل عرض سعر: ${price} ريال`,
        data: {
            type: 'price_request',
            job_id: jobId,
            price: String(price)
        }
    });
}

/**
 * Send notification for job completion (to customer)
 */
export async function notifyJobCompleted(jobId, customerId) {
    await sendPushNotification(customerId, {
        title: 'تأكيد إكمال الخدمة 🎉',
        body: 'الفني أنهى العمل. يرجى تأكيد استلام الخدمة',
        data: {
            type: 'completion_request',
            job_id: jobId
        }
    });
}

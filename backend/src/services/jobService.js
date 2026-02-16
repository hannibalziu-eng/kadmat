import { supabaseAdmin } from '../config/supabase.js';
import {
    validateTransition,
    JOB_STATES
} from '../utils/jobStateMachine.js';
import { notifyPriceRequest, notifyJobCompleted, sendPushNotification } from './fcmService.js';

const CUSTOMER_LOCKED_STATUSES = [
    JOB_STATES.ON_THE_WAY,
    JOB_STATES.ARRIVED,
    JOB_STATES.IN_PROGRESS,
    JOB_STATES.PENDING_CONFIRM
];

const TECHNICIAN_LOCKED_STATUSES = [
    JOB_STATES.ON_THE_WAY,
    JOB_STATES.ARRIVED,
    JOB_STATES.IN_PROGRESS,
    JOB_STATES.PENDING_CONFIRM
];

class JobService {
    /**
     * Create a new job (Service Request)
     */
    async create(userId, jobData) {
        // Log input for debugging
        console.log(`📝 [JobService.create] userId=${userId}, lat=${jobData.lat}, lng=${jobData.lng}, service_id=${jobData.service_id}`);

        await this._ensureCustomerCanCreateJob(userId);

        // Cancel older open search jobs for the same customer to prevent
        // duplicate dispatch items and stale legacy requests.
        await this._cancelOpenSearchJobsForCustomer(userId);

        // 1. Prepare Data
        const jobToInsert = {
            customer_id: userId,
            service_id: jobData.service_id,
            lat: jobData.lat,
            lng: jobData.lng,
            location: `SRID=4326;POINT(${jobData.lng} ${jobData.lat})`, // PostGIS
            address_text: jobData.address_text,
            description: jobData.description,
            initial_price: jobData.initial_price,
            status: JOB_STATES.PENDING,
            search_radius: 5000, // 5km initial radius
            metadata: jobData.metadata || {}
        };

        // 2. Insert into DB
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .insert(jobToInsert)
            .select()
            .single();

        if (error) {
            console.error('❌ [JobService.create] DB Error:', {
                code: error.code,
                message: error.message,
                details: error.details,
                hint: error.hint,
                input: { userId, lat: jobData.lat, lng: jobData.lng, service_id: jobData.service_id }
            });
            // Include DB error details in the thrown error
            const dbError = new Error(`Failed to create job: ${error.message || 'Database error'}`);
            dbError.code = error.code || 'DB_INSERT_ERROR';
            dbError.details = error.details;
            dbError.hint = error.hint;
            throw dbError;
        }

        console.log(`✅ [JobService.create] Job created successfully: ${job.id}`);

        // 3. Insert Images (if any)
        if (jobData.images && jobData.images.length > 0) {
            const imageRecords = jobData.images.map(url => ({
                job_id: job.id,
                image_url: url,
                media_type: 'image'
            }));

            const { error: imagesError } = await supabaseAdmin
                .from('job_images')
                .insert(imageRecords);

            if (imagesError) {
                console.error('Error inserting job images:', imagesError);
            }
        }

        return job;
    }

    /**
     * Transition: pending/searching -> accepted
     */
    async accept(jobId, technicianId) {
        const job = await this._getJob(jobId);

        await this._ensureTechnicianCanTakeNewWork(technicianId, { currentJobId: jobId });

        if (job.technician_id && job.technician_id !== technicianId) {
            const error = new Error('Job already accepted by another technician');
            error.code = 'JOB_ALREADY_ACCEPTED';
            throw error;
        }

        // Idempotent: if same technician already accepted, return current job state.
        if (job.technician_id === technicianId && job.status === JOB_STATES.ACCEPTED) {
            return job;
        }

        const allowedStatuses = [JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN];
        if (!allowedStatuses.includes(job.status)) {
            const error = new Error(`Cannot accept job in status '${job.status}'`);
            error.code = 'INVALID_STATUS_TRANSITION';
            error.currentStatus = job.status;
            throw error;
        }

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.ACCEPTED,
                technician_id: technicianId,
                accepted_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .in('status', allowedStatuses)
            .is('technician_id', null)
            .select()
            .maybeSingle();

        if (error) {
            const acceptError = new Error(`Failed to accept job: ${error.message}`);
            acceptError.code = 'ACCEPT_FAILED';
            throw acceptError;
        }

        if (!updatedJob) {
            const latestJob = await this._getJob(jobId);
            if (latestJob.technician_id && latestJob.technician_id !== technicianId) {
                const conflictError = new Error('Job already accepted by another technician');
                conflictError.code = 'JOB_ALREADY_ACCEPTED';
                throw conflictError;
            }

            const genericError = new Error('Failed to accept job');
            genericError.code = 'ACCEPT_FAILED';
            throw genericError;
        }

        return updatedJob;
    }

    /**
     * Submit an Offer (Technician)
     */
    async submitOffer(jobId, technicianId, price) {
        const job = await this._getJob(jobId);

        const numericPrice = Number(price);
        if (!Number.isFinite(numericPrice) || numericPrice <= 0) {
            throw new Error('Invalid price');
        }

        await this._ensureTechnicianCanTakeNewWork(technicianId, { currentJobId: jobId });

        const offerableStatuses = [JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN];
        if (!offerableStatuses.includes(job.status) || job.technician_id) {
            throw new Error('Job is no longer available');
        }

        // Avoid duplicate active offers by the same technician.
        const { data: existingOffer, error: existingOfferError } = await supabaseAdmin
            .from('job_offers')
            .select('id, status')
            .eq('job_id', jobId)
            .eq('technician_id', technicianId)
            .eq('is_active', true)
            .single();

        if (existingOfferError && existingOfferError.code !== 'PGRST116') {
            throw new Error('Failed to submit offer: ' + existingOfferError.message);
        }

        let offer = null;

        if (existingOffer) {
            if (existingOffer.status !== 'pending') {
                throw new Error('Offer is no longer available');
            }

            const { data: updatedOffer, error: updateError } = await supabaseAdmin
                .from('job_offers')
                .update({
                    price: numericPrice,
                    updated_at: new Date().toISOString()
                })
                .eq('id', existingOffer.id)
                .select()
                .single();

            if (updateError) throw new Error('Failed to submit offer: ' + updateError.message);
            offer = updatedOffer;
        } else {
            const { data: insertedOffer, error: insertError } = await supabaseAdmin
                .from('job_offers')
                .insert({
                    job_id: jobId,
                    technician_id: technicianId,
                    price: numericPrice,
                    status: 'pending',
                    is_active: true
                })
                .select()
                .single();

            if (insertError) throw new Error('Failed to submit offer: ' + insertError.message);
            offer = insertedOffer;
        }

        if (!offer) throw new Error('Failed to submit offer');

        // Notify Customer
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'new_offer',
            title: 'عرض جديد!',
            body: `تلقيت عرضاً جديداً بقيمة ${numericPrice} ريال`,
            data: { job_id: jobId, offer_id: offer.id },
            is_read: false
        });

        // Trigger push notification here...

        return offer;
    }

    /**
     * Accept an Offer (Customer)
     */
    async acceptOffer(jobId, customerId, offerId) {
        if (!offerId) {
            const err = new Error('Offer not found');
            err.code = 'NOT_FOUND';
            throw err;
        }

        const job = await this._getJob(jobId);
        if (job.customer_id !== customerId) {
            const err = new Error('Unauthorized');
            err.code = 'UNAUTHORIZED';
            throw err;
        }

        const preloadedOffer = await this._getOfferById(jobId, offerId);
        await this._ensureTechnicianCanTakeNewWork(preloadedOffer.technician_id, {
            currentJobId: jobId
        });

        // Preferred path: atomic DB contract.
        // If migration is not applied yet, fallback to legacy JS flow below.
        const atomic = await this._tryAcceptOfferAtomically(jobId, customerId, offerId);
        if (atomic.handled) {
            let resolvedAtomicJob = atomic.job;

            // Backward compatibility:
            // older RPC versions may still assign "in_progress" مباشرة.
            // Normalize first post-accept status to "on_the_way".
            if (resolvedAtomicJob?.status === JOB_STATES.IN_PROGRESS) {
                const { data: normalizedJob } = await supabaseAdmin
                    .from('jobs')
                    .update({
                        status: JOB_STATES.ON_THE_WAY,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', jobId)
                    .eq('accepted_bid_id', offerId)
                    .eq('status', JOB_STATES.IN_PROGRESS)
                    .select()
                    .maybeSingle();

                if (normalizedJob) {
                    resolvedAtomicJob = normalizedJob;
                }
            }

            await this._notifyOfferAccepted(
                atomic.technicianId,
                jobId,
                atomic.acceptedPrice
            );
            return resolvedAtomicJob;
        }

        // Idempotency guard: repeated accept request for the same selected offer
        // should return current job state instead of failing.
        if (
            job.accepted_bid_id === offerId &&
            job.technician_id &&
            [
                JOB_STATES.ACCEPTED,
                JOB_STATES.PRICE_PENDING,
                JOB_STATES.ON_THE_WAY,
                JOB_STATES.ARRIVED,
                JOB_STATES.IN_PROGRESS,
                JOB_STATES.PENDING_CONFIRM,
                JOB_STATES.COMPLETED,
                JOB_STATES.RATED
            ].includes(job.status)
        ) {
            return job;
        }

        // If a different offer was already selected, this offer cannot be accepted.
        if (job.accepted_bid_id && job.accepted_bid_id !== offerId) {
            const err = new Error('Offer is no longer available');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = job.status;
            throw err;
        }

        // Offer flow is only valid while job is still open for bidding.
        if (![JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN].includes(job.status)) {
            const err = new Error('Job is no longer available for accepting offers');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = job.status;
            throw err;
        }

        // 1. Get Offer
        const offer = preloadedOffer;
        if (offer.status === 'accepted' && job.accepted_bid_id === offerId) {
            return this._getJob(jobId);
        }
        if (offer.status && offer.status !== 'pending') {
            const err = new Error('Offer is no longer available');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = job.status;
            throw err;
        }

        // 2. Assign Job to Technician and lock the agreed offer price.
        // Offer acceptance is itself a price approval in offer-flow.
        const nowIso = new Date().toISOString();
        const fallbackAssignableStatuses = [
            JOB_STATES.ON_THE_WAY,
            JOB_STATES.IN_PROGRESS
        ];
        let statusAttemptIndex = 0;

        const requiredAssignPayload = {
            status: fallbackAssignableStatuses[statusAttemptIndex],
            technician_id: offer.technician_id,
            updated_at: nowIso
        };
        const optionalAssignPayload = {
            technician_price: offer.price,
            final_price: offer.price,
            accepted_at: nowIso,
            price_confirmed_at: nowIso,
            accepted_bid_id: offer.id
        };
        const assignmentPayload = {
            ...requiredAssignPayload,
            ...optionalAssignPayload
        };

        const runAssignUpdate = async (payload) => {
            return await supabaseAdmin
                .from('jobs')
                .update(payload)
                .eq('id', jobId)
                .in('status', [JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN])
                .is('technician_id', null)
                .select()
                .maybeSingle();
        };

        let { data: updatedJob, error } = await runAssignUpdate(assignmentPayload);

        // Backward compatibility for schema drift:
        // if optional columns are missing in some environments, retry without them.
        const removableOptionalColumns = new Set(Object.keys(optionalAssignPayload));
        while (error) {
            const rawAssignErrorMessage = [
                error.message,
                error.details,
                error.hint,
                error.code ? `code=${error.code}` : null
            ]
                .filter(Boolean)
                .join(' | ');

            const missingOptionalColumns = [...removableOptionalColumns].filter((columnName) =>
                new RegExp(`\\b${columnName}\\b`, 'i').test(rawAssignErrorMessage)
            );

            if (missingOptionalColumns.length > 0) {
                for (const missingColumn of missingOptionalColumns) {
                    removableOptionalColumns.delete(missingColumn);
                    delete assignmentPayload[missingColumn];
                }

                console.warn(
                    `⚠️ [JobService.acceptOffer] Retrying assignment without optional columns: ${missingOptionalColumns.join(', ')}`
                );

                ({ data: updatedJob, error } = await runAssignUpdate(assignmentPayload));
                continue;
            }

            const isUnsupportedOnTheWayStatusError =
                /jobs_status_check/i.test(rawAssignErrorMessage) ||
                /invalid input value for enum/i.test(rawAssignErrorMessage) ||
                /on_the_way/i.test(rawAssignErrorMessage);

            if (
                isUnsupportedOnTheWayStatusError &&
                statusAttemptIndex < fallbackAssignableStatuses.length - 1
            ) {
                statusAttemptIndex += 1;
                assignmentPayload.status = fallbackAssignableStatuses[statusAttemptIndex];
                console.warn(
                    `⚠️ [JobService.acceptOffer] Retrying assignment with legacy-compatible status: ${assignmentPayload.status}`
                );
                ({ data: updatedJob, error } = await runAssignUpdate(assignmentPayload));
                continue;
            }

            break;
        }

        if (error) {
            const rawAssignErrorMessage = [
                error.message,
                error.details,
                error.hint,
                error.code ? `code=${error.code}` : null
            ]
                .filter(Boolean)
                .join(' | ');

            console.error('❌ [JobService.acceptOffer] Failed to assign job', {
                jobId,
                offerId,
                offerTechnicianId: offer.technician_id,
                error: rawAssignErrorMessage,
                payloadKeys: Object.keys(assignmentPayload)
            });

            const err = new Error(
                `Failed to assign job: ${rawAssignErrorMessage || 'unknown database error'}`
            );
            err.code = 'ACCEPT_FAILED';
            err.dbCode = error.code;
            err.dbError = error;
            throw err;
        }
        if (!updatedJob) {
            const latest = await this._getJob(jobId);
            if (latest.accepted_bid_id === offerId && latest.technician_id) {
                return latest;
            }

            // Compatibility for schemas without accepted_bid_id:
            // if the job already advanced and has assigned technician, treat as accepted.
            const advancedStatuses = [
                JOB_STATES.ACCEPTED,
                JOB_STATES.PRICE_PENDING,
                JOB_STATES.ON_THE_WAY,
                JOB_STATES.ARRIVED,
                JOB_STATES.IN_PROGRESS,
                JOB_STATES.PENDING_CONFIRM,
                JOB_STATES.COMPLETED,
                JOB_STATES.RATED
            ];
            if (latest.technician_id && advancedStatuses.includes(latest.status)) {
                return latest;
            }

            const err = new Error('Job is no longer available');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = latest.status;
            throw err;
        }

        // 3. Mark offer as accepted
        await supabaseAdmin
            .from('job_offers')
            .update({
                status: 'accepted',
                is_active: true,
                updated_at: new Date().toISOString()
            })
            .eq('id', offerId);

        // 4. Reject all other offers for this job.
        await supabaseAdmin
            .from('job_offers')
            .update({
                status: 'rejected',
                is_active: false,
                updated_at: new Date().toISOString()
            })
            .eq('job_id', jobId)
            .neq('id', offerId);

        // 5. Notify Technician (best effort, should not break acceptance).
        await this._notifyOfferAccepted(offer.technician_id, jobId, offer.price);

        return updatedJob;
    }

    /**
     * Transition: accepted -> price_pending
     */
    async setPrice(jobId, technicianId, price, notes, paymentMethod) {
        if (price <= 0) throw new Error('Price must be positive');

        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.PRICE_PENDING);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                technician_price: price,
                status: JOB_STATES.PRICE_PENDING,
                metadata: { ...job.metadata, price_notes: notes, payment_method: paymentMethod },
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to set price');

        // Send notification to customer (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'price_request',
            title: 'عرض سعر جديد',
            body: `الفني أرسل عرض سعر: ${price} ريال`,
            data: { job_id: jobId, price },
            is_read: false
        });

        // Send push notification (FCM)
        await notifyPriceRequest(jobId, job.customer_id, price);

        return updatedJob;
    }

    /**
     * Transition: price_pending -> on_the_way
     */
    async confirmPrice(jobId, customerId) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.ON_THE_WAY);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                final_price: job.technician_price,
                status: JOB_STATES.ON_THE_WAY,
                price_confirmed_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to confirm price');

        // Send notification to technician (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.technician_id,
            type: 'price_confirmed',
            title: 'تم قبول السعر',
            body: 'العميل وافق على السعر. تحرّك الآن إلى موقع العميل.',
            data: { job_id: jobId },
            is_read: false
        });

        // Send push notification (FCM)
        await sendPushNotification(job.technician_id, {
            title: 'تم قبول السعر ✅',
            body: 'العميل وافق على السعر. تحرّك الآن إلى موقع العميل.',
            data: { type: 'price_confirmed', job_id: jobId }
        });

        return updatedJob;
    }

    /**
     * Transition: on_the_way -> arrived -> in_progress
     */
    async updateTechnicianProgress(jobId, technicianId, progress) {
        const normalizedProgress = String(progress || '').trim().toLowerCase();
        const allowedProgress = new Set(['arrived', 'start_work']);

        if (!allowedProgress.has(normalizedProgress)) {
            const err = new Error('Invalid progress action');
            err.code = 'INVALID_INPUT';
            throw err;
        }

        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            const err = new Error('Unauthorized');
            err.code = 'UNAUTHORIZED';
            throw err;
        }

        let nextStatus = job.status;
        if (normalizedProgress === 'arrived') {
            nextStatus = JOB_STATES.ARRIVED;
            if (job.status === JOB_STATES.ARRIVED) {
                return job;
            }
            validateTransition(job.status, nextStatus);
        }

        if (normalizedProgress === 'start_work') {
            nextStatus = JOB_STATES.IN_PROGRESS;
            if (job.status === JOB_STATES.IN_PROGRESS) {
                return job;
            }

            if (job.status !== JOB_STATES.ARRIVED && job.status !== JOB_STATES.ON_THE_WAY) {
                const err = new Error(
                    `Cannot start work while job is '${job.status}'. Expected 'arrived' or 'on_the_way'.`
                );
                err.code = 'INVALID_STATUS_TRANSITION';
                err.currentStatus = job.status;
                throw err;
            }
        }

        const nowIso = new Date().toISOString();
        const updatePayload = {
            status: nextStatus,
            updated_at: nowIso
        };

        if (nextStatus === JOB_STATES.IN_PROGRESS && !job.accepted_at) {
            updatePayload.accepted_at = nowIso;
        }

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update(updatePayload)
            .eq('id', jobId)
            .eq('technician_id', technicianId)
            .select()
            .single();

        if (error) {
            const err = new Error(`Failed to update technician progress: ${error.message}`);
            err.code = 'DATABASE_ERROR';
            throw err;
        }

        const notificationByStatus = {
            [JOB_STATES.ARRIVED]: {
                type: 'technician_arrived',
                title: 'الفني وصل',
                body: 'الفني وصل إلى موقعك.',
                pushTitle: 'الفني وصل 📍',
                pushBody: 'الفني وصل إلى موقعك.'
            },
            [JOB_STATES.IN_PROGRESS]: {
                type: 'work_started',
                title: 'بدأ تنفيذ الخدمة',
                body: 'الفني بدأ تنفيذ الخدمة الآن.',
                pushTitle: 'بدأ تنفيذ الخدمة 🔧',
                pushBody: 'الفني بدأ تنفيذ الخدمة الآن.'
            }
        };

        const notification = notificationByStatus[nextStatus];
        if (notification && job.customer_id) {
            await supabaseAdmin.from('notifications').insert({
                user_id: job.customer_id,
                type: notification.type,
                title: notification.title,
                body: notification.body,
                data: { job_id: jobId, status: nextStatus },
                is_read: false
            });

            await sendPushNotification(job.customer_id, {
                title: notification.pushTitle,
                body: notification.pushBody,
                data: {
                    type: notification.type,
                    job_id: jobId,
                    status: nextStatus
                }
            });
        }

        return updatedJob;
    }

    /**
     * Transition: in_progress -> completed
     */
    /**
     * Transition: in_progress -> pending_confirm
     */
    async requestCompletion(jobId, technicianId, { finalPrice, notes, afterPhotos } = {}) {
        const job = await this._getJob(jobId);

        if (job.technician_id !== technicianId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.PENDING_CONFIRM);

        const updates = {
            status: JOB_STATES.PENDING_CONFIRM,
            updated_at: new Date().toISOString()
        };

        if (finalPrice) updates.final_price = finalPrice;
        if (notes) updates.work_notes = notes;
        if (afterPhotos && Array.isArray(afterPhotos)) updates.after_photos = afterPhotos;

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update(updates)
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to request completion');

        // Send notification to customer (in-app)
        await supabaseAdmin.from('notifications').insert({
            user_id: job.customer_id,
            type: 'completion_request',
            title: 'تأكيد إكمال الخدمة',
            body: 'الفني قام بإنهاء العمل. يرجى تأكيد استلام الخدمة لإغلاق الطلب.',
            data: { job_id: jobId },
            is_read: false
        });

        // Send push notification (FCM)
        await notifyJobCompleted(jobId, job.customer_id);

        return updatedJob;
    }

    /**
     * Transition: pending_confirm -> completed
     */
    async confirmJobCompletion(jobId, customerId, paymentMethod) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.COMPLETED);

        // Update metadata with payment info
        const metadata = {
            ...job.metadata,
            payment_method: paymentMethod || 'cash', // Default to cash if not provided
            payment_status: 'paid'
        };

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.COMPLETED,
                completed_at: new Date().toISOString(),
                metadata: metadata,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to confirm completion');

        // Send notification to technician
        await supabaseAdmin.from('notifications').insert({
            user_id: job.technician_id,
            type: 'job_completed',
            title: 'تم إغلاق الطلب',
            body: 'العميل قام بتأكيد إكمال الخدمة. شكراً لك!',
            data: { job_id: jobId },
            is_read: false
        });

        // Process Commission (Deduct from Technician Wallet)
        try {
            const amount = job.final_price || job.technician_price || 0;
            if (amount > 0) {
                await supabaseAdmin.rpc('process_job_payment', {
                    job_id: jobId,
                    tech_id: job.technician_id,
                    amount: amount
                });
                console.log(`💰 Commission processed for Job ${jobId}, Amount: ${amount}`);
            }
        } catch (commError) {
            console.error('❌ Failed to process commission:', commError);
        }

        return updatedJob;
    }

    /**
     * Transition: completed -> rated
     */
    async rate(jobId, customerId, rating, review) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== customerId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.RATED);

        // 1. Insert into reviews table
        // This will fire the 'on_review_created' trigger to update user rating
        const { error: reviewError } = await supabaseAdmin
            .from('reviews')
            .insert({
                job_id: jobId,
                reviewer_id: customerId,
                reviewee_id: job.technician_id,
                rating: rating,
                comment: review
            });

        if (reviewError) {
            // Handle duplicate review or other errors
            if (reviewError.code === '23505') { // Unique violation
                throw new Error('Review already exists for this job');
            }
            throw new Error(`Failed to create review: ${reviewError.message}`);
        }

        // 2. Update Job Status
        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.RATED,
                rated_at: new Date().toISOString(),
                // We can still keep these for quick access if schema has them, 
                // but 'reviews' table is now the source of truth.
                // customer_rating: rating, 
                // customer_review: review,
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to update job status');

        return updatedJob;
    }

    /**
     * Transition: * -> cancelled
     */
    async cancel(jobId, userId, reason) {
        const job = await this._getJob(jobId);

        if (job.customer_id !== userId && job.technician_id !== userId) {
            throw new Error('Unauthorized');
        }

        validateTransition(job.status, JOB_STATES.CANCELLED);

        const { data: updatedJob, error } = await supabaseAdmin
            .from('jobs')
            .update({
                status: JOB_STATES.CANCELLED,
                cancelled_at: new Date().toISOString(),
                metadata: { ...job.metadata, cancellation_reason: reason, cancelled_by: userId },
                updated_at: new Date().toISOString()
            })
            .eq('id', jobId)
            .select()
            .single();

        if (error) throw new Error('Failed to cancel job');
        return updatedJob;
    }

    // Helper: Get Job or Throw
    async _getJob(jobId) {
        const { data: job, error } = await supabaseAdmin
            .from('jobs')
            .select('*')
            .eq('id', jobId)
            .single();

        if (error || !job) {
            const err = new Error('Job not found');
            err.code = 'JOB_NOT_FOUND';
            throw err;
        }

        return job;
    }

    async _tryAcceptOfferAtomically(jobId, customerId, offerId) {
        try {
            const { data, error } = await supabaseAdmin.rpc('accept_job_offer_atomic', {
                p_job_id: jobId,
                p_customer_id: customerId,
                p_offer_id: offerId
            });

            if (error) {
                const raw = [
                    error.message,
                    error.details,
                    error.hint,
                    error.code ? `code=${error.code}` : null
                ]
                    .filter(Boolean)
                    .join(' | ');

                // Migration not applied yet in this environment.
                if (error.code === 'PGRST202' || /accept_job_offer_atomic/i.test(raw)) {
                    console.warn('⚠️ [JobService.acceptOffer] Atomic RPC unavailable. Falling back to legacy path.');
                    return { handled: false };
                }

                const err = new Error(`Atomic accept failed: ${raw || 'unknown database error'}`);
                err.code = 'ACCEPT_FAILED';
                err.dbCode = error.code;
                err.dbError = error;
                throw err;
            }

            const payload = data && typeof data === 'object' ? data : null;
            if (!payload || typeof payload.success !== 'boolean') {
                // RPC contract not available (or mocked with legacy value); use fallback path.
                return { handled: false };
            }

            if (payload.success !== true) {
                const err = new Error(payload.message || 'Failed to accept offer');
                err.code = payload.code || 'ACCEPT_FAILED';
                if (payload.current_status) {
                    err.currentStatus = payload.current_status;
                }
                if (payload.locked_job_id) {
                    err.lockedJobId = payload.locked_job_id;
                }
                throw err;
            }

            const resolvedJob = payload.job || await this._getJob(jobId);
            return {
                handled: true,
                job: resolvedJob,
                technicianId: payload.technician_id || resolvedJob.technician_id,
                acceptedPrice: payload.accepted_price || resolvedJob.final_price || resolvedJob.technician_price
            };
        } catch (error) {
            if (error?.code) {
                throw error;
            }
            const err = new Error(error?.message || 'Failed to accept offer');
            err.code = 'ACCEPT_FAILED';
            throw err;
        }
    }

    async _notifyOfferAccepted(technicianId, jobId, offerPrice) {
        if (!technicianId) return;
        try {
            await supabaseAdmin.from('notifications').insert({
                user_id: technicianId,
                type: 'offer_accepted',
                title: 'تم قبول عرضك!',
                body: `العميل قبل عرضك بقيمة ${offerPrice ?? ''} ريال. تحرّك الآن إلى موقع العميل.`,
                data: { job_id: jobId },
                is_read: false
            });
        } catch (error) {
            console.warn('⚠️ [JobService.acceptOffer] Failed to notify technician:', error?.message || error);
        }
    }

    async _getOfferById(jobId, offerId) {
        const { data: offer, error } = await supabaseAdmin
            .from('job_offers')
            .select('*')
            .eq('id', offerId)
            .eq('job_id', jobId)
            .single();

        if (error || !offer) {
            const err = new Error('Offer not found');
            err.code = 'NOT_FOUND';
            throw err;
        }

        return offer;
    }

    async _ensureCustomerCanCreateJob(customerId) {
        const { data, error } = await supabaseAdmin
            .from('jobs')
            .select('id, status')
            .eq('customer_id', customerId)
            .in('status', CUSTOMER_LOCKED_STATUSES)
            .limit(1);

        if (error) {
            const err = new Error(`Failed to validate customer lock: ${error.message}`);
            err.code = 'DATABASE_ERROR';
            throw err;
        }

        if (data && data.length > 0) {
            const lockedJob = data[0];
            const err = new Error('لديك طلب نشط حالياً. لا يمكنك إنشاء طلب جديد حتى انتهاء الطلب الحالي.');
            err.code = 'ACTIVE_JOB_LOCKED';
            err.currentStatus = lockedJob.status;
            err.lockedJobId = lockedJob.id;
            throw err;
        }
    }

    async _ensureTechnicianCanTakeNewWork(technicianId, { currentJobId = null } = {}) {
        let query = supabaseAdmin
            .from('jobs')
            .select('id, status')
            .eq('technician_id', technicianId)
            .in('status', TECHNICIAN_LOCKED_STATUSES);

        if (currentJobId) {
            query = query.neq('id', currentJobId);
        }

        const { data, error } = await query.limit(1);

        if (error) {
            const err = new Error(`Failed to validate technician lock: ${error.message}`);
            err.code = 'DATABASE_ERROR';
            throw err;
        }

        if (data && data.length > 0) {
            const lockedJob = data[0];
            const err = new Error('لا يمكنك استقبال طلبات جديدة أثناء تنفيذ طلب نشط.');
            err.code = 'ACTIVE_JOB_LOCKED';
            err.currentStatus = lockedJob.status;
            err.lockedJobId = lockedJob.id;
            throw err;
        }
    }

    async _cancelOpenSearchJobsForCustomer(customerId) {
        try {
            const nowIso = new Date().toISOString();
            const { data: updated, error } = await supabaseAdmin
                .from('jobs')
                .update({
                    status: JOB_STATES.CANCELLED,
                    cancelled_at: nowIso,
                    cancelled_by: customerId,
                    cancel_reason: 'superseded_by_new_request',
                    next_search_at: null,
                    updated_at: nowIso
                })
                .eq('customer_id', customerId)
                .in('status', [JOB_STATES.PENDING, JOB_STATES.SEARCHING, JOB_STATES.NO_TECHNICIAN])
                .select('id');

            if (error) {
                console.warn('⚠️ [JobService.create] Failed to cancel older open jobs:', error.message);
                return;
            }

            if (updated && updated.length > 0) {
                console.log(`🧹 [JobService.create] Cancelled ${updated.length} older open jobs for customer ${customerId}`);
            }
        } catch (error) {
            console.warn('⚠️ [JobService.create] Unexpected cleanup error:', error?.message || error);
        }
    }
}

export const jobService = new JobService();

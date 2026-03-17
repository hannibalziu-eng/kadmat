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

const ALLOWED_PRICING_MODES = ['technician_quote', 'catalog_fixed'];

const normalizeCatalogItemInput = (item) => ({
    service_catalog_item_id: item?.service_catalog_item_id ?? item?.serviceCatalogItemId ?? item?.id ?? null,
    quantity: Number(item?.quantity ?? 1)
});

const buildPricingSummary = ({ pricingMode, subtotal, itemCount, currencyCode }) => ({
    pricing_mode: pricingMode,
    catalog_subtotal: subtotal,
    catalog_item_count: itemCount,
    currency_code: currencyCode
});

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

        const pricingMode = ALLOWED_PRICING_MODES.includes(jobData.pricing_mode)
            ? jobData.pricing_mode
            : 'technician_quote';

        if (pricingMode === 'catalog_fixed') {
            return this._createCatalogFixedJob(userId, jobData);
        }

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
            metadata: jobData.metadata || {},
            pricing_mode: 'technician_quote',
            quote_required: true,
            catalog_item_count: 0,
            catalog_subtotal: null,
            pricing_summary: buildPricingSummary({
                pricingMode: 'technician_quote',
                subtotal: null,
                itemCount: 0,
                currencyCode: 'LYD'
            })
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

    async _createCatalogFixedJob(userId, jobData) {
        const catalogItems = Array.isArray(jobData.catalog_items)
            ? jobData.catalog_items.map(normalizeCatalogItemInput)
            : [];

        if (catalogItems.length === 0) {
            throw new Error('catalog_items are required for catalog_fixed jobs');
        }

        const { data: service, error: serviceError } = await supabaseAdmin
            .from('services')
            .select('id, pricing_mode_default, is_catalog_enabled, is_active')
            .eq('id', jobData.service_id)
            .maybeSingle();

        if (serviceError) throw serviceError;
        if (!service || !service.is_active) {
            throw new Error('Service not found');
        }

        if (!service.is_catalog_enabled && service.pricing_mode_default !== 'catalog_fixed') {
            throw new Error('Selected service does not support fixed-price catalog flow');
        }

        const itemIds = catalogItems.map((item) => item.service_catalog_item_id).filter(Boolean);
        if (itemIds.length !== catalogItems.length) {
            throw new Error('Each catalog item must include service_catalog_item_id');
        }

        const { data: serviceCatalogItems, error: itemsError } = await supabaseAdmin
            .from('service_catalog_items')
            .select('*')
            .eq('service_id', jobData.service_id)
            .eq('is_active', true)
            .in('id', itemIds);

        if (itemsError) throw itemsError;

        const catalogMap = new Map((serviceCatalogItems || []).map((item) => [item.id, item]));
        if (catalogMap.size !== itemIds.length) {
            throw new Error('One or more catalog items are invalid, inactive, or do not belong to the selected service');
        }

        const jobLineItems = catalogItems.map((item) => {
            const quantity = Number(item.quantity || 0);
            if (!Number.isFinite(quantity) || quantity <= 0) {
                throw new Error('Catalog item quantity must be greater than zero');
            }

            const source = catalogMap.get(item.service_catalog_item_id);
            const unitPrice = Number(source.price || 0);
            const lineTotal = Number((unitPrice * quantity).toFixed(2));

            return {
                service_catalog_item_id: source.id,
                name: source.name,
                name_ar: source.name_ar,
                unit_price: unitPrice,
                quantity,
                line_total: lineTotal,
                currency_code: source.currency_code || 'LYD',
                item_snapshot: source
            };
        });

        const catalogSubtotal = Number(jobLineItems.reduce((sum, item) => sum + item.line_total, 0).toFixed(2));
        const catalogItemCount = jobLineItems.reduce((sum, item) => sum + item.quantity, 0);
        const currencyCode = jobLineItems[0]?.currency_code || 'LYD';

        const jobToInsert = {
            customer_id: userId,
            service_id: jobData.service_id,
            lat: jobData.lat,
            lng: jobData.lng,
            location: `SRID=4326;POINT(${jobData.lng} ${jobData.lat})`,
            address_text: jobData.address_text,
            description: jobData.description,
            initial_price: catalogSubtotal,
            status: JOB_STATES.PENDING,
            search_radius: 5000,
            metadata: jobData.metadata || {},
            pricing_mode: 'catalog_fixed',
            quote_required: false,
            catalog_item_count: catalogItemCount,
            catalog_subtotal: catalogSubtotal,
            pricing_summary: buildPricingSummary({
                pricingMode: 'catalog_fixed',
                subtotal: catalogSubtotal,
                itemCount: catalogItemCount,
                currencyCode
            })
        };

        const { data: job, error: jobError } = await supabaseAdmin
            .from('jobs')
            .insert(jobToInsert)
            .select()
            .single();

        if (jobError) {
            const dbError = new Error(`Failed to create job: ${jobError.message || 'Database error'}`);
            dbError.code = jobError.code || 'DB_INSERT_ERROR';
            dbError.details = jobError.details;
            dbError.hint = jobError.hint;
            throw dbError;
        }

        const lineItemsPayload = jobLineItems.map((item) => ({
            job_id: job.id,
            service_catalog_item_id: item.service_catalog_item_id,
            name: item.name,
            name_ar: item.name_ar,
            unit_price: item.unit_price,
            quantity: item.quantity,
            line_total: item.line_total,
            currency_code: item.currency_code,
            item_snapshot: item.item_snapshot
        }));

        const { error: lineItemsError } = await supabaseAdmin
            .from('job_catalog_items')
            .insert(lineItemsPayload);

        if (lineItemsError) {
            const dbError = new Error(`Failed to create job catalog items: ${lineItemsError.message || 'Database error'}`);
            dbError.code = lineItemsError.code || 'DB_INSERT_ERROR';
            dbError.details = lineItemsError.details;
            dbError.hint = lineItemsError.hint;
            throw dbError;
        }

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

        return {
            ...job,
            job_catalog_items: lineItemsPayload
        };
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

        if (job.pricing_mode === 'catalog_fixed' && job.customer_id) {
            const notificationPayload = {
                user_id: job.customer_id,
                type: 'job_accepted',
                title: 'تم قبول طلبك',
                body: 'تم تعيين فني لطلبك وسيبدأ التوجه إليك قريبًا.',
                data: {
                    job_id: jobId,
                    pricing_mode: 'catalog_fixed'
                },
                is_read: false
            };

            await supabaseAdmin.from('notifications').insert(notificationPayload);

            await sendPushNotification(job.customer_id, {
                title: 'تم قبول طلبك! ✅',
                body: 'تم تعيين فني لطلبك وسيبدأ التوجه إليك قريبًا.',
                data: {
                    type: 'job_accepted',
                    job_id: jobId,
                    pricing_mode: 'catalog_fixed'
                }
            });
        }

        return updatedJob;
    }

    _buildFixedPriceRuntimeError(job, message) {
        const err = new Error(message);
        err.code = 'INVALID_STATUS_TRANSITION';
        err.currentStatus = job.status;
        err.pricingMode = job.pricing_mode;
        return err;
    }

    /**
     * Submit an Offer (Technician)
     */
    async submitOffer(jobId, technicianId, price) {
        const job = await this._getJob(jobId);

        if (job.pricing_mode === 'catalog_fixed') {
            const err = new Error('Fixed-price jobs do not accept technician offers');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = job.status;
            err.pricingMode = job.pricing_mode;
            throw err;
        }

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

        if (job.pricing_mode === 'catalog_fixed') {
            const err = new Error('Fixed-price jobs do not support offer acceptance');
            err.code = 'INVALID_STATUS_TRANSITION';
            err.currentStatus = job.status;
            err.pricingMode = job.pricing_mode;
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

        if (job.pricing_mode === 'catalog_fixed') {
            throw this._buildFixedPriceRuntimeError(
                job,
                'Fixed-price jobs do not support technician price submission'
            );
        }

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

        if (job.pricing_mode === 'catalog_fixed') {
            throw this._buildFixedPriceRuntimeError(
                job,
                'Fixed-price jobs do not require customer price confirmation'
            );
        }

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
    async updateTechnicianProgress(jobId, technicianId, progress, { prePhotos } = {}) {
        const normalizedProgress = String(progress || '').trim().toLowerCase();
        const allowedProgress = new Set(['on_the_way', 'arrived', 'start_work']);

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
        if (normalizedProgress === 'on_the_way') {
            if (job.pricing_mode !== 'catalog_fixed') {
                const err = new Error('Only fixed-price jobs can start travel from accepted state');
                err.code = 'INVALID_STATUS_TRANSITION';
                err.currentStatus = job.status;
                err.pricingMode = job.pricing_mode || 'technician_quote';
                throw err;
            }

            nextStatus = JOB_STATES.ON_THE_WAY;
            if (job.status === JOB_STATES.ON_THE_WAY) {
                return job;
            }

            if (job.status !== JOB_STATES.ACCEPTED) {
                const err = new Error(
                    `Cannot start travel while job is '${job.status}'. Expected 'accepted'.`
                );
                err.code = 'INVALID_STATUS_TRANSITION';
                err.currentStatus = job.status;
                err.pricingMode = job.pricing_mode;
                throw err;
            }
        }

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

            const hasPreServicePhotos = await this._hasRequiredPhotos({
                job,
                photoType: 'pre',
                incomingPhotos: prePhotos,
                legacyPhotos: job?.metadata?.pre_service_photos
            });

            if (!hasPreServicePhotos) {
                const err = new Error('لا يمكن بدء العمل قبل رفع صور ما قبل الخدمة.');
                err.code = 'PRE_SERVICE_PHOTOS_REQUIRED';
                err.currentStatus = job.status;
                throw err;
            }
        }

        const nowIso = new Date().toISOString();
        const normalizedPrePhotos = this._sanitizePhotoUrls(prePhotos);
        const updatePayload = {
            status: nextStatus,
            updated_at: nowIso
        };

        if (nextStatus === JOB_STATES.IN_PROGRESS && !job.accepted_at) {
            updatePayload.accepted_at = nowIso;
        }

        if (nextStatus === JOB_STATES.IN_PROGRESS && normalizedPrePhotos.length > 0) {
            updatePayload.metadata = {
                ...job.metadata,
                pre_service_photos: normalizedPrePhotos
            };
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
            [JOB_STATES.ON_THE_WAY]: {
                type: 'technician_on_the_way',
                title: 'الفني في الطريق',
                body: 'الفني بدأ التوجه إلى موقعك.',
                pushTitle: 'الفني في الطريق 🚗',
                pushBody: 'الفني بدأ التوجه إلى موقعك.'
            },
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

        const normalizedAfterPhotos = this._sanitizePhotoUrls(afterPhotos);
        const hasPostServicePhotos = await this._hasRequiredPhotos({
            job,
            photoType: 'post',
            incomingPhotos: normalizedAfterPhotos,
            legacyPhotos: job.after_photos
        });

        if (!hasPostServicePhotos) {
            const err = new Error('لا يمكن إرسال طلب الإنهاء بدون صور ما بعد الخدمة.');
            err.code = 'POST_SERVICE_PHOTOS_REQUIRED';
            err.currentStatus = job.status;
            throw err;
        }

        const updates = {
            status: JOB_STATES.PENDING_CONFIRM,
            updated_at: new Date().toISOString()
        };

        if (finalPrice) updates.final_price = finalPrice;
        if (notes) updates.work_notes = notes;
        if (normalizedAfterPhotos.length > 0) {
            updates.after_photos = normalizedAfterPhotos;
        }

        const optionalUpdateColumns = ['work_notes', 'after_photos'];

        const runCompletionUpdate = async (payload) => {
            return await supabaseAdmin
                .from('jobs')
                .update(payload)
                .eq('id', jobId)
                .select()
                .single();
        };

        let completionPayload = { ...updates };
        let { data: updatedJob, error } = await runCompletionUpdate(completionPayload);

        while (error) {
            const rawCompletionError = [
                error.message,
                error.details,
                error.hint,
                error.code ? `code=${error.code}` : null
            ]
                .filter(Boolean)
                .join(' | ');

            const removableColumns = optionalUpdateColumns.filter((columnName) =>
                Object.prototype.hasOwnProperty.call(completionPayload, columnName) &&
                new RegExp(`\\b${columnName}\\b`, 'i').test(rawCompletionError)
            );

            if (removableColumns.length === 0) {
                break;
            }

            for (const columnName of removableColumns) {
                delete completionPayload[columnName];
            }

            console.warn(
                `⚠️ [JobService.requestCompletion] Retrying without optional columns: ${removableColumns.join(', ')}`
            );
            ({ data: updatedJob, error } = await runCompletionUpdate(completionPayload));
        }

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

        if ([JOB_STATES.ARRIVED, JOB_STATES.IN_PROGRESS].includes(job.status)) {
            const err = new Error('لا يمكن إلغاء الطلب بعد وصول الفني أو بدء تنفيذ العمل.');
            err.code = 'CANCELLATION_RESTRICTED';
            err.currentStatus = job.status;
            throw err;
        }

        if (
            job.pricing_mode === 'catalog_fixed' &&
            job.status === JOB_STATES.ACCEPTED &&
            job.technician_id === userId
        ) {
            const releasedAt = new Date().toISOString();
            const releaseReason = reason || 'technician_released_before_travel';
            const metadata = {
                ...job.metadata,
                release_reason: releaseReason,
                released_by: userId,
                released_at: releasedAt
            };

            const { data: reopenedJob, error } = await supabaseAdmin
                .from('jobs')
                .update({
                    status: JOB_STATES.PENDING,
                    technician_id: null,
                    accepted_at: null,
                    metadata,
                    updated_at: releasedAt
                })
                .eq('id', jobId)
                .eq('technician_id', userId)
                .eq('status', JOB_STATES.ACCEPTED)
                .select()
                .single();

            if (error) throw new Error('Failed to reopen fixed-price job');

            if (job.customer_id) {
                await supabaseAdmin.from('notifications').insert({
                    user_id: job.customer_id,
                    type: 'technician_timeout',
                    title: 'جاري إعادة البحث عن فني',
                    body: 'تعذر متابعة الفني الحالي. جارٍ إعادة البحث عن فني بديل.',
                    data: {
                        job_id: jobId,
                        pricing_mode: 'catalog_fixed',
                        restart_search: true
                    },
                    is_read: false
                });

                await sendPushNotification(job.customer_id, {
                    title: 'جاري إعادة البحث عن فني',
                    body: 'تعذر متابعة الفني الحالي. جارٍ إعادة البحث عن فني بديل.',
                    data: {
                        type: 'technician_timeout',
                        job_id: jobId,
                        pricing_mode: 'catalog_fixed'
                    }
                });
            }

            return reopenedJob;
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
                if (this._shouldFallbackFromAtomicFailure(payload)) {
                    const rawPayload = JSON.stringify({
                        code: payload.code,
                        message: payload.message,
                        sqlstate: payload.sqlstate
                    });
                    console.warn(
                        `⚠️ [JobService.acceptOffer] Atomic RPC returned recoverable failure (${rawPayload}). Falling back to legacy path.`
                    );
                    return { handled: false };
                }

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

    _shouldFallbackFromAtomicFailure(payload) {
        const code = String(payload?.code || '').trim().toUpperCase();
        if (code !== 'ACCEPT_FAILED') {
            return false;
        }

        // Any ACCEPT_FAILED from atomic RPC is treated as contract/schema drift.
        // Legacy flow has guarded retries for missing optional columns and
        // legacy status constraints, so fallback is safer than surfacing 500.
        return true;
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
        await this._ensureTechnicianWalletHasNoDebt(technicianId);

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

    async _ensureTechnicianWalletHasNoDebt(technicianId) {
        const { data: wallet, error } = await supabaseAdmin
            .from('wallets')
            .select('id, balance, currency, is_frozen')
            .eq('user_id', technicianId)
            .maybeSingle();

        if (error) {
            const err = new Error(`Failed to validate technician wallet: ${error.message}`);
            err.code = 'DATABASE_ERROR';
            throw err;
        }

        if (!wallet) {
            // Keep backward compatibility in environments where wallet bootstrap
            // is temporarily inconsistent. Active-job locking will still apply.
            return;
        }

        const balance = Number(wallet.balance ?? 0);
        if (!Number.isFinite(balance) || balance >= 0) {
            return;
        }

        const debtAmount = Math.abs(balance);
        const currency = wallet.currency || 'SAR';
        const err = new Error(
            `لا يمكنك استقبال طلبات جديدة حتى سداد المديونية المستحقة (${debtAmount.toFixed(2)} ${currency}).`
        );
        err.code = 'TECHNICIAN_WALLET_DEBT_LOCKED';
        err.debtAmount = debtAmount;
        err.currency = currency;
        err.walletId = wallet.id;
        throw err;
    }

    _sanitizePhotoUrls(photoList) {
        if (!Array.isArray(photoList)) {
            return [];
        }

        const normalized = photoList
            .map((item) => (typeof item === 'string' ? item.trim() : ''))
            .filter(Boolean);

        return [...new Set(normalized)];
    }

    async _hasRequiredPhotos({ job, photoType, incomingPhotos, legacyPhotos }) {
        const normalizedIncoming = this._sanitizePhotoUrls(incomingPhotos);
        const normalizedLegacy = this._sanitizePhotoUrls(legacyPhotos);

        const hasIncoming = normalizedIncoming.length > 0;
        const hasLegacy = normalizedLegacy.length > 0;
        if (hasIncoming || hasLegacy) {
            return true;
        }

        const hasTablePhotos = await this._hasJobPhotosTableRecords(job.id, photoType);
        if (hasTablePhotos === null) {
            // Table does not exist in some environments yet; rely on payload/legacy fallback.
            return false;
        }

        return hasTablePhotos;
    }

    async _hasJobPhotosTableRecords(jobId, photoType) {
        const { data, error } = await supabaseAdmin
            .from('job_photos')
            .select('id')
            .eq('job_id', jobId)
            .eq('photo_type', photoType)
            .limit(1);

        if (!error) {
            return Array.isArray(data) && data.length > 0;
        }

        if (this._isMissingRelationError(error, 'job_photos')) {
            return null;
        }

        const err = new Error(`Failed to validate ${photoType} service photos: ${error.message}`);
        err.code = 'DATABASE_ERROR';
        throw err;
    }

    _isMissingRelationError(error, relationName) {
        if (!error) return false;

        const code = String(error.code || '').toUpperCase();
        if (code === '42P01' || code === 'PGRST205' || code === 'PGRST204') {
            return true;
        }

        const raw = [error.message, error.details, error.hint]
            .filter(Boolean)
            .join(' ')
            .toLowerCase();

        return raw.includes(String(relationName).toLowerCase()) && raw.includes('does not exist');
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

-- Backfill existing notifications into the segmentation contract fields.

BEGIN;

WITH role_lookup AS (
    SELECT id, user_type
    FROM public.users
)
UPDATE public.notifications AS n
SET audience_role = CASE
    WHEN n.type IN ('new_job_offer', 'offer_accepted', 'price_confirmed', 'job_completed', 'penalty_warning', 'new_job')
        THEN 'technician'
    WHEN n.type IN ('new_offer', 'price_request', 'technician_arrived', 'work_started', 'completion_request', 'no_technician', 'technician_timeout', 'job_accepted', 'price_set', 'price_pending', 'completed')
        THEN 'customer'
    WHEN rl.user_type IN ('customer', 'technician', 'admin')
        THEN rl.user_type
    ELSE 'all'
END
FROM role_lookup rl
WHERE rl.id = n.user_id;

UPDATE public.notifications AS n
SET category = CASE
    WHEN n.type IN ('new_job_offer', 'no_technician', 'new_job')
        THEN 'job'
    WHEN n.type IN ('new_offer', 'price_request', 'price_set', 'price_pending')
        THEN 'offer'
    WHEN n.type IN ('technician_arrived', 'work_started', 'completion_request', 'technician_timeout', 'job_accepted', 'offer_accepted', 'price_confirmed')
        THEN 'message'
    WHEN n.type IN ('job_completed', 'completed')
        THEN 'payment'
    ELSE 'system'
END;

UPDATE public.notifications
SET channels = ARRAY['inbox']::TEXT[]
WHERE channels IS NULL OR COALESCE(array_length(channels, 1), 0) = 0;

UPDATE public.notifications AS n
SET entity_type = 'job'
WHERE n.entity_type IS NULL
  AND (
    n.data ? 'job_id'
    OR n.data ? 'jobId'
  );

UPDATE public.notifications AS n
SET entity_id = COALESCE(
    CASE
        WHEN (n.data ->> 'job_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
            THEN (n.data ->> 'job_id')::uuid
        ELSE NULL
    END,
    CASE
        WHEN (n.data ->> 'jobId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
            THEN (n.data ->> 'jobId')::uuid
        ELSE NULL
    END,
    n.entity_id
)
WHERE n.entity_id IS NULL;

UPDATE public.notifications
SET priority = CASE
    WHEN type IN ('offer_accepted') THEN 5
    WHEN type IN ('new_job_offer', 'new_offer', 'price_request', 'price_confirmed', 'technician_arrived', 'completion_request', 'job_accepted', 'penalty_warning', 'technician_timeout') THEN 4
    WHEN type IN ('work_started', 'no_technician', 'job_completed', 'price_set', 'price_pending', 'completed') THEN 3
    ELSE 2
END
WHERE priority IS NULL OR priority < 1 OR priority > 5;

COMMIT;

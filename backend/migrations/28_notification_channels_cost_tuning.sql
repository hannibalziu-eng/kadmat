-- Tune channels for low-urgency notification types to reduce push fan-out noise.

BEGIN;

UPDATE public.notifications
SET channels = ARRAY['inbox', 'in_app']::TEXT[]
WHERE type IN (
    'work_started',
    'job_completed',
    'no_technician',
    'penalty_warning',
    'new_job',
    'completed'
);

COMMIT;


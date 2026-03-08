\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_indexes text;
  missing_policies text;
BEGIN
  IF to_regclass('public.notification_lifecycle_events') IS NULL THEN
    RAISE EXCEPTION 'Missing table: public.notification_lifecycle_events';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notification_lifecycle_events_stage_check'
      AND conrelid = 'public.notification_lifecycle_events'::regclass
  ) THEN
    RAISE EXCEPTION 'Missing constraint: notification_lifecycle_events_stage_check';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'notification_lifecycle_events'
      AND c.relrowsecurity = TRUE
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled on public.notification_lifecycle_events';
  END IF;

  WITH required(index_name) AS (
    VALUES
      ('idx_notification_lifecycle_events_user_created'),
      ('idx_notification_lifecycle_events_request'),
      ('idx_notification_lifecycle_events_entity'),
      ('uq_notification_lifecycle_event_fingerprint')
  )
  SELECT string_agg(index_name, ', ' ORDER BY index_name)
  INTO missing_indexes
  FROM required r
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_indexes i
    WHERE i.schemaname = 'public'
      AND i.tablename = 'notification_lifecycle_events'
      AND i.indexname = r.index_name
  );

  IF missing_indexes IS NOT NULL THEN
    RAISE EXCEPTION 'Missing notification lifecycle indexes: %', missing_indexes;
  END IF;

  WITH required(policy_name) AS (
    VALUES
      ('notification_lifecycle_events_select_own'),
      ('notification_lifecycle_events_insert_own')
  )
  SELECT string_agg(policy_name, ', ' ORDER BY policy_name)
  INTO missing_policies
  FROM required r
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename = 'notification_lifecycle_events'
      AND p.policyname = r.policy_name
  );

  IF missing_policies IS NOT NULL THEN
    RAISE EXCEPTION 'Missing notification lifecycle RLS policies: %', missing_policies;
  END IF;

  RAISE NOTICE 'Notification lifecycle contract checks passed.';
END $$;

SELECT
  event_stage,
  count(*) AS event_count
FROM public.notification_lifecycle_events
GROUP BY event_stage
ORDER BY event_stage;


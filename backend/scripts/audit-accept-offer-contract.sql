-- Accept-offer contract SQL audit (DB-only, SQL Editor friendly)
-- Run this after migrations 22 -> 25.

-- 1) jobs.accepted_bid_id must exist
SELECT EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'jobs'
    AND column_name = 'accepted_bid_id'
) AS has_jobs_accepted_bid_id;

-- 2) Required RPC signatures must exist
SELECT to_regprocedure(
  'public.accept_job_offer_atomic(uuid,uuid,uuid)'
) IS NOT NULL AS has_accept_job_offer_atomic_rpc;

SELECT to_regprocedure(
  'public.update_user_location(double precision,double precision,uuid)'
) IS NOT NULL AS has_update_user_location_rpc;

-- 3) accept_job_offer_atomic smoke call with zero UUIDs
WITH payload AS (
  SELECT public.accept_job_offer_atomic(
    '00000000-0000-0000-0000-000000000000'::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid
  ) AS body
)
SELECT
  body->>'success' AS success_flag,
  body->>'code' AS code,
  body->>'message' AS message
FROM payload;

-- 4) update_user_location smoke check:
-- Missing function should fail. "User not found" is acceptable proof that function exists.
DO $$
BEGIN
  BEGIN
    PERFORM public.update_user_location(
      24.7136::double precision,
      46.6753::double precision,
      '00000000-0000-0000-0000-000000000000'::uuid
    );
    RAISE NOTICE 'update_user_location executed successfully';
  EXCEPTION
    WHEN undefined_function THEN
      RAISE EXCEPTION 'update_user_location RPC is missing';
    WHEN OTHERS THEN
      IF POSITION('User not found' IN SQLERRM) > 0 THEN
        RAISE NOTICE 'update_user_location exists (smoke returned user-not-found as expected)';
      ELSE
        RAISE EXCEPTION 'update_user_location returned unexpected error: %', SQLERRM;
      END IF;
  END;
END $$;


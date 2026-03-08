\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_publication_tables text;
  missing_rls_tables text;
  missing_select_policies text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    RAISE EXCEPTION 'Missing publication: supabase_realtime';
  END IF;

  WITH required(table_name) AS (
    VALUES
      ('jobs'),
      ('job_offers'),
      ('notifications'),
      ('messages'),
      ('users')
  )
  SELECT string_agg(r.table_name, ', ' ORDER BY r.table_name)
  INTO missing_publication_tables
  FROM required r
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables p
    WHERE p.pubname = 'supabase_realtime'
      AND p.schemaname = 'public'
      AND p.tablename = r.table_name
  );

  IF missing_publication_tables IS NOT NULL THEN
    RAISE EXCEPTION
      'Tables missing from supabase_realtime publication: %',
      missing_publication_tables;
  END IF;

  WITH required(table_name) AS (
    VALUES
      ('jobs'),
      ('job_offers'),
      ('notifications'),
      ('messages'),
      ('users')
  )
  SELECT string_agg(r.table_name, ', ' ORDER BY r.table_name)
  INTO missing_rls_tables
  FROM required r
  LEFT JOIN pg_namespace n
    ON n.nspname = 'public'
  LEFT JOIN pg_class c
    ON c.relname = r.table_name
   AND c.relnamespace = n.oid
  WHERE c.oid IS NULL
     OR c.relrowsecurity IS DISTINCT FROM TRUE;

  IF missing_rls_tables IS NOT NULL THEN
    RAISE EXCEPTION
      'Tables missing RLS enablement: %',
      missing_rls_tables;
  END IF;

  WITH required(table_name) AS (
    VALUES
      ('jobs'),
      ('job_offers'),
      ('notifications'),
      ('messages'),
      ('users')
  )
  SELECT string_agg(r.table_name, ', ' ORDER BY r.table_name)
  INTO missing_select_policies
  FROM required r
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_policies pol
    WHERE pol.schemaname = 'public'
      AND pol.tablename = r.table_name
      AND upper(pol.cmd) IN ('SELECT', 'ALL')
  );

  IF missing_select_policies IS NOT NULL THEN
    RAISE EXCEPTION
      'Tables missing SELECT/ALL RLS policies: %',
      missing_select_policies;
  END IF;

  RAISE NOTICE 'Realtime + RLS contract checks passed.';
END $$;

SELECT
  tablename,
  count(*) FILTER (WHERE upper(cmd) IN ('SELECT', 'ALL')) AS select_policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('jobs', 'job_offers', 'notifications', 'messages', 'users')
GROUP BY tablename
ORDER BY tablename;

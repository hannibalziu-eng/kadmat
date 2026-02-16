-- Add missing RPC expected by Flutter LocationSyncService:
-- public.update_user_location(p_lat, p_lng, p_user_id)
-- Idempotent and backward-compatible across minor schema drift.

CREATE OR REPLACE FUNCTION public.update_user_location(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_location_udt TEXT;
  v_has_updated_at BOOLEAN;
  v_has_last_seen BOOLEAN;
  v_has_is_online BOOLEAN;
  v_has_status BOOLEAN;
  v_set_clauses TEXT[];
  v_sql TEXT;
  v_rows INT;
BEGIN
  IF p_lat IS NULL OR p_lng IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_lat, p_lng and p_user_id are required';
  END IF;

  IF p_lat < -90 OR p_lat > 90 OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'Invalid coordinates: lat/lng out of range';
  END IF;

  -- Allow only self-update for authenticated users, unless service role.
  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to update this user location';
  END IF;

  SELECT c.udt_name
  INTO v_location_udt
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'users'
    AND c.column_name = 'location'
  LIMIT 1;

  IF v_location_udt IS NULL THEN
    RAISE EXCEPTION 'users.location column not found';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'updated_at'
  ) INTO v_has_updated_at;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'last_seen'
  ) INTO v_has_last_seen;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'is_online'
  ) INTO v_has_is_online;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'status'
  ) INTO v_has_status;

  v_set_clauses := ARRAY[]::TEXT[];

  IF v_location_udt IN ('geography', 'geometry') THEN
    v_set_clauses := array_append(
      v_set_clauses,
      'location = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography'
    );
  ELSE
    -- Fallback when location is a text column in older environments.
    v_set_clauses := array_append(
      v_set_clauses,
      'location = format(''SRID=4326;POINT(%s %s)'', $1, $2)'
    );
  END IF;

  IF v_has_updated_at THEN
    v_set_clauses := array_append(v_set_clauses, 'updated_at = NOW()');
  END IF;

  IF v_has_last_seen THEN
    v_set_clauses := array_append(v_set_clauses, 'last_seen = NOW()');
  END IF;

  IF v_has_is_online THEN
    v_set_clauses := array_append(v_set_clauses, 'is_online = TRUE');
  END IF;

  IF v_has_status THEN
    v_set_clauses := array_append(v_set_clauses, 'status = ''online''');
  END IF;

  v_sql := format(
    'UPDATE public.users SET %s WHERE id = $3',
    array_to_string(v_set_clauses, ', ')
  );

  EXECUTE v_sql USING p_lng, p_lat, p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) TO service_role;

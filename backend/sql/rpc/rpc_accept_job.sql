-- ============================================
-- 🔒 Secure Job Acceptance RPC
-- ============================================

-- Function to handle job acceptance atomically with locking
CREATE OR REPLACE FUNCTION accept_job_secure(
  p_job_id UUID,
  p_technician_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_job RECORD;
  v_result JSONB;
BEGIN
  -- 1. Lock the row for update to prevent race conditions
  -- NOWAIT means if it's already locked, fail immediately (fast fail)
  -- Or use just FOR UPDATE to wait. Usually for this UX, wait or skip is fine.
  -- Let's use standard FOR UPDATE.
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  -- 2. Validate existence
  IF v_job IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'JOB_NOT_FOUND', 'message', 'الطلب غير موجود');
  END IF;

  -- 3. Validate status (Must be pending, searching, or no_technician_found)
  IF v_job.status NOT IN ('pending', 'searching', 'no_technician_found') THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error_code', 'JOB_ALREADY_ACCEPTED', 
      'message', 'عذراً، تم قبول الطلب مسبقاً من فني آخر',
      'current_status', v_job.status
    );
  END IF;

  -- 4. Update the job
  UPDATE jobs
  SET 
    status = 'accepted',
    technician_id = p_technician_id,
    accepted_at = NOW(),
    updated_at = NOW()
  WHERE id = p_job_id;

  -- 5. Return the updated record
  -- Re-fetch to get any triggers output if needed, or just return success
  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'accepted',
    'technician_id', p_technician_id
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error_code', 'DB_ERROR', 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

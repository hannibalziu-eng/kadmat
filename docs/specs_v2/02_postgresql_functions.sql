-- Critical PostgreSQL Functions for Kadmat

-- Function 1: Accept Bid & Lock Job
CREATE OR REPLACE FUNCTION accept_bid_and_lock_job_safe(
    p_job_id UUID,
    p_bid_id UUID,
    p_customer_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_job RECORD;
    v_bid RECORD;
    v_timer RECORD;
    v_decision_time INTEGER;
    v_confirmation_code TEXT;
BEGIN
    SELECT * INTO v_job
    FROM jobs
    WHERE id = p_job_id
    AND customer_id = p_customer_id
    AND bidding_status = 'open'
    AND status NOT IN ('cancelled', 'completed', 'expired')
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job not available or unauthorized' USING ERRCODE = 'P0001';
    END IF;
    
    SELECT * INTO v_timer
    FROM bidding_timers
    WHERE job_id = p_job_id AND status = 'running';
    
    IF NOT FOUND OR v_timer.ends_at <= NOW() THEN
        UPDATE jobs SET bidding_status = 'expired' WHERE id = p_job_id;
        RAISE EXCEPTION 'Bidding expired' USING ERRCODE = 'P0001';
    END IF;
    
    SELECT * INTO v_bid
    FROM bids
    WHERE id = p_bid_id
    AND job_id = p_job_id
    AND status = 'pending'
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bid not available' USING ERRCODE = 'P0001';
    END IF;
    
    v_confirmation_code := substring(md5(random()::text), 1, 6);
    v_decision_time := EXTRACT(EPOCH FROM (NOW() - v_job.created_at))::INTEGER;
    
    UPDATE jobs SET
        bidding_status = 'locked',
        technician_id = v_bid.technician_id,
        proposed_price = v_bid.amount,
        final_price = v_bid.amount,
        accepted_bid_id = p_bid_id,
        confirmation_code = v_confirmation_code,
        status = 'accepted_by_tech',
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_job_id;
    
    UPDATE bidding_timers
    SET status = 'completed', updated_at = NOW()
    WHERE job_id = p_job_id;
    
    UPDATE bids
    SET status = 'accepted', updated_at = NOW()
    WHERE id = p_bid_id;
    
    UPDATE bids
    SET status = 'rejected', updated_at = NOW()
    WHERE job_id = p_job_id AND id != p_bid_id;
    
    INSERT INTO bid_waitlist (job_id, bid_id, technician_id, amount, rank, status)
    SELECT 
        job_id, id, technician_id, amount,
        ROW_NUMBER() OVER (ORDER BY amount ASC), 'waiting'
    FROM bids
    WHERE job_id = p_job_id AND status = 'rejected'
    ORDER BY amount ASC;
    
    INSERT INTO analytics_events (
        event_type, job_id, technician_id, customer_id,
        amount, total_bids, decision_time_seconds, wave_number
    ) VALUES (
        'bid_accepted', p_job_id, v_bid.technician_id, p_customer_id,
        v_bid.amount, (SELECT COUNT(*) FROM bids WHERE job_id = p_job_id),
        v_decision_time, v_job.current_wave
    );
    
    PERFORM pg_notify('bid_accepted', jsonb_build_object(
        'job_id', p_job_id,
        'technician_id', v_bid.technician_id,
        'amount', v_bid.amount,
        'customer_id', p_customer_id,
        'confirmation_code', v_confirmation_code
    )::text);
    
    RETURN jsonb_build_object(
        'success', true,
        'job_id', p_job_id,
        'technician_id', v_bid.technician_id,
        'amount', v_bid.amount,
        'confirmation_code', v_confirmation_code,
        'decision_time_seconds', v_decision_time
    );
END;
$$ LANGUAGE plpgsql;

-- Function 2: Process Expired Biddings
CREATE OR REPLACE FUNCTION process_expired_biddings()
RETURNS void AS $$
DECLARE
    v_job RECORD;
BEGIN
    FOR v_job IN
        SELECT j.id, j.customer_id, j.current_wave
        FROM jobs j
        JOIN bidding_timers bt ON j.id = bt.job_id
        WHERE j.bidding_status = 'open'
        AND bt.ends_at <= NOW()
        AND bt.status = 'running'
    LOOP
        UPDATE jobs SET
            bidding_status = 'expired',
            status = 'cancelled',
            updated_at = NOW()
        WHERE id = v_job.id;
        
        UPDATE bidding_timers 
        SET status = 'expired', updated_at = NOW() 
        WHERE job_id = v_job.id;
        
        UPDATE bids 
        SET status = 'expired', updated_at = NOW() 
        WHERE job_id = v_job.id AND status = 'pending';
        
        INSERT INTO analytics_events (
            event_type, job_id, customer_id, timestamp, wave_number
        ) VALUES (
            'bidding_expired', v_job.id, v_job.customer_id, NOW(), v_job.current_wave
        );
        
        PERFORM pg_notify('bidding_expired', jsonb_build_object(
            'job_id', v_job.id,
            'customer_id', v_job.customer_id,
            'can_reopen', true
        )::text);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule Function 2 (Requires pg_cron)
SELECT cron.schedule('process-expired-biddings', '* * * * *', 'SELECT process_expired_biddings()');

-- Function 3: Extend Bidding Timer
CREATE OR REPLACE FUNCTION extend_bidding_timer(
    p_job_id UUID,
    p_additional_minutes INTEGER DEFAULT 5
)
RETURNS void AS $$
BEGIN
    UPDATE bidding_timers SET
        ends_at = ends_at + (p_additional_minutes || ' minutes')::interval,
        extended_by_minutes = p_additional_minutes,
        extended_at = NOW(),
        status = 'extended',
        updated_at = NOW()
    WHERE job_id = p_job_id
    AND status = 'running'
    AND extended_by_minutes = 0;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cannot extend: already extended or expired' USING ERRCODE = 'P0001';
    END IF;
    
    INSERT INTO analytics_events (event_type, job_id, metadata)
    VALUES ('timer_extended', p_job_id, jsonb_build_object('additional_minutes', p_additional_minutes));
END;
$$ LANGUAGE plpgsql;

-- Function 4: Handle Technician Cancellation with Waitlist
CREATE OR REPLACE FUNCTION handle_technician_cancellation(
    p_job_id UUID,
    p_technician_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_job RECORD;
    v_waitlist RECORD;
    v_impact_score INTEGER;
BEGIN
    v_impact_score := CASE 
        WHEN p_reason = 'emergency' THEN -2
        WHEN p_reason = 'vehicle_breakdown' THEN -3
        WHEN p_reason = 'no_show' THEN -10
        ELSE -5
    END;
    
    INSERT INTO technician_cancellations (technician_id, job_id, reason, impact_score)
    VALUES (p_technician_id, p_job_id, p_reason, v_impact_score);
    
    UPDATE users SET
        cancelled_jobs = cancelled_jobs + 1,
        rating = GREATEST(1.0, rating + (v_impact_score::decimal / 100)),
        updated_at = NOW()
    WHERE id = p_technician_id;
    
    UPDATE jobs SET
        status = 'pending',
        bidding_status = 'open',
        technician_id = NULL,
        accepted_bid_id = NULL,
        confirmation_code = NULL,
        updated_at = NOW()
    WHERE id = p_job_id;
    
    SELECT * INTO v_waitlist 
    FROM bid_waitlist 
    WHERE job_id = p_job_id AND status = 'waiting'
    ORDER BY rank ASC, amount ASC
    LIMIT 1;
    
    IF FOUND THEN
        UPDATE bid_waitlist SET 
            status = 'offered',
            offered_at = NOW(),
            expires_at = NOW() + INTERVAL '5 minutes'
        WHERE id = v_waitlist.id;
        
        PERFORM pg_notify('waitlist_offer', jsonb_build_object(
            'job_id', p_job_id,
            'technician_id', v_waitlist.technician_id,
            'amount', v_waitlist.amount,
            'expires_at', v_waitlist.expires_at
        )::text);
        
        PERFORM pg_notify('technician_cancelled', jsonb_build_object(
            'job_id', p_job_id,
            'message', 'Searching for alternative technician',
            'alternative_available', true
        )::text);
        
        RETURN jsonb_build_object(
            'action', 'offered_to_waitlist',
            'technician_id', v_waitlist.technician_id,
            'amount', v_waitlist.amount,
            'expires_in_minutes', 5
        );
    ELSE
        PERFORM pg_notify('technician_cancelled', jsonb_build_object(
            'job_id', p_job_id,
            'message', 'Job reopened for new bids',
            'alternative_available', false
        )::text);
        
        RETURN jsonb_build_object(
            'action', 'reopened_for_bidding',
            'message', 'No waitlist available, job is open for new bids'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Process Waves
CREATE OR REPLACE FUNCTION process_job_waves()
RETURNS void AS $$
DECLARE
    v_job RECORD;
    v_nearby_technicians INTEGER;
BEGIN
    FOR v_job IN
        SELECT j.id, j.location, j.current_wave, j.wave_started_at, j.service_id
        FROM jobs j
        WHERE j.bidding_status = 'open'
        AND j.status = 'pending'
        AND j.created_at > NOW() - INTERVAL '30 minutes'
    LOOP
        CASE v_job.current_wave
            WHEN 1 THEN
                IF v_job.wave_started_at <= NOW() - INTERVAL '2 minutes' THEN
                    SELECT COUNT(*) INTO v_nearby_technicians
                    FROM bids WHERE job_id = v_job.id;
                    
                    IF v_nearby_technicians = 0 THEN
                        UPDATE jobs SET
                            current_wave = 2,
                            wave_started_at = NOW(),
                            updated_at = NOW()
                        WHERE id = v_job.id;
                        
                        PERFORM pg_notify('job_wave_2', jsonb_build_object(
                            'job_id', v_job.id,
                            'radius_km', 50,
                            'location', v_job.location::text
                        )::text);
                        
                        INSERT INTO analytics_events (event_type, job_id, wave_number)
                        VALUES ('wave_advanced', v_job.id, 2);
                    END IF;
                END IF;
                
            WHEN 2 THEN
                IF v_job.wave_started_at <= NOW() - INTERVAL '2 minutes' THEN
                    SELECT COUNT(*) INTO v_nearby_technicians
                    FROM bids WHERE job_id = v_job.id;
                    
                    IF v_nearby_technicians = 0 THEN
                        UPDATE jobs SET
                            current_wave = 3,
                            wave_started_at = NOW(),
                            updated_at = NOW()
                        WHERE id = v_job.id;
                        
                        PERFORM pg_notify('job_wave_3', jsonb_build_object(
                            'job_id', v_job.id,
                            'radius_km', 'all',
                            'location', v_job.location::text
                        )::text);
                        
                        INSERT INTO analytics_events (event_type, job_id, wave_number)
                        VALUES ('wave_advanced', v_job.id, 3);
                    END IF;
                END IF;
        END CASE;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule Function 5 (Requires pg_cron)
SELECT cron.schedule('process-job-waves', '*/30 * * * * *', 'SELECT process_job_waves()');

-- Function 6: Confirm Cash Payment
CREATE OR REPLACE FUNCTION confirm_cash_payment(
    p_job_id UUID,
    p_customer_id UUID,
    p_confirmation_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_job RECORD;
BEGIN
    SELECT * INTO v_job
    FROM jobs
    WHERE id = p_job_id
    AND customer_id = p_customer_id
    AND status = 'payment_pending'
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job not found or not in payment pending status' USING ERRCODE = 'P0001';
    END IF;
    
    IF v_job.confirmation_code != p_confirmation_code THEN
        RAISE EXCEPTION 'Invalid confirmation code' USING ERRCODE = 'P0001';
    END IF;
    
    UPDATE jobs SET
        is_paid = true,
        paid_at = NOW(),
        status = 'paid',
        updated_at = NOW()
    WHERE id = p_job_id;
    
    INSERT INTO analytics_events (
        event_type, job_id, customer_id, technician_id, amount
    ) VALUES (
        'payment_confirmed', p_job_id, p_customer_id, 
        v_job.technician_id, v_job.final_price
    );
    
    PERFORM pg_notify('payment_received', jsonb_build_object(
        'job_id', p_job_id,
        'technician_id', v_job.technician_id,
        'amount', v_job.final_price
    )::text);
    
    RETURN jsonb_build_object(
        'success', true,
        'job_id', p_job_id,
        'amount', v_job.final_price,
        'paid_at', NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Function 7: Create Dispute
CREATE OR REPLACE FUNCTION create_dispute(
    p_job_id UUID,
    p_raised_by UUID,
    p_dispute_type TEXT,
    p_description TEXT,
    p_evidence_urls TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_job RECORD;
    v_dispute_id UUID;
BEGIN
    SELECT * INTO v_job
    FROM jobs
    WHERE id = p_job_id
    AND (customer_id = p_raised_by OR technician_id = p_raised_by)
    AND status IN ('completed', 'payment_pending', 'paid');
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job not eligible for dispute' USING ERRCODE = 'P0001';
    END IF;
    
    IF EXISTS (SELECT 1 FROM disputes WHERE job_id = p_job_id) THEN
        RAISE EXCEPTION 'Dispute already exists for this job' USING ERRCODE = 'P0001';
    END IF;
    
    INSERT INTO disputes (
        job_id, raised_by, dispute_type, description, 
        evidence_photo_urls, status
    ) VALUES (
        p_job_id, p_raised_by, p_dispute_type, p_description,
        p_evidence_urls, 'open'
    )
    RETURNING id INTO v_dispute_id;
    
    UPDATE jobs SET
        status = 'disputed',
        updated_at = NOW()
    WHERE id = p_job_id;
    
    INSERT INTO analytics_events (
        event_type, job_id, customer_id, technician_id, metadata
    ) VALUES (
        'dispute_created', p_job_id, v_job.customer_id, 
        v_job.technician_id, jsonb_build_object('dispute_type', p_dispute_type)
    );
    
    PERFORM pg_notify('new_dispute', jsonb_build_object(
        'dispute_id', v_dispute_id,
        'job_id', p_job_id,
        'raised_by', p_raised_by,
        'type', p_dispute_type,
        'whatsapp_link', 'https://wa.me/SUPPORT_NUMBER?text=Dispute:' || v_dispute_id
    )::text);
    
    RETURN jsonb_build_object(
        'success', true,
        'dispute_id', v_dispute_id,
        'status', 'open',
        'support_contact', 'SUPPORT_WHATSAPP_NUMBER',
        'message', 'Support team will contact you via WhatsApp within 2 hours'
    );
END;
$$ LANGUAGE plpgsql;

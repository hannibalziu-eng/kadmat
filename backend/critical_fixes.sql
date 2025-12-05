-- ============================================
-- KADMAT BACKEND CRITICAL FIXES (FIXED ORDER)
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. ADD MISSING COLUMNS TO JOBS TABLE FIRST!
-- ============================================
DO $$ 
BEGIN
    -- Add price_notes column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'price_notes') THEN
        ALTER TABLE jobs ADD COLUMN price_notes TEXT;
    END IF;

    -- Add customer_offer column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'customer_offer') THEN
        ALTER TABLE jobs ADD COLUMN customer_offer DECIMAL(10, 2);
    END IF;

    -- Add price_confirmed_at column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'price_confirmed_at') THEN
        ALTER TABLE jobs ADD COLUMN price_confirmed_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Add customer_rating column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'customer_rating') THEN
        ALTER TABLE jobs ADD COLUMN customer_rating INT CHECK (customer_rating >= 1 AND customer_rating <= 5);
    END IF;

    -- Add customer_review column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'customer_review') THEN
        ALTER TABLE jobs ADD COLUMN customer_review TEXT;
    END IF;

    -- Add rated_at column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'rated_at') THEN
        ALTER TABLE jobs ADD COLUMN rated_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Add cancelled_by column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'cancelled_by') THEN
        ALTER TABLE jobs ADD COLUMN cancelled_by UUID REFERENCES users(id);
    END IF;

    -- Add cancel_reason column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'cancel_reason') THEN
        ALTER TABLE jobs ADD COLUMN cancel_reason TEXT;
    END IF;

    -- Add cancelled_at column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'jobs' AND column_name = 'cancelled_at') THEN
        ALTER TABLE jobs ADD COLUMN cancelled_at TIMESTAMP WITH TIME ZONE;
    END IF;

    RAISE NOTICE 'Jobs columns added successfully!';
END $$;

-- ============================================
-- 2. UPDATE JOBS STATUS CHECK CONSTRAINT
-- ============================================
DO $$
BEGIN
    -- Drop old constraint
    ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_status_check;
    
    -- Add new constraint with all statuses
    ALTER TABLE jobs ADD CONSTRAINT jobs_status_check 
        CHECK (status IN ('pending', 'accepted', 'price_pending', 'counter_offer', 'in_progress', 'completed', 'cancelled', 'no_technician_found'));
    
    RAISE NOTICE 'Status constraint updated!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not update status constraint: %', SQLERRM;
END $$;

-- ============================================
-- 3. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type VARCHAR(50) NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
    ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type 
    ON notifications(type);

-- RLS Policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
CREATE POLICY "Service role can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 4. FIND NEARBY TECHNICIANS FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION find_nearby_technicians(
    p_lat FLOAT,
    p_lng FLOAT,
    p_radius INT DEFAULT 5000,
    p_service_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    phone VARCHAR(20),
    rating DECIMAL(3,2),
    profile_image_url TEXT,
    distance_meters FLOAT
) 
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.full_name,
        u.phone,
        u.rating,
        u.profile_image_url,
        ST_Distance(
            u.location, 
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) as distance_meters
    FROM public.users u
    LEFT JOIN public.wallets w ON u.id = w.user_id
    WHERE 
        u.user_type = 'technician'
        AND u.is_online = TRUE
        AND (w.is_frozen IS NULL OR w.is_frozen = FALSE)
        AND u.location IS NOT NULL
        AND ST_DWithin(
            u.location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius
        )
    ORDER BY distance_meters ASC
    LIMIT 50;
END;
$$;

-- ============================================
-- 5. AUTO-UPDATE TECHNICIAN RATING TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION update_technician_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating DECIMAL(3,2);
    total_jobs INT;
BEGIN
    -- Only run for UPDATE events where customer_rating changed
    IF TG_OP = 'UPDATE' AND NEW.customer_rating IS NOT NULL THEN
        -- Calculate new average rating
        SELECT 
            COALESCE(AVG(customer_rating), 5.0),
            COUNT(*)
        INTO avg_rating, total_jobs
        FROM jobs
        WHERE technician_id = NEW.technician_id
        AND customer_rating IS NOT NULL;

        -- Update technician's rating
        UPDATE users
        SET rating = ROUND(avg_rating, 2)
        WHERE id = NEW.technician_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_job_rated ON jobs;

-- Create trigger (simple version without WHEN clause to avoid column issues)
CREATE TRIGGER on_job_rated
AFTER UPDATE ON jobs
FOR EACH ROW
EXECUTE FUNCTION update_technician_rating();

-- ============================================
-- 6. CREATE NOTIFICATION HELPER FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type VARCHAR(50),
    p_title TEXT,
    p_body TEXT DEFAULT NULL,
    p_data JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (p_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$;

-- ============================================
-- 7. JOB STATUS CHANGE NOTIFICATION TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION notify_job_status_change()
RETURNS TRIGGER AS $$
DECLARE
    notify_user_id UUID;
    notify_title TEXT;
    notify_body TEXT;
BEGIN
    -- Only process if status actually changed
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    -- Determine who to notify based on status change
    CASE NEW.status
        WHEN 'accepted' THEN
            notify_user_id := NEW.customer_id;
            notify_title := 'تم قبول طلبك! ✅';
            notify_body := 'فني قبل طلب الخدمة، سيقوم بتحديد السعر قريباً';
        WHEN 'price_pending' THEN
            notify_user_id := NEW.customer_id;
            notify_title := 'عرض سعر جديد 💰';
            notify_body := 'الفني حدد سعر ' || COALESCE(NEW.technician_price::text, '0') || ' ريال. راجع العرض الآن.';
        WHEN 'in_progress' THEN
            notify_user_id := NEW.technician_id;
            notify_title := 'العميل وافق! 🎉';
            notify_body := 'تم قبول السعر. توجه للعميل الآن.';
        WHEN 'completed' THEN
            notify_user_id := NEW.customer_id;
            notify_title := 'تمت الخدمة ✨';
            notify_body := 'قيّم تجربتك مع الفني';
        WHEN 'cancelled' THEN
            -- Notify the other party
            IF NEW.cancelled_by = NEW.customer_id THEN
                notify_user_id := NEW.technician_id;
            ELSE
                notify_user_id := NEW.customer_id;
            END IF;
            notify_title := 'تم إلغاء الطلب ❌';
            notify_body := COALESCE(NEW.cancel_reason, 'تم إلغاء الطلب');
        ELSE
            RETURN NEW;
    END CASE;

    -- Only notify if user_id is set
    IF notify_user_id IS NOT NULL THEN
        PERFORM create_notification(
            notify_user_id,
            'job_' || NEW.status,
            notify_title,
            notify_body,
            jsonb_build_object('job_id', NEW.id, 'status', NEW.status)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS on_job_status_change ON jobs;
CREATE TRIGGER on_job_status_change
AFTER UPDATE ON jobs
FOR EACH ROW
EXECUTE FUNCTION notify_job_status_change();

-- ============================================
-- 8. PERFORMANCE INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_customer ON jobs(customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_technician ON jobs(technician_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_pending ON jobs(status, created_at DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_users_technician_online ON users(user_type, is_online) WHERE user_type = 'technician';

-- ============================================
-- DONE! ✅
-- ============================================
SELECT 'All critical fixes applied successfully! ✅' as result;

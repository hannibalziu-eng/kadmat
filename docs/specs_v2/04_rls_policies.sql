-- Kadmat V2 RLS Policies
-- SECURITY IS MANDATORY: Enable RLS on all tables

-- 1. Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE bid_waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE technician_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 2. User Policies
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Public can view technician profiles" ON users
    FOR SELECT USING (user_type = 'technician');

-- 3. Service Policies
CREATE POLICY "Public read services" ON services
    FOR SELECT USING (true);

-- 4. Job Policies
-- Customer can see own jobs
CREATE POLICY "Customer view own jobs" ON jobs
    FOR SELECT USING (auth.uid() = customer_id);

-- Customer can create jobs
CREATE POLICY "Customer create jobs" ON jobs
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Customer can update own 'pending' jobs
CREATE POLICY "Customer update own jobs" ON jobs
    FOR UPDATE USING (auth.uid() = customer_id);

-- Technicians can see available jobs based on WAVES logic and location
-- Wave 1: 15km
-- Wave 2: 50km
-- Wave 3: Unlimited
CREATE POLICY "Technician view open jobs" ON jobs
    FOR SELECT USING (
        (
          status = 'pending' AND bidding_status = 'open'
          AND (
            (current_wave = 1 AND ST_DWithin(location, (SELECT current_location FROM users WHERE id = auth.uid()), 15000)) OR
            (current_wave = 2 AND ST_DWithin(location, (SELECT current_location FROM users WHERE id = auth.uid()), 50000)) OR
            (current_wave >= 3)
          )
        ) 
        OR 
        (technician_id = auth.uid())
    );

-- 5. Bid Policies
-- Technician can see/edit own bids
CREATE POLICY "Technician manage own bids" ON bids
    FOR ALL USING (auth.uid() = technician_id);

-- Customer can see bids on their jobs
CREATE POLICY "Customer view bids on their jobs" ON bids
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM jobs 
            WHERE jobs.id = bids.job_id 
            AND jobs.customer_id = auth.uid()
        )
    );

-- 6. Dispute Policies
CREATE POLICY "Users view their disputes" ON disputes
    FOR SELECT USING (
        auth.uid() = raised_by 
        OR 
        EXISTS (
            SELECT 1 FROM jobs 
            WHERE jobs.id = disputes.job_id 
            AND (jobs.customer_id = auth.uid() OR jobs.technician_id = auth.uid())
        )
    );

CREATE POLICY "Users create disputes" ON disputes
    FOR INSERT WITH CHECK (auth.uid() = raised_by);

-- 7. Notification Policies
CREATE POLICY "Users view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- ==============================================================================
-- KADMAT SCHEMA V2 (Medusa-Inspired Architecture)
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==============================================================================
-- 1. ENUMS & TYPES (For strict state management)
-- ==============================================================================

-- Job Status: The high-level state of the job
DO $$ BEGIN
    CREATE TYPE job_status_enum AS ENUM (
        'pending',              -- Created, waiting for technician
        'searching',            -- System is actively searching
        'accepted',             -- Technician assigned
        'price_pending',        -- Technician proposed price
        'customer_review',      -- Customer reviewing price (optional step)
        'in_progress',          -- Work started
        'completed',            -- Work finished
        'cancelled',            -- Cancelled by either party
        'no_technician_found'   -- Search exhausted
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Payment Status: Tracks the money flow (Medusa style)
DO $$ BEGIN
    CREATE TYPE payment_status_enum AS ENUM (
        'not_paid',
        'awaiting',
        'captured',
        'refunded',
        'partially_refunded'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Transaction Type: For clear financial audit trails
DO $$ BEGIN
    CREATE TYPE transaction_type_enum AS ENUM (
        'deposit',
        'withdrawal',
        'job_payment',
        'commission',
        'penalty',
        'refund',
        'adjustment'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==============================================================================
-- 2. TABLES
-- ==============================================================================

-- USERS (Enhanced)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(255),
    profile_image_url TEXT,
    user_type VARCHAR(20) DEFAULT 'customer', -- 'customer', 'technician', 'admin'
    rating DECIMAL(3, 2) DEFAULT 5.0,
    is_online BOOLEAN DEFAULT FALSE,
    location GEOGRAPHY(POINT),
    metadata JSONB DEFAULT '{}', -- For flexible extra data (Medusa style)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- WALLETS (Enhanced with blocked balance)
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    balance DECIMAL(10, 2) DEFAULT 0.00 CHECK (balance >= 0),
    blocked_balance DECIMAL(10, 2) DEFAULT 0.00 CHECK (blocked_balance >= 0), -- Funds held for active jobs
    currency VARCHAR(3) DEFAULT 'SAR',
    is_frozen BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- SERVICES (Catalog)
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    description TEXT,
    base_price DECIMAL(10, 2) DEFAULT 0.00,
    commission_rate DECIMAL(5, 4) DEFAULT 0.10, -- 0.10 = 10%
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- JOBS (The Order Entity)
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    display_id SERIAL, -- Human readable ID (e.g., #1024)
    
    -- Relations
    customer_id UUID REFERENCES public.users(id) NOT NULL,
    technician_id UUID REFERENCES public.users(id),
    service_id UUID REFERENCES public.services(id) NOT NULL,
    
    -- Statuses
    status job_status_enum DEFAULT 'pending',
    payment_status payment_status_enum DEFAULT 'not_paid',
    
    -- Location
    location GEOGRAPHY(POINT),
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    address_text TEXT,
    
    -- Details
    description TEXT,
    initial_price DECIMAL(10, 2), -- Estimated price
    technician_price DECIMAL(10, 2), -- Price proposed by tech
    final_price DECIMAL(10, 2), -- Final agreed price
    
    -- Search & Allocation
    search_radius INT DEFAULT 2000,
    search_data JSONB DEFAULT '{}', -- Store search tier info here
    
    -- Cancellation
    cancelled_by UUID REFERENCES public.users(id),
    cancel_reason TEXT,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- Rating
    customer_rating INT CHECK (customer_rating BETWEEN 1 AND 5),
    customer_review TEXT,
    rated_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata (Medusa style extension)
    metadata JSONB DEFAULT '{}'
);

-- WALLET TRANSACTIONS (The Ledger)
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES public.wallets(id) NOT NULL,
    
    -- Transaction Details
    amount DECIMAL(10, 2) NOT NULL, -- Positive = Credit, Negative = Debit
    type transaction_type_enum NOT NULL,
    status VARCHAR(20) DEFAULT 'completed', -- pending, completed, failed
    
    -- Polymorphic Reference (What is this transaction for?)
    reference_type VARCHAR(50), -- 'job', 'refund', 'admin_adjustment'
    reference_id UUID,          -- job_id, etc.
    
    description TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'job_offer', 'job_accepted', etc.
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- 3. INDEXES (Performance)
-- ==============================================================================

-- Jobs
CREATE INDEX IF NOT EXISTS idx_jobs_customer ON jobs(customer_id);
CREATE INDEX IF NOT EXISTS idx_jobs_technician ON jobs(technician_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_location ON jobs USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);

-- Users
CREATE INDEX IF NOT EXISTS idx_users_technician_location ON users USING GIST(location) WHERE user_type = 'technician';
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Transactions
CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON wallet_transactions(reference_id);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id) WHERE is_read = FALSE;

-- ==============================================================================
-- 4. ATOMIC FUNCTIONS (The "Bank" Logic)
-- ==============================================================================

-- Function to safely transfer money (Atomic Transaction)
CREATE OR REPLACE FUNCTION process_job_payment(
    p_job_id UUID,
    p_amount DECIMAL,
    p_commission_rate DECIMAL DEFAULT 0.10
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_job jobs%ROWTYPE;
    v_customer_wallet_id UUID;
    v_technician_wallet_id UUID;
    v_commission_amount DECIMAL;
    v_technician_amount DECIMAL;
BEGIN
    -- 1. Lock the job row
    SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Job not found');
    END IF;
    
    IF v_job.payment_status = 'captured' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Payment already processed');
    END IF;

    -- 2. Get Wallets
    SELECT id INTO v_customer_wallet_id FROM wallets WHERE user_id = v_job.customer_id;
    SELECT id INTO v_technician_wallet_id FROM wallets WHERE user_id = v_job.technician_id;
    
    -- 3. Calculate Amounts
    v_commission_amount := p_amount * p_commission_rate;
    v_technician_amount := p_amount - v_commission_amount;
    
    -- 4. Perform Transfers (Debit Customer, Credit Tech)
    -- Note: In a real app, customer might have pre-authorized card payment. 
    -- Here we assume wallet balance or cash recording.
    
    -- Credit Technician
    UPDATE wallets 
    SET balance = balance + v_technician_amount, updated_at = NOW()
    WHERE id = v_technician_wallet_id;
    
    INSERT INTO wallet_transactions (wallet_id, amount, type, reference_type, reference_id, description)
    VALUES (v_technician_wallet_id, v_technician_amount, 'job_payment', 'job', p_job_id, 'Payment for job');
    
    -- Record Commission (Platform Revenue)
    -- We could have a platform wallet, but for now just logging it via the job or a system wallet.
    
    -- 5. Update Job Status
    UPDATE jobs 
    SET payment_status = 'captured',
        final_price = p_amount,
        updated_at = NOW()
    WHERE id = p_job_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Payment processed successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ==============================================================================
-- 5. RLS POLICIES (Security)
-- ==============================================================================

ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Jobs Policies
CREATE POLICY "Users can view own jobs" ON jobs
    FOR SELECT USING (auth.uid() = customer_id OR auth.uid() = technician_id);

CREATE POLICY "Customers can create jobs" ON jobs
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Users can update own jobs" ON jobs
    FOR UPDATE USING (auth.uid() = customer_id OR auth.uid() = technician_id);

-- Wallet Policies
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own transactions" ON wallet_transactions
    FOR SELECT USING (wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid()));

-- Notification Policies
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- ==============================================================================
-- 6. TRIGGERS
-- ==============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_wallets_updated_at BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- Kadmat Database Schema v2.0 (Cash Only)

-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Enums
CREATE TYPE job_status AS ENUM (
    'pending', 'accepted_by_tech', 'price_sent', 'customer_agreed',
    'in_progress', 'completed', 'payment_pending', 'paid', 'reviewed',
    'cancelled', 'cancelled_by_customer', 'cancelled_by_technician', 'disputed'
);

CREATE TYPE bidding_status AS ENUM ('open', 'locked', 'completed', 'cancelled', 'expired', 'reopened');
CREATE TYPE bid_status AS ENUM ('pending', 'accepted', 'rejected', 'expired', 'withdrawn', 'waiting', 'offered');
CREATE TYPE timer_status AS ENUM ('running', 'extended', 'expired', 'completed');
CREATE TYPE payment_method AS ENUM ('cash', 'card', 'wallet');
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved_customer_favor', 'resolved_technician_favor', 'compromise', 'closed');
CREATE TYPE cancellation_reason AS ENUM ('customer_changed_mind', 'customer_not_available', 'technician_emergency', 'technician_no_show', 'technician_late', 'price_disagreement', 'other');

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    user_type TEXT NOT NULL CHECK (user_type IN ('customer', 'technician', 'admin')),
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT false,
    rating DECIMAL(2,1) DEFAULT 5.0 CHECK (rating >= 1 AND rating <= 5),
    completed_jobs INTEGER DEFAULT 0,
    cancelled_jobs INTEGER DEFAULT 0,
    response_time_minutes INTEGER DEFAULT 0,
    service_radius_km INTEGER DEFAULT 15,
    current_location GEOGRAPHY(POINT, 4326),
    is_online BOOLEAN DEFAULT false,
    last_online_at TIMESTAMPTZ,
    fcm_token TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_location ON users USING GIST(current_location) WHERE user_type = 'technician';
CREATE INDEX IF NOT EXISTS idx_users_online ON users(is_online, last_online_at) WHERE user_type = 'technician';

-- Services Table
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_ar TEXT NOT NULL,
    name_en TEXT NOT NULL,
    icon_url TEXT,
    base_price DECIMAL(10,2),
    estimated_duration_minutes INTEGER,
    category TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Jobs Table (الطلبات)
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    address TEXT NOT NULL,
    address_details TEXT,
    description TEXT NOT NULL,
    max_budget DECIMAL(10,2),
    preferred_time TIMESTAMPTZ,
    status job_status DEFAULT 'pending',
    bidding_status bidding_status DEFAULT 'open',
    accepted_bid_id UUID,
    technician_id UUID REFERENCES users(id),
    proposed_price DECIMAL(10,2),
    final_price DECIMAL(10,2),
    additional_cost DECIMAL(10,2) DEFAULT 0,
    payment_method payment_method DEFAULT 'cash',
    confirmation_code TEXT,
    is_paid BOOLEAN DEFAULT false,
    paid_at TIMESTAMPTZ,
    current_wave INTEGER DEFAULT 1,
    wave_started_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    cancellation_reason cancellation_reason,
    cancelled_by UUID REFERENCES users(id),
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_budget CHECK (max_budget IS NULL OR max_budget > 0)
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_jobs_location ON jobs USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_jobs_bidding ON jobs(bidding_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_customer ON jobs(customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_technician ON jobs(technician_id, status);

-- Bids Table (العروض)
CREATE TABLE IF NOT EXISTS bids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    notes TEXT,
    estimated_duration_minutes INTEGER CHECK (estimated_duration_minutes > 0),
    availability_days INTEGER[],
    status bid_status DEFAULT 'pending',
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(job_id, technician_id)
);

-- Add missing FK constraint for jobs.accepted_bid_id if not circular definition
-- ALTER TABLE jobs ADD CONSTRAINT fk_jobs_accepted_bid FOREIGN KEY (accepted_bid_id) REFERENCES bids(id); -- Circular dependency handling usually done after both tables created

CREATE INDEX IF NOT EXISTS idx_bids_job ON bids(job_id, status);
CREATE INDEX IF NOT EXISTS idx_bids_technician ON bids(technician_id, submitted_at DESC);

-- Bid Waitlist (قائمة الانتظار)
CREATE TABLE IF NOT EXISTS bid_waitlist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    bid_id UUID NOT NULL REFERENCES bids(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    rank INTEGER NOT NULL,
    status TEXT DEFAULT 'waiting',
    offered_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(job_id, technician_id)
);

CREATE INDEX IF NOT EXISTS idx_waitlist_job ON bid_waitlist(job_id, status, rank);
CREATE INDEX IF NOT EXISTS idx_waitlist_technician ON bid_waitlist(technician_id, status);

-- Bidding Timers
CREATE TABLE IF NOT EXISTS bidding_timers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ends_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 15,
    extended_by_minutes INTEGER DEFAULT 0,
    extended_at TIMESTAMPTZ,
    status timer_status DEFAULT 'running',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT single_extension CHECK (extended_by_minutes <= 15)
);

CREATE INDEX IF NOT EXISTS idx_timers_ends_at ON bidding_timers(ends_at) WHERE status = 'running';

-- Job Checkins
CREATE TABLE IF NOT EXISTS job_checkins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES users(id),
    checkin_type TEXT NOT NULL CHECK (checkin_type IN ('arrived', 'started', 'completed')),
    location GEOGRAPHY(POINT, 4326),
    photo_urls TEXT[],
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_checkins_job ON job_checkins(job_id, checkin_type);

-- Job Photos
CREATE TABLE IF NOT EXISTS job_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    photo_type TEXT NOT NULL CHECK (photo_type IN ('before', 'after', 'additional_work', 'dispute_evidence')),
    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_photos_job ON job_photos(job_id, photo_type);

-- Disputes (النزاعات)
CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE CASCADE,
    raised_by UUID NOT NULL REFERENCES users(id),
    dispute_type TEXT NOT NULL CHECK (dispute_type IN ('payment_refused', 'quality_issue', 'incomplete_work', 'additional_charges_dispute', 'technician_no_show', 'customer_absent', 'other')),
    description TEXT NOT NULL,
    evidence_photo_urls TEXT[],
    status dispute_status DEFAULT 'open',
    support_notes TEXT,
    resolution_type TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    refund_amount DECIMAL(10,2),
    compensation_amount DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status, created_at);

-- Technician Cancellations
CREATE TABLE IF NOT EXISTS technician_cancellations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_id UUID NOT NULL REFERENCES users(id),
    job_id UUID NOT NULL REFERENCES jobs(id),
    reason TEXT NOT NULL,
    impact_score INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cancellations_technician ON technician_cancellations(technician_id, created_at);

-- Analytics Events
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,
    job_id UUID REFERENCES jobs(id),
    technician_id UUID REFERENCES users(id),
    customer_id UUID REFERENCES users(id),
    amount DECIMAL(10,2),
    total_bids INTEGER,
    decision_time_seconds INTEGER,
    wave_number INTEGER,
    service_type TEXT,
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analytics_type_time ON analytics_events(event_type, timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_job ON analytics_events(job_id);

-- Notifications Table (Added in v2 refinements)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    priority TEXT DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

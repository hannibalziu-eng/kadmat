-- Add indexes to improve query performance

-- Index for technician's jobs (My Jobs)
CREATE INDEX IF NOT EXISTS idx_jobs_technician_id ON jobs(technician_id);

-- Index for customer's jobs (My Requests)
CREATE INDEX IF NOT EXISTS idx_jobs_customer_id ON jobs(customer_id);

-- Index for job status (Filtering)
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);

-- Index for location (Geospatial queries)
CREATE INDEX IF NOT EXISTS idx_jobs_location ON jobs USING GIST (location);

-- Index for notifications (My Notifications)
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

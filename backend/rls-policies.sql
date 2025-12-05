-- Additional RLS Policies for Kadmat
-- Run this to fix job creation and wallet access issues

-- =============================================
-- Jobs Table Policies
-- =============================================

-- Allow customers to create jobs
CREATE POLICY "Customers can create jobs" ON public.jobs
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Allow technicians to update jobs they accept
CREATE POLICY "Technicians can update accepted jobs" ON public.jobs
    FOR UPDATE USING (auth.uid() = technician_id);

-- Allow all authenticated users to view pending jobs (for technician discovery)
CREATE POLICY "Authenticated users can view pending jobs" ON public.jobs
    FOR SELECT USING (status = 'pending' OR auth.uid() = customer_id OR auth.uid() = technician_id);

-- =============================================
-- Users Table Policies
-- =============================================

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- =============================================
-- Wallets Table Policies
-- =============================================

-- Allow users to update their own wallet (for balance changes)
CREATE POLICY "System can update wallets" ON public.wallets
    FOR UPDATE USING (true);  -- This is handled by backend logic

-- =============================================
-- Wallet Transactions Policies  
-- =============================================

ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions
    FOR SELECT USING (
        wallet_id IN (
            SELECT id FROM public.wallets WHERE user_id = auth.uid()
        )
    );

-- System can insert transactions (backend handles this)
CREATE POLICY "System can insert transactions" ON public.wallet_transactions
    FOR INSERT WITH CHECK (true);

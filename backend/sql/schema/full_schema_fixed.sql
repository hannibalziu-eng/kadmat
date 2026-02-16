-- =============================================
-- 1. تهيئة الإضافات (Extensions)
-- =============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 2. الجداول الأساسية (Tables)
-- =============================================

-- جدول المستخدمين
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(255),
    profile_image_url TEXT,
    address TEXT,
    location GEOGRAPHY(POINT),
    user_type VARCHAR(20) DEFAULT 'customer',
    rating DECIMAL(3, 2) DEFAULT 5.0,
    is_online BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول المحفظة
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'SAR',
    is_frozen BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول حركات المحفظة
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES public.wallets(id),
    amount DECIMAL(10, 2) NOT NULL,
    type VARCHAR(20) CHECK (type IN ('deposit', 'withdrawal', 'commission', 'payment', 'penalty')),
    description TEXT,
    reference_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول الخدمات
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    base_price DECIMAL(10, 2) NOT NULL,
    commission_rate DECIMAL(4, 2) DEFAULT 0.10,
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- جدول الطلبات
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES public.users(id),
    technician_id UUID REFERENCES public.users(id),
    service_id UUID REFERENCES public.services(id),
    status VARCHAR(20) DEFAULT 'pending',
    location GEOGRAPHY(POINT),
    address_text TEXT,
    initial_price DECIMAL(10, 2),
    final_price DECIMAL(10, 2),
    technician_price DECIMAL(10, 2),
    description TEXT,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- =============================================
-- 3. الدوال المنطقية (Functions & Triggers)
-- =============================================

-- أ) دالة إنشاء مستخدم ومحفظة تلقائياً
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, phone, full_name, user_type)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'full_name',
    COALESCE(new.raw_user_meta_data->>'user_type', 'customer')
  );
  
  INSERT INTO public.wallets (user_id) VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- تفعيل التريجر (حذف القديم أولاً لتجنب التكرار)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- ب) دالة البحث عن الفنيين
CREATE OR REPLACE FUNCTION get_nearby_technicians(
  lat float, 
  long float, 
  radius_meters int,
  service_type uuid DEFAULT NULL
)
RETURNS TABLE (
  id UUID, 
  full_name text, 
  profile_image_url text,
  dist_meters float, 
  rating decimal,
  is_online boolean
) 
LANGUAGE sql
AS $$
  SELECT 
    u.id, 
    u.full_name,
    u.profile_image_url,
    ST_Distance(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography) as dist_meters,
    u.rating,
    u.is_online
  FROM public.users u
  JOIN public.wallets w ON u.id = w.user_id
  WHERE 
    u.user_type = 'technician'
    AND u.is_online = TRUE
    AND w.is_frozen = FALSE
    AND ST_DWithin(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography, radius_meters)
  ORDER BY dist_meters ASC
  LIMIT 20;
$$;

-- ج) دالة خصم العمولة
CREATE OR REPLACE FUNCTION process_job_payment(
    job_id UUID, 
    tech_id UUID, 
    amount DECIMAL
)
RETURNS void AS $$
DECLARE
    commission_amount DECIMAL;
    service_commission_rate DECIMAL;
BEGIN
    SELECT s.commission_rate INTO service_commission_rate
    FROM public.jobs j
    JOIN public.services s ON j.service_id = s.id
    WHERE j.id = job_id;

    commission_amount := amount * service_commission_rate;

    UPDATE public.wallets
    SET balance = balance - commission_amount,
        updated_at = NOW()
    WHERE user_id = tech_id;

    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, reference_id)
    SELECT id, -commission_amount, 'commission', 'خصم عمولة الطلب', job_id
    FROM public.wallets WHERE user_id = tech_id;
    
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. سياسات الأمان (RLS) - النسخة المصححة ✅
-- =============================================

-- تفعيل RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة لتجنب التعارض
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Anyone can view technicians" ON public.users;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Users can view own jobs" ON public.jobs;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users;
DROP POLICY IF EXISTS "Enable insert for service role" ON public.users;

-- --- سياسات Users ---
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Anyone can view technicians" ON public.users
    FOR SELECT USING (user_type = 'technician');

-- (هام جداً) السماح بالإضافة عند التسجيل
CREATE POLICY "Enable insert for authenticated users only" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Enable insert for service role" ON public.users
    FOR INSERT TO service_role WITH CHECK (true);

-- السماح بالتعديل (تحديث الملف الشخصي)
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- --- سياسات Wallets ---
CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

-- السماح للنظام بإنشاء المحفظة
CREATE POLICY "System can insert wallet" ON public.wallets
    FOR INSERT WITH CHECK (true);

-- --- سياسات Jobs ---
CREATE POLICY "Users can view own jobs" ON public.jobs
    FOR SELECT USING (
        auth.uid() = customer_id OR 
        auth.uid() = technician_id
    );

CREATE POLICY "Customers can create jobs" ON public.jobs
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Technicians can update accepted jobs" ON public.jobs
    FOR UPDATE USING (auth.uid() = technician_id);

-- --- سياسات Transactions ---
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions
    FOR SELECT USING (
        wallet_id IN (SELECT id FROM public.wallets WHERE user_id = auth.uid())
    );

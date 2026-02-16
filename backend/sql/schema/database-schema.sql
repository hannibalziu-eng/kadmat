-- =============================================
-- 1. تهيئة الإضافات (Extensions)
-- =============================================
-- لتوليد المعرفات الفريدة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- للخرائط والحسابات الجغرافية (الجندي المجهول!)
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 2. الجداول الأساسية (Tables)
-- =============================================

-- جدول المستخدمين (يربط مع Supabase Auth)
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(255),
    profile_image_url TEXT,
    address TEXT,
    location GEOGRAPHY(POINT), -- موقع المستخدم (للفنيين والعملاء)
    user_type VARCHAR(20) DEFAULT 'customer', -- customer, technician
    rating DECIMAL(3, 2) DEFAULT 5.0, -- التقييم من 5
    is_online BOOLEAN DEFAULT FALSE, -- حالة الفني (متصل/غير متصل)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول المحفظة (Wallet)
CREATE TABLE public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    balance DECIMAL(10, 2) DEFAULT 0.00, -- الرصيد (يمكن أن يكون سالب للفني)
    currency VARCHAR(3) DEFAULT 'SAR',
    is_frozen BOOLEAN DEFAULT FALSE, -- تجميد المحفظة إذا زادت المديونية
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول حركات المحفظة (Transactions)
CREATE TABLE public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES public.wallets(id),
    amount DECIMAL(10, 2) NOT NULL, -- موجب للإيداع، سالب للخصم
    type VARCHAR(20) CHECK (type IN ('deposit', 'withdrawal', 'commission', 'payment', 'penalty')),
    description TEXT,
    reference_id UUID, -- رقم الطلب المرتبط (اختياري)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- جدول الخدمات (Services)
CREATE TABLE public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255), -- الاسم بالعربي
    base_price DECIMAL(10, 2) NOT NULL, -- السعر المبدئي
    commission_rate DECIMAL(4, 2) DEFAULT 0.10, -- نسبة العمولة (0.10 = 10%)
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- جدول الطلبات (Jobs)
CREATE TABLE public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES public.users(id),
    technician_id UUID REFERENCES public.users(id),
    service_id UUID REFERENCES public.services(id),
    status VARCHAR(20) DEFAULT 'pending', -- pending, offered, accepted, in_progress, completed, cancelled
    
    -- الموقع
    location GEOGRAPHY(POINT),
    address_text TEXT,
    
    -- التفاصيل المالية
    initial_price DECIMAL(10, 2), -- السعر التقديري
    final_price DECIMAL(10, 2), -- السعر النهائي
    technician_price DECIMAL(10, 2), -- عرض الفني (إن وجد)
    
    description TEXT,
    scheduled_time TIMESTAMP WITH TIME ZONE, -- لوقت لاحق (اختياري)
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- =============================================
-- 3. الدوال المنطقية (Functions & Triggers)
-- =============================================

-- أ) دالة إنشاء مستخدم ومحفظة تلقائياً عند التسجيل
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
  
  -- إنشاء محفظة فارغة
  INSERT INTO public.wallets (user_id) VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- تفعيل التريجر
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- ب) دالة البحث عن الفنيين (الأسرع والأذكى!)
CREATE OR REPLACE FUNCTION get_nearby_technicians(
  lat float, 
  long float, 
  radius_meters int,
  service_type uuid DEFAULT NULL -- اختياري: تصفية حسب الخدمة
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
    AND u.is_online = TRUE -- فقط المتصلين
    AND w.is_frozen = FALSE -- فقط من لديهم رصيد يسمح
    AND ST_DWithin(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography, radius_meters)
  ORDER BY dist_meters ASC
  LIMIT 20; -- أقرب 20 فني فقط
$$;

-- ج) دالة خصم العمولة الآمنة (Atomic Transaction)
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
    -- 1. الحصول على نسبة العمولة للخدمة
    SELECT s.commission_rate INTO service_commission_rate
    FROM public.jobs j
    JOIN public.services s ON j.service_id = s.id
    WHERE j.id = job_id;

    -- 2. حساب العمولة
    commission_amount := amount * service_commission_rate;

    -- 3. خصم العمولة من محفظة الفني
    UPDATE public.wallets
    SET balance = balance - commission_amount,
        updated_at = NOW()
    WHERE user_id = tech_id;

    -- 4. تسجيل العملية
    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, reference_id)
    SELECT id, -commission_amount, 'commission', 'خصم عمولة الطلب', job_id
    FROM public.wallets WHERE user_id = tech_id;
    
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. سياسات الأمان (RLS - Row Level Security)
-- =============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- المستخدم يرى بياناته فقط
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- الجميع يرى الفنيين (للبحث)
CREATE POLICY "Anyone can view technicians" ON public.users
    FOR SELECT USING (user_type = 'technician');

-- المحفظة: المالك فقط يراها
CREATE POLICY "Users can view own wallet" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

-- الطلبات: العميل والفني فقط يرونها
CREATE POLICY "Users can view own jobs" ON public.jobs
    FOR SELECT USING (
        auth.uid() = customer_id OR 
        auth.uid() = technician_id
    );

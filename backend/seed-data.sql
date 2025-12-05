-- =============================================
-- Seed Data for Kadmat Application
-- Run this after database-schema.sql
-- =============================================

-- Insert Services with Arabic names
INSERT INTO public.services (id, name, name_ar, base_price, commission_rate, is_active) VALUES
  (uuid_generate_v4(), 'electrical_repair', 'إصلاح كهربائي', 100.00, 0.10, true),
  (uuid_generate_v4(), 'plumbing_repair', 'إصلاح سباكة', 120.00, 0.10, true),
  (uuid_generate_v4(), 'ac_maintenance', 'صيانة تكييف', 150.00, 0.12, true),
  (uuid_generate_v4(), 'carpentry', 'نجارة', 90.00, 0.10, true),
  (uuid_generate_v4(), 'painting', 'صباغة', 80.00, 0.10, true),
  (uuid_generate_v4(), 'cleaning', 'تنظيف', 70.00, 0.08, true),
  (uuid_generate_v4(), 'appliance_repair', 'تصليح أجهزة', 110.00, 0.10, true)
ON CONFLICT (id) DO NOTHING;

-- Verify services were inserted
SELECT COUNT(*) as service_count FROM public.services;

-- Display all services
SELECT id, name, name_ar, base_price, commission_rate FROM public.services;

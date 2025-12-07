-- Add service_id to users table to link technicians to their trade
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.services(id);

-- Update the handle_new_user function to map service_id from metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, phone, full_name, user_type, service_id)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'full_name',
    COALESCE(new.raw_user_meta_data->>'user_type', 'customer'),
    (new.raw_user_meta_data->>'service_id')::uuid -- Cast to UUID if present
  );
  
  INSERT INTO public.wallets (user_id) VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

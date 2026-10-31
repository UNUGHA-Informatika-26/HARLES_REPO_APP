-- ============================================================
-- HARLES JUJUG — SUPABASE DATABASE SCHEMA & CONFIGURATION
-- ============================================================
-- Petunjuk:
-- Salin seluruh isi script ini dan jalankan di SQL Editor Supabase Anda.
-- ============================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CUSTOM TYPES / ENUMS
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('customer', 'driver', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('pending', 'assigned', 'in_progress', 'completed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. PROFILES TABLE (Terkoneksi langsung dengan Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role user_role NOT NULL DEFAULT 'customer',
    avatar_url TEXT,
    wallet_balance BIGINT NOT NULL DEFAULT 150000,
    -- Khusus driver
    is_online BOOLEAN NOT NULL DEFAULT false,
    vehicle_plate TEXT,
    vehicle_type TEXT, -- contoh: 'Honda Beat', 'Yamaha NMAX'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index untuk performa pencarian
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- 4. ORDERS TABLE (Data Pesanan Layanan)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL, -- 'ride', 'car', 'express', 'food', 'mart', dll.
    status order_status NOT NULL DEFAULT 'pending',
    pickup_address TEXT NOT NULL,
    dropoff_address TEXT NOT NULL,
    item_notes TEXT,
    total_price BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index untuk filter orderan
CREATE INDEX IF NOT EXISTS idx_orders_customer ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_driver ON public.orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);

-- Pastikan seluruh kolom di profiles selalu ada (jika tabel sudah pernah dibuat sebelumnya)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS vehicle_plate TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS vehicle_type TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wallet_balance BIGINT NOT NULL DEFAULT 150000;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT false;

-- Pastikan seluruh kolom rincian transaksi & bagi hasil di orders selalu ada
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS service_code TEXT DEFAULT 'JPS MTR';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS outlet_cost BIGINT NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS parking_fee BIGINT NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_fee BIGINT NOT NULL DEFAULT 8000;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS admin_fee BIGINT NOT NULL DEFAULT 500;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS extra_fee BIGINT NOT NULL DEFAULT 0;

-- 5. FUNCTION & TRIGGER: Auto-Create Profile saat User Register di auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
    default_role public.user_role := 'customer';
    raw_role text;
BEGIN
    raw_role := new.raw_user_meta_data->>'role';
    IF raw_role = 'driver' THEN
        default_role := 'driver'::public.user_role;
    ELSIF raw_role = 'admin' THEN
        default_role := 'admin'::public.user_role;
    ELSE
        default_role := 'customer'::public.user_role;
    END IF;

    INSERT INTO public.profiles (
        id,
        full_name,
        phone,
        email,
        role,
        vehicle_type,
        vehicle_plate,
        is_online,
        created_at,
        updated_at
    ) VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', 'Pengguna Harles'),
        new.raw_user_meta_data->>'phone',
        new.email,
        default_role,
        new.raw_user_meta_data->>'vehicle_type',
        new.raw_user_meta_data->>'vehicle_plate',
        false,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        vehicle_type = EXCLUDED.vehicle_type,
        vehicle_plate = EXCLUDED.vehicle_plate;

    RETURN new;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in handle_new_user: %', SQLERRM;
        RETURN new;
END;
$$;

-- Pasang trigger ke auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. TRIGGER: Auto-Update Timestamp updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 7. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Kebijakan Profiles
DROP POLICY IF EXISTS "Public profiles read" ON public.profiles;
CREATE POLICY "Public profiles read" ON public.profiles
    FOR SELECT USING (true); -- Memungkinkan customer melihat info driver & sebaliknya

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Kebijakan Orders
DROP POLICY IF EXISTS "Customer can create orders" ON public.orders;
CREATE POLICY "Customer can create orders" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Users can view relevant orders" ON public.orders;
CREATE POLICY "Users can view relevant orders" ON public.orders
    FOR SELECT USING (
        auth.uid() = customer_id OR 
        auth.uid() = driver_id OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') OR
        (status = 'pending' AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'driver'))
    );

DROP POLICY IF EXISTS "Drivers and Admins can update orders" ON public.orders;
CREATE POLICY "Drivers and Admins can update orders" ON public.orders
    FOR UPDATE USING (
        auth.uid() = driver_id OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- 8. REALTIME CONFIGURATION
-- Mengaktifkan Supabase Realtime agar status pesanan langsung sinkron (idempotent / aman di-run berkali-kali)
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 9. RPC FUNCTION: PENDAFTARAN AKUN TERPUSAT OLEH ADMIN
-- Memungkinkan Admin mendaftarkan akun Driver dan Customer langsung ke auth.users & profiles
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.admin_create_user(
    new_email TEXT,
    new_password TEXT,
    new_full_name TEXT,
    new_phone TEXT,
    new_role TEXT,
    new_vehicle_plate TEXT DEFAULT '',
    new_vehicle_type TEXT DEFAULT '',
    new_wallet_balance NUMERIC DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    new_id UUID := gen_random_uuid();
    v_role public.user_role;
BEGIN
    IF new_role = 'driver' THEN
        v_role := 'driver'::public.user_role;
    ELSIF new_role = 'admin' THEN
        v_role := 'admin'::public.user_role;
    ELSE
        v_role := 'customer'::public.user_role;
    END IF;

    -- 1. Buat record di auth.users (langsung terkonfirmasi / siap login)
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud,
        confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
        reauthentication_token, email_change, phone_change, phone_change_token
    ) VALUES (
        new_id, '00000000-0000-0000-0000-000000000000',
        new_email, crypt(new_password, gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('full_name', new_full_name, 'phone', new_phone, 'role', new_role),
        now(), now(), 'authenticated', 'authenticated',
        '', '', '', '', '', '', '', ''
    );

    -- 2. Buat record di auth.identities
    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        new_id, new_id,
        jsonb_build_object('sub', new_id::text, 'email', new_email),
        'email', new_id::text, now(), now(), now()
    );

    -- 3. Masukkan ke public.profiles
    INSERT INTO public.profiles (
        id, full_name, phone, email, role, vehicle_plate, vehicle_type, wallet_balance, is_online, created_at, updated_at
    ) VALUES (
        new_id, new_full_name, new_phone, new_email, v_role, new_vehicle_plate, new_vehicle_type, new_wallet_balance, true, now(), now()
    )
    ON CONFLICT (id) DO UPDATE SET 
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        vehicle_plate = EXCLUDED.vehicle_plate,
        vehicle_type = EXCLUDED.vehicle_type,
        wallet_balance = EXCLUDED.wallet_balance;

    RETURN new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_user TO anon;


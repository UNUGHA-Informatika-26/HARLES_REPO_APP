-- ============================================================
-- HARLES JUJUG — SEEDER AKUN ADMIN & DEMO DRIVER
-- ============================================================
-- Petunjuk:
-- Jalankan script ini di SQL Editor Supabase untuk membuat
-- akun Admin dan Akun Demo bawaan secara otomatis.
-- Password default semua akun ini: password123
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. BERSIHKAN KOLOM NULL DI AUTH.USERS YANG MEMBUAT ERROR 500 (SCHEMA QUERY ERROR)
UPDATE auth.users 
SET 
    confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    reauthentication_token = COALESCE(reauthentication_token, ''),
    email_change = COALESCE(email_change, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, '');

-- 2. HAPUS USER LAMA AGAR BERSIH
DELETE FROM auth.users WHERE email IN ('admin@harlesjujug.com', 'ahmad.driver@gmail.com');

-- 3. BUAT AKUN ADMIN BESERTA IDENTITIES LENGKAP
DO $$
DECLARE
    admin_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud,
        confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
        reauthentication_token, email_change, phone_change, phone_change_token
    ) VALUES (
        admin_id, '00000000-0000-0000-0000-000000000000',
        'admin@harlesjujug.com', crypt('password123', gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Administrator Utama","phone":"6281234567890","role":"admin"}',
        now(), now(), 'authenticated', 'authenticated',
        '', '', '', '', '', '', '', ''
    );

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        admin_id, admin_id,
        format('{"sub":"%s","email":"%s"}', admin_id::text, 'admin@harlesjujug.com')::jsonb,
        'email', admin_id::text, now(), now(), now()
    );

    INSERT INTO public.profiles (id, full_name, phone, email, role, wallet_balance, created_at, updated_at)
    VALUES (admin_id, 'Administrator Utama', '6281234567890', 'admin@harlesjujug.com', 'admin', 999999999, now(), now())
    ON CONFLICT (id) DO UPDATE SET role = 'admin';
END $$;

-- 4. BUAT AKUN DRIVER BESERTA IDENTITIES LENGKAP
DO $$
DECLARE
    driver_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud,
        confirmation_token, recovery_token, email_change_token_new, email_change_token_current,
        reauthentication_token, email_change, phone_change, phone_change_token
    ) VALUES (
        driver_id, '00000000-0000-0000-0000-000000000000',
        'ahmad.driver@gmail.com', crypt('password123', gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Ahmad Supriadi","phone":"6281311223344","role":"driver"}',
        now(), now(), 'authenticated', 'authenticated',
        '', '', '', '', '', '', '', ''
    );

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        driver_id, driver_id,
        format('{"sub":"%s","email":"%s"}', driver_id::text, 'ahmad.driver@gmail.com')::jsonb,
        'email', driver_id::text, now(), now(), now()
    );

    INSERT INTO public.profiles (id, full_name, phone, email, role, is_online, vehicle_plate, vehicle_type, wallet_balance, created_at, updated_at)
    VALUES (driver_id, 'Ahmad Supriadi', '6281311223344', 'ahmad.driver@gmail.com', 'driver', true, 'B 1234 XYZ', 'Honda Vario 160', 250000, now(), now())
    ON CONFLICT (id) DO UPDATE SET role = 'driver', is_online = true;
END $$;

-- 5. PASTIKAN SEMUA EMAIL DI-APPROVE / DIKONFIRMASI LANGSUNG
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE email_confirmed_at IS NULL;

-- 6. RPC FUNCTION: PENDAFTARAN AKUN TERPUSAT OLEH ADMIN
-- Memungkinkan Admin mendaftarkan Driver dan Customer langsung via aplikasi Harles Jujug
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

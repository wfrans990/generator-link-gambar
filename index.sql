-- ============================================================
-- IMAGE LINK GENERATOR PRO
-- FIX: SECURE ADMIN CHECK WITHOUT EXPOSING ADMIN TABLE
-- ============================================================
-- Jalankan script ini di Supabase SQL Editor.
--
-- Penyebab error sebelumnya:
-- HTML mencoba SELECT langsung ke image_history_admins,
-- sementara akses SELECT memang sudah ditutup.
--
-- Solusi:
-- Browser memanggil function SECURITY DEFINER.
-- Function mengecek UUID login di tabel admin tanpa membuka
-- tabel image_history_admins kepada browser.
-- ============================================================

-- 1. Pastikan tabel admin ada
create table if not exists public.image_history_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.image_history_admins enable row level security;

-- 2. Tutup akses langsung ke tabel admin
revoke all on table public.image_history_admins from anon, authenticated;

-- 3. Buat function untuk mengecek apakah user login adalah admin
create or replace function public.is_image_history_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.image_history_admins
    where user_id = auth.uid()
  );
$$;

-- 4. Browser hanya boleh memanggil function, bukan membaca tabel admin
revoke all on function public.is_image_history_admin() from public;
grant execute on function public.is_image_history_admin() to anon, authenticated;

-- 5. Hapus policy DELETE lama yang terlalu terbuka
drop policy if exists "Allow delete image history"
on public.image_upload_history;

drop policy if exists "Only admins can delete image history"
on public.image_upload_history;

-- 6. Hanya authenticated ADMIN yang boleh DELETE
create policy "Only admins can delete image history"
on public.image_upload_history
for delete
to authenticated
using (
  public.is_image_history_admin()
);

-- 7. Pastikan akses history tetap benar
grant select, insert on table public.image_upload_history to anon, authenticated;
grant delete on table public.image_upload_history to authenticated;

-- 8. Pastikan realtime aktif
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'image_upload_history'
  ) then
    alter publication supabase_realtime
      add table public.image_upload_history;
  end if;
end $$;

-- ============================================================
-- 9. PASTIKAN USER INI TERDAFTAR SEBAGAI ADMIN
-- ============================================================
-- UUID admin yang kamu gunakan:
-- 94c25e42-0c60-42ba-8da8-7537e4d27bd6
--
-- INSERT hanya perlu dijalankan sekali.
-- Jika sudah pernah dimasukkan, jangan ulangi karena PRIMARY KEY.
-- ============================================================

insert into public.image_history_admins (user_id)
values ('94c25e42-0c60-42ba-8da8-7537e4d27bd6')
on conflict (user_id) do nothing;

-- ============================================================
-- 10. TEST DARI SQL EDITOR
-- ============================================================
-- Query ini dijalankan sebagai database owner/admin, bukan
-- sebagai browser user. Harus menghasilkan true jika UUID
-- admin di atas memang ada.
--
-- select exists (
--   select 1
--   from public.image_history_admins
--   where user_id = '94c25e42-0c60-42ba-8da8-7537e4d27bd6'
-- );
-- ============================================================

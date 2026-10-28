-- e-Tahsilatım ilk kurulum şeması
-- Bu script mevcut tabloları silmez. Canlı veritabanında uygulamadan önce yedek alın.
create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists company_id uuid;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists role text not null default 'personel';
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.cariler add column if not exists company_id uuid;
alter table public.cariler add column if not exists id uuid default gen_random_uuid();
alter table public.cariler alter column id set default gen_random_uuid();
alter table public.makbuzlar add column if not exists company_id uuid;
alter table public.makbuzlar add column if not exists cek_no text;
alter table public.makbuzlar add column if not exists vade_tarihi date;
alter table public.makbuzlar add column if not exists banka text;
alter table public.makbuzlar alter column id set default gen_random_uuid();

-- Signup trigger: her yeni hesap için şirket ve yönetici profili açar.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare new_company_id uuid;
begin
  insert into public.companies(name, owner_id)
  values (coalesce(nullif(new.raw_user_meta_data->>'company_name',''), split_part(new.email,'@',1) || ' şirketi'), new.id)
  returning id into new_company_id;
  insert into public.profiles(id,email,full_name,role,company_id)
  values (new.id, coalesce(new.email,''), nullif(new.raw_user_meta_data->>'full_name',''), 'yonetici', new_company_id)
  on conflict (id) do update set email=excluded.email, company_id=excluded.company_id;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.current_company_id()
returns uuid language sql stable security definer set search_path = public
as $$ select company_id from public.profiles where id = auth.uid() limit 1 $$;
create or replace function public.is_company_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='yonetici') $$;

create table if not exists public.subscription_plans (
 id uuid primary key default gen_random_uuid(), name text not null, monthly_price numeric(12,2) not null default 0,
 yearly_price numeric(12,2) not null default 0, included_reps integer not null default 5, unlimited_reps boolean not null default false,
 active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.subscriptions (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 plan_id uuid references public.subscription_plans(id), period text not null default 'monthly', status text not null default 'pending',
 starts_at date, ends_at date, locked_price numeric(12,2) not null default 0, rep_limit integer not null default 5,
 created_at timestamptz not null default now()
);
create table if not exists public.payment_requests (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 subscription_id uuid references public.subscriptions(id), amount numeric(12,2) not null, payment_date date,
 bank_reference text, note text, status text not null default 'pending', reviewed_by uuid, reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.invoice_documents (
 id uuid primary key default gen_random_uuid(), company_id uuid not null default public.current_company_id() references public.companies(id),
 file_name text not null, invoice_no text not null, invoice_date date, invoice_type text not null default 'Bilinmiyor',
 supplier_vkn text, currency text not null default 'TRY', payable_amount numeric(14,2) not null default 0,
 xml_text text, status text not null default 'incelemede', created_at timestamptz not null default now(),
 unique(company_id, invoice_no, supplier_vkn)
);

-- Foreign keys are added only when absent.
do $$ begin
 if not exists(select 1 from pg_constraint where conname='profiles_company_id_fkey') then alter table public.profiles add constraint profiles_company_id_fkey foreign key(company_id) references public.companies(id); end if;
 if not exists(select 1 from pg_constraint where conname='cariler_company_id_fkey') then alter table public.cariler add constraint cariler_company_id_fkey foreign key(company_id) references public.companies(id); end if;
 if not exists(select 1 from pg_constraint where conname='makbuzlar_company_id_fkey') then alter table public.makbuzlar add constraint makbuzlar_company_id_fkey foreign key(company_id) references public.companies(id); end if;
end $$;

-- Indexes
create index if not exists cariler_company_idx on public.cariler(company_id);
create index if not exists makbuzlar_company_idx on public.makbuzlar(company_id);
create index if not exists makbuzlar_cari_idx on public.makbuzlar(cari_id);
create index if not exists invoice_documents_company_idx on public.invoice_documents(company_id);

-- RLS
alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.cariler enable row level security;
alter table public.makbuzlar enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payment_requests enable row level security;
alter table public.invoice_documents enable row level security;

-- Drop legacy broad policies with known names and common older names.
drop policy if exists "Giriş yapan tüm yetkililer carileri görebilir" on public.cariler;
drop policy if exists "Giriş yapanlar yeni cari ekleyebilir" on public.cariler;
drop policy if exists "Carileri güncelleme izni" on public.cariler;
drop policy if exists "Sadece yöneticiler cari silebilir" on public.cariler;
drop policy if exists "Giriş yapanlar makbuzları görebilir" on public.makbuzlar;
drop policy if exists "Makbuz oluşturma" on public.makbuzlar;
drop policy if exists "Sadece yöneticiler makbuz silebilir veya güncelleyebilir" on public.makbuzlar;
drop policy if exists "Kullanıcılar kendi profilini güncelleyebilir" on public.profiles;
drop policy if exists "Kullanıcılar kendi profillerini görebilir" on public.profiles;
drop policy if exists "Yöneticiler tüm profilleri görebilir" on public.profiles;

create policy company_select on public.companies for select to authenticated using (id=public.current_company_id());
create policy profiles_select on public.profiles for select to authenticated using (id=auth.uid() or company_id=public.current_company_id());
create policy profiles_update_self on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid() and company_id=public.current_company_id());
create policy cariler_select_company on public.cariler for select to authenticated using (company_id=public.current_company_id());
create policy cariler_insert_company on public.cariler for insert to authenticated with check (company_id=public.current_company_id());
create policy cariler_update_company on public.cariler for update to authenticated using (company_id=public.current_company_id()) with check (company_id=public.current_company_id());
create policy cariler_delete_admin on public.cariler for delete to authenticated using (company_id=public.current_company_id() and public.is_company_admin());
create policy makbuzlar_select_company on public.makbuzlar for select to authenticated using (company_id=public.current_company_id());
create policy makbuzlar_insert_company on public.makbuzlar for insert to authenticated with check (company_id=public.current_company_id());
create policy makbuzlar_update_admin on public.makbuzlar for update to authenticated using (company_id=public.current_company_id() and public.is_company_admin()) with check (company_id=public.current_company_id() and public.is_company_admin());
create policy makbuzlar_delete_admin on public.makbuzlar for delete to authenticated using (company_id=public.current_company_id() and public.is_company_admin());
create policy plans_read_active on public.subscription_plans for select to authenticated using (active=true);
create policy subscriptions_company_select on public.subscriptions for select to authenticated using (company_id=public.current_company_id());
create policy subscriptions_company_insert on public.subscriptions for insert to authenticated with check (company_id=public.current_company_id());
create policy payment_requests_company_select on public.payment_requests for select to authenticated using (company_id=public.current_company_id());
create policy payment_requests_company_insert on public.payment_requests for insert to authenticated with check (company_id=public.current_company_id());
create policy invoices_company_select on public.invoice_documents for select to authenticated using (company_id=public.current_company_id());
create policy invoices_company_insert on public.invoice_documents for insert to authenticated with check (company_id=public.current_company_id());
create policy invoices_company_update on public.invoice_documents for update to authenticated using (company_id=public.current_company_id()) with check (company_id=public.current_company_id());

-- IMPORTANT: Eski cariler/makbuzlar varsa company_id NULL kalır ve şirket kullanıcılarına görünmez.
-- SQL'i çalıştırmadan önce mevcut kayıtları yedekleyin ve eski kayıtların hangi şirkete ait olduğunu belirleyin.
-- Mevcut profillere şirket ataması otomatik tahmin edilmez. Canlıya geçmeden önce şirket bazlı backfill yapılmalıdır.

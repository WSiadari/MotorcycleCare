-- =====================================================================
-- MotorcycleCare — Supabase schema (user app + ready for the admin app)
-- Run once in: Supabase Dashboard → SQL Editor → New query → Run
-- =====================================================================

-- ---------------------------------------------------------------- tables
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null default '',
  email         text not null default '',
  role          text not null default 'owner' check (role in ('owner', 'mechanic', 'admin')),
  workshop_name text,
  staff_code    text,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists public.catalog_models (
  id              bigint generated always as identity primary key,
  motorcycle_type text not null check (motorcycle_type in ('matic', 'underbone', 'sport', 'trail')),
  make            text not null,
  model           text not null,
  model_year      int  not null check (model_year between 1950 and 2100),
  created_at      timestamptz not null default now(),
  unique (make, model, model_year)
);

create table if not exists public.maintenance_rules (
  id               bigint generated always as identity primary key,
  catalog_id       bigint not null references public.catalog_models (id) on delete cascade,
  component_key    text   not null,
  component_name   text   not null,
  interval_km      int    not null check (interval_km > 0),
  interval_months  int    not null check (interval_months > 0),
  source_reference text   not null default 'Owner''s manual',
  created_at       timestamptz not null default now(),
  unique (catalog_id, component_key)
);
create index if not exists maintenance_rules_catalog_id_idx on public.maintenance_rules (catalog_id);

create table if not exists public.motorcycles (
  id                    uuid primary key default gen_random_uuid(),
  owner_id              uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  catalog_id            bigint not null references public.catalog_models (id),
  plate                 text not null unique,
  odometer              int  not null check (odometer >= 0),
  odometer_updated_at   date not null default current_date,
  registration_odometer int  not null check (registration_odometer >= 0),
  registered_at         date not null default current_date,
  created_at            timestamptz not null default now()
);
create index if not exists motorcycles_owner_id_idx on public.motorcycles (owner_id);
create index if not exists motorcycles_catalog_id_idx on public.motorcycles (catalog_id);

create table if not exists public.maintenance_records (
  id            uuid primary key default gen_random_uuid(),
  motorcycle_id uuid not null references public.motorcycles (id) on delete cascade,
  service_date  date not null,
  odometer      int  not null check (odometer >= 0),
  workshop      text,                -- null = done by the owner
  receipt_path  text,                -- path inside the "receipts" storage bucket
  receipt_name  text,
  created_at    timestamptz not null default now()
);
create index if not exists maintenance_records_motorcycle_id_idx on public.maintenance_records (motorcycle_id);

create table if not exists public.maintenance_record_items (
  record_id     uuid not null references public.maintenance_records (id) on delete cascade,
  component_key text not null,
  description   text not null default '',
  primary key (record_id, component_key)
);

-- ---------------------------------------------------- profile on sign-up
-- Trigger functions live in a private (non-exposed) schema.
create schema if not exists private;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- full_name is display data only; the role is never taken from user metadata.
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), coalesce(new.email, ''));
  return new;
end;
$$;
revoke execute on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------- Data API access
-- New tables are not exposed to the Data API automatically, so grant explicitly.
grant select on public.profiles, public.catalog_models, public.maintenance_rules to authenticated;
grant select, insert, update, delete on public.motorcycles, public.maintenance_records,
  public.maintenance_record_items to authenticated;

-- ---------------------------------------------------- Row Level Security
alter table public.profiles                 enable row level security;
alter table public.catalog_models           enable row level security;
alter table public.maintenance_rules        enable row level security;
alter table public.motorcycles              enable row level security;
alter table public.maintenance_records      enable row level security;
alter table public.maintenance_record_items enable row level security;

-- profiles: each user reads only their own row (admin policies come with the admin app)
drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

-- catalog + rules: read-only for signed-in users (managed by admins)
drop policy if exists "catalog: read" on public.catalog_models;
create policy "catalog: read" on public.catalog_models for select to authenticated using (true);
drop policy if exists "rules: read" on public.maintenance_rules;
create policy "rules: read" on public.maintenance_rules for select to authenticated using (true);

-- motorcycles: owners manage only their own motorcycles
drop policy if exists "motorcycles: read own" on public.motorcycles;
create policy "motorcycles: read own" on public.motorcycles for select to authenticated
  using ((select auth.uid()) = owner_id);
drop policy if exists "motorcycles: insert own" on public.motorcycles;
create policy "motorcycles: insert own" on public.motorcycles for insert to authenticated
  with check ((select auth.uid()) = owner_id);
drop policy if exists "motorcycles: update own" on public.motorcycles;
create policy "motorcycles: update own" on public.motorcycles for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists "motorcycles: delete own" on public.motorcycles;
create policy "motorcycles: delete own" on public.motorcycles for delete to authenticated
  using ((select auth.uid()) = owner_id);

-- maintenance records: only for motorcycles the user owns
drop policy if exists "records: own" on public.maintenance_records;
create policy "records: own" on public.maintenance_records for all to authenticated
  using (exists (select 1 from public.motorcycles m
                 where m.id = motorcycle_id and m.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.motorcycles m
                      where m.id = motorcycle_id and m.owner_id = (select auth.uid())));

drop policy if exists "record items: own" on public.maintenance_record_items;
create policy "record items: own" on public.maintenance_record_items for all to authenticated
  using (exists (select 1 from public.maintenance_records r
                 join public.motorcycles m on m.id = r.motorcycle_id
                 where r.id = record_id and m.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.maintenance_records r
                      join public.motorcycles m on m.id = r.motorcycle_id
                      where r.id = record_id and m.owner_id = (select auth.uid())));

-- ---------------------------------------------------- receipt storage
-- Private bucket; each user writes into a folder named after their user id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

drop policy if exists "receipts: read own" on storage.objects;
create policy "receipts: read own" on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "receipts: upload own" on storage.objects;
create policy "receipts: upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "receipts: delete own" on storage.objects;
create policy "receipts: delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);

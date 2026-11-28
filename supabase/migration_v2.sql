-- =====================================================================
-- MotorcycleCare — migration v1 → v2 (for projects that already ran the OLD schema.sql)
--
-- Order:  1) this file   2) schema.sql   3) seed.sql      (SQL Editor → Run, one after another)
--
-- What happens to the existing data (nothing is deleted):
--   profiles                   → user_accounts + motorcycle_owners / mechanics / admins (+ workshops)
--   catalog_models             → motorcycle_catalog          (renamed, same ids)
--   maintenance_rules.id       → maintenance_rules.rule_id   (same ids)
--   motorcycles.id/plate/odometer → motorcycle_id / plate_number / current_odometer
--   registration_odometer + registered_at → first row in odometer_readings
--   maintenance_records        → service_records (recorded_by_user_id = the owner)
--   receipt_path / receipt_name → service_receipts (files stay where they are in Storage)
--   maintenance_record_items   → service_record_items (component_key → rule_id)
-- The whole file is one transaction (one DO block): if a step fails, nothing is changed.
-- Running it again on an already migrated project does nothing.
-- =====================================================================

do $migration$
declare
  v_unmapped int;
  v_bad_owner text;
  v_con record;
begin
  if to_regclass('public.profiles') is null then
    raise notice 'MotorcycleCare: no v1 tables found, nothing to migrate.';
    return;
  end if;

  create schema if not exists private;

  -- The v1 sign-up trigger writes into profiles; schema.sql creates the v2 trigger again.
  drop trigger if exists on_auth_user_created on auth.users;

  -- v1 policies (v2 policies are created by schema.sql)
  drop policy if exists "profiles: read own" on public.profiles;
  drop policy if exists "motorcycles: read own" on public.motorcycles;
  drop policy if exists "motorcycles: insert own" on public.motorcycles;
  drop policy if exists "motorcycles: update own" on public.motorcycles;
  drop policy if exists "motorcycles: delete own" on public.motorcycles;
  drop policy if exists "records: own" on public.maintenance_records;
  drop policy if exists "record items: own" on public.maintenance_record_items;

  -- ------------------------------------------------------------ accounts
  create table if not exists public.roles (
    role_id     smallint primary key,
    role_name   text not null unique check (role_name in ('owner', 'mechanic', 'admin')),
    description text not null default ''
  );
  insert into public.roles (role_id, role_name, description) values
    (1, 'owner',    'Motorcycle Owner: manages own motorcycles, odometer and maintenance records'),
    (2, 'mechanic', 'Mechanic: searches motorcycles by plate and records services'),
    (3, 'admin',    'Admin: manages users, the motorcycle catalog and maintenance rules')
  on conflict (role_id) do nothing;

  create table if not exists public.staff_codes (
    code        text primary key check (code = upper(code)),
    description text not null default '',
    active      boolean not null default true
  );
  insert into public.staff_codes (code, description)
  select distinct upper(trim(p.staff_code)), 'Migrated from v1 profiles'
  from public.profiles p
  where p.role = 'admin' and coalesce(trim(p.staff_code), '') <> ''
  on conflict (code) do nothing;

  create table if not exists public.workshops (
    workshop_id bigint generated always as identity primary key,
    name        text not null check (length(trim(name)) > 0),
    address     text,
    city        text,
    hours       text,
    phone       text
  );
  create unique index if not exists workshops_name_key on public.workshops (lower(name));
  insert into public.workshops (name)
  select distinct on (lower(trim(p.workshop_name))) trim(p.workshop_name)
  from public.profiles p
  where p.role = 'mechanic' and coalesce(trim(p.workshop_name), '') <> ''
  on conflict do nothing;

  create table if not exists public.user_accounts (
    user_id    uuid primary key references auth.users (id) on delete cascade,
    email      text not null default '',
    full_name  text not null default '',
    phone      text,
    active     boolean not null default true,
    role_id    smallint not null default 1 references public.roles (role_id),
    created_at timestamptz not null default now()
  );
  insert into public.user_accounts (user_id, email, full_name, active, role_id, created_at)
  select p.id, p.email, p.full_name, p.active, ro.role_id, p.created_at
  from public.profiles p
  join public.roles ro on ro.role_name = p.role
  on conflict (user_id) do nothing;

  -- motorcycles.owner_id must point at a Motorcycle Owner from now on
  select string_agg(distinct p.email || ' (' || p.role || ')', ', ') into v_bad_owner
  from public.motorcycles m join public.profiles p on p.id = m.owner_id
  where p.role <> 'owner';
  if v_bad_owner is not null then
    raise exception 'Migration stopped: these non-owner accounts own motorcycles: %. '
                    'Set their role to owner in public.profiles, then run this file again.', v_bad_owner;
  end if;

  create table if not exists public.motorcycle_owners (
    user_id              uuid primary key references public.user_accounts (user_id) on delete cascade,
    notification_enabled boolean not null default true
  );
  insert into public.motorcycle_owners (user_id)
  select p.id from public.profiles p where p.role = 'owner'
  on conflict (user_id) do nothing;

  create table if not exists public.mechanics (
    user_id     uuid primary key references public.user_accounts (user_id) on delete cascade,
    workshop_id bigint references public.workshops (workshop_id) on delete set null
  );
  insert into public.mechanics (user_id, workshop_id)
  select p.id, w.workshop_id
  from public.profiles p
  left join public.workshops w on lower(w.name) = lower(trim(p.workshop_name))
  where p.role = 'mechanic'
  on conflict (user_id) do nothing;

  create table if not exists public.admins (
    user_id    uuid primary key references public.user_accounts (user_id) on delete cascade,
    staff_code text references public.staff_codes (code) on update cascade on delete set null
  );
  insert into public.admins (user_id, staff_code)
  select p.id, nullif(upper(trim(coalesce(p.staff_code, ''))), '')
  from public.profiles p where p.role = 'admin'
  on conflict (user_id) do nothing;

  -- ------------------------------------------------------------ catalog + rules (rename, keep ids)
  alter table public.catalog_models rename to motorcycle_catalog;
  alter table public.motorcycle_catalog rename column id to catalog_id;
  alter table public.motorcycle_catalog drop column if exists created_at;

  alter table public.maintenance_rules rename column id to rule_id;
  alter table public.maintenance_rules drop column if exists created_at;

  -- ------------------------------------------------------------ motorcycles
  alter table public.motorcycles rename column id to motorcycle_id;
  alter table public.motorcycles rename column plate to plate_number;
  alter table public.motorcycles rename column odometer to current_odometer;
  alter table public.motorcycles alter column owner_id drop default;
  alter table public.motorcycles alter column odometer_updated_at type timestamptz
    using odometer_updated_at::timestamptz;
  alter table public.motorcycles alter column odometer_updated_at set default now();
  alter table public.motorcycles drop constraint if exists motorcycles_owner_id_fkey;
  alter table public.motorcycles add constraint motorcycles_owner_id_fkey
    foreign key (owner_id) references public.motorcycle_owners (user_id) on delete cascade;
  alter table public.motorcycles drop constraint if exists motorcycles_odometer_check;
  alter table public.motorcycles add constraint motorcycles_current_odometer_check
    check (current_odometer between 0 and 999999);
  update public.motorcycles set plate_number = upper(plate_number) where plate_number <> upper(plate_number);
  alter table public.motorcycles add constraint motorcycles_plate_number_check
    check (plate_number = upper(plate_number));

  create table if not exists public.odometer_readings (
    reading_id    bigint generated always as identity primary key,
    motorcycle_id uuid not null references public.motorcycles (motorcycle_id) on delete cascade,
    value_km      int  not null check (value_km between 0 and 999999),
    recorded_at   timestamptz not null default now(),
    recorded_by   uuid references public.user_accounts (user_id) on delete set null
  );
  -- first reading = the old registration values, second = the latest odometer (when it differs)
  insert into public.odometer_readings (motorcycle_id, value_km, recorded_at, recorded_by)
  select m.motorcycle_id, m.registration_odometer, m.registered_at::timestamptz, m.owner_id
  from public.motorcycles m;
  insert into public.odometer_readings (motorcycle_id, value_km, recorded_at, recorded_by)
  select m.motorcycle_id, m.current_odometer, m.odometer_updated_at, m.owner_id
  from public.motorcycles m
  where m.current_odometer <> m.registration_odometer or m.odometer_updated_at::date <> m.registered_at;
  alter table public.motorcycles drop column registration_odometer;
  alter table public.motorcycles drop column registered_at;

  -- ------------------------------------------------------------ service records
  alter table public.maintenance_records rename to service_records;
  alter table public.service_records rename column id to record_id;
  alter table public.service_records rename column odometer to odometer_km;
  alter table public.service_records rename column workshop to workshop_name;
  alter table public.service_records drop constraint if exists maintenance_records_odometer_check;
  alter table public.service_records add constraint service_records_odometer_km_check
    check (odometer_km between 0 and 999999);
  alter table public.service_records add column mechanic_id uuid
    references public.mechanics (user_id) on delete set null;
  alter table public.service_records add column recorded_by_user_id uuid default auth.uid()
    references public.user_accounts (user_id) on delete set null;
  -- v1 could only be used by owners, so the owner recorded every existing service
  update public.service_records r set recorded_by_user_id = m.owner_id
  from public.motorcycles m where m.motorcycle_id = r.motorcycle_id;

  create table if not exists public.service_receipts (
    receipt_id   bigint generated always as identity primary key,
    record_id    uuid not null unique references public.service_records (record_id) on delete cascade,
    file_name    text not null,
    storage_path text not null unique,
    uploaded_at  timestamptz not null default now()
  );
  insert into public.service_receipts (record_id, file_name, storage_path, uploaded_at)
  select r.record_id, coalesce(nullif(r.receipt_name, ''), regexp_replace(r.receipt_path, '^.*/', '')),
         r.receipt_path, r.created_at
  from public.service_records r
  where r.receipt_path is not null
  on conflict (record_id) do nothing;
  alter table public.service_records drop column receipt_path;
  alter table public.service_records drop column receipt_name;

  create table if not exists public.service_record_items (
    item_id          bigint generated always as identity primary key,
    record_id        uuid   not null references public.service_records (record_id) on delete cascade,
    rule_id          bigint not null references public.maintenance_rules (rule_id) on delete restrict,
    work_description text   not null default '',
    unique (record_id, rule_id)
  );
  select count(*) into v_unmapped
  from public.maintenance_record_items i
  join public.service_records r on r.record_id = i.record_id
  join public.motorcycles m on m.motorcycle_id = r.motorcycle_id
  left join public.maintenance_rules mr on mr.catalog_id = m.catalog_id and mr.component_key = i.component_key
  where mr.rule_id is null;
  if v_unmapped > 0 then
    raise exception 'Migration stopped: % service item(s) use a component that has no maintenance rule any more. '
                    'Add the missing rules (same component_key) and run this file again.', v_unmapped;
  end if;
  insert into public.service_record_items (record_id, rule_id, work_description)
  select i.record_id, mr.rule_id, i.description
  from public.maintenance_record_items i
  join public.service_records r on r.record_id = i.record_id
  join public.motorcycles m on m.motorcycle_id = r.motorcycle_id
  join public.maintenance_rules mr on mr.catalog_id = m.catalog_id and mr.component_key = i.component_key
  on conflict (record_id, rule_id) do nothing;

  -- ------------------------------------------------------------ old tables (all data copied above)
  drop table public.maintenance_record_items;
  drop table public.profiles;

  -- tidy constraint / index names left over from the old table names
  for v_con in
    select c.conname, c.conrelid::regclass as tbl, t.relname
    from pg_constraint c join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and (c.conname like 'catalog\_models\_%' or c.conname like 'maintenance\_records\_%'
           or c.conname = 'motorcycles_plate_key')
  loop
    execute format('alter table %s rename constraint %I to %I', v_con.tbl, v_con.conname,
      replace(replace(replace(v_con.conname, 'catalog_models_', 'motorcycle_catalog_'),
                      'maintenance_records_', 'service_records_'), 'motorcycles_plate_key', 'motorcycles_plate_number_key'));
  end loop;
  alter index if exists public.maintenance_records_motorcycle_id_idx rename to service_records_motorcycle_id_idx;

  raise notice 'MotorcycleCare: v1 data migrated. Now run schema.sql, then seed.sql.';
end;
$migration$;

-- =====================================================================
-- MotorcycleCare — Supabase schema (Motorcycle Owner · Mechanic · Admin)
--
-- New project: run this file, then seed.sql.
-- Project with the v1 schema: run migration_v2.sql first, then this file, then seed.sql.
-- Safe to run again: tables use "if not exists", functions "create or replace",
-- policies are dropped and created again.
-- Passwords are kept by Supabase Auth (auth.users), never in these tables.
-- =====================================================================

create schema if not exists private;

-- ================================================================ 1. tables
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

-- Codes that allow someone to register an Admin account (checked by private.register_role).
create table if not exists public.staff_codes (
  code        text primary key check (code = upper(code)),
  description text not null default '',
  active      boolean not null default true
);

create table if not exists public.workshops (
  workshop_id bigint generated always as identity primary key,
  name        text not null check (length(trim(name)) > 0),
  address     text,
  city        text,
  hours       text,
  phone       text
);
create unique index if not exists workshops_name_key on public.workshops (lower(name));

-- One row per Supabase Auth user. Created by the on_auth_user_created trigger.
create table if not exists public.user_accounts (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null default '',
  full_name  text not null default '',
  phone      text,
  active     boolean not null default true,
  role_id    smallint not null default 1 references public.roles (role_id),
  created_at timestamptz not null default now()
);
create index if not exists user_accounts_role_id_idx on public.user_accounts (role_id);

create table if not exists public.motorcycle_owners (
  user_id              uuid primary key references public.user_accounts (user_id) on delete cascade,
  notification_enabled boolean not null default true
);

create table if not exists public.mechanics (
  user_id     uuid primary key references public.user_accounts (user_id) on delete cascade,
  workshop_id bigint references public.workshops (workshop_id) on delete set null
);
create index if not exists mechanics_workshop_id_idx on public.mechanics (workshop_id);

create table if not exists public.admins (
  user_id    uuid primary key references public.user_accounts (user_id) on delete cascade,
  staff_code text references public.staff_codes (code) on update cascade on delete set null
);

create table if not exists public.motorcycle_catalog (
  catalog_id      bigint generated always as identity primary key,
  motorcycle_type text not null check (motorcycle_type in ('matic', 'underbone', 'sport', 'trail')),
  make            text not null,
  model           text not null,
  model_year      int  not null check (model_year between 1950 and 2100),
  unique (make, model, model_year)
);

create table if not exists public.maintenance_rules (
  rule_id          bigint generated always as identity primary key,
  catalog_id       bigint not null references public.motorcycle_catalog (catalog_id) on delete cascade,
  component_key    text   not null,
  component_name   text   not null,
  interval_km      int    not null check (interval_km > 0),
  interval_months  int    not null check (interval_months > 0),
  source_reference text   not null default 'Owner''s manual',
  unique (catalog_id, component_key)
);
create index if not exists maintenance_rules_catalog_id_idx on public.maintenance_rules (catalog_id);

create table if not exists public.motorcycles (
  motorcycle_id       uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references public.motorcycle_owners (user_id) on delete cascade,
  catalog_id          bigint not null references public.motorcycle_catalog (catalog_id),
  plate_number        text not null unique check (plate_number = upper(plate_number)),
  current_odometer    int  not null check (current_odometer between 0 and 999999),
  odometer_updated_at timestamptz not null default now(),
  created_at          timestamptz not null default now()
);
create index if not exists motorcycles_owner_id_idx on public.motorcycles (owner_id);
create index if not exists motorcycles_catalog_id_idx on public.motorcycles (catalog_id);

-- Every odometer update or confirmation. The first reading is written when the motorcycle is registered.
create table if not exists public.odometer_readings (
  reading_id    bigint generated always as identity primary key,
  motorcycle_id uuid not null references public.motorcycles (motorcycle_id) on delete cascade,
  value_km      int  not null check (value_km between 0 and 999999),
  recorded_at   timestamptz not null default now(),
  recorded_by   uuid references public.user_accounts (user_id) on delete set null
);
create index if not exists odometer_readings_motorcycle_id_idx on public.odometer_readings (motorcycle_id, recorded_at);
create index if not exists odometer_readings_recorded_by_idx on public.odometer_readings (recorded_by);

create table if not exists public.service_records (
  record_id           uuid primary key default gen_random_uuid(),
  motorcycle_id       uuid not null references public.motorcycles (motorcycle_id) on delete cascade,
  mechanic_id         uuid references public.mechanics (user_id) on delete set null,   -- null = logged by the owner
  recorded_by_user_id uuid default auth.uid() references public.user_accounts (user_id) on delete set null,
  service_date        date not null,
  odometer_km         int  not null check (odometer_km between 0 and 999999),
  workshop_name       text,                                                                -- null = self-service
  created_at          timestamptz not null default now()
);
create index if not exists service_records_motorcycle_id_idx on public.service_records (motorcycle_id);
create index if not exists service_records_mechanic_id_idx on public.service_records (mechanic_id);
create index if not exists service_records_recorded_by_idx on public.service_records (recorded_by_user_id);

create table if not exists public.service_record_items (
  item_id          bigint generated always as identity primary key,
  record_id        uuid   not null references public.service_records (record_id) on delete cascade,
  rule_id          bigint not null references public.maintenance_rules (rule_id) on delete restrict,
  work_description text   not null default '',
  unique (record_id, rule_id)
);
create index if not exists service_record_items_rule_id_idx on public.service_record_items (rule_id);

-- 0..1 receipt per service record; the file itself is in the "receipts" storage bucket.
create table if not exists public.service_receipts (
  receipt_id   bigint generated always as identity primary key,
  record_id    uuid not null unique references public.service_records (record_id) on delete cascade,
  file_name    text not null,
  storage_path text not null unique,
  uploaded_at  timestamptz not null default now()
);

-- One reminder per motorcycle, rule and status (MaintenanceStatus.dueSoon / overdue) and service cycle.
-- Reminders of a component are removed when that component is serviced (trigger below).
create table if not exists public.reminders (
  reminder_id   bigint generated always as identity primary key,
  motorcycle_id uuid   not null references public.motorcycles (motorcycle_id) on delete cascade,
  rule_id       bigint not null references public.maintenance_rules (rule_id) on delete cascade,
  message       text   not null,
  due_status    text   not null check (due_status in ('dueSoon', 'overdue')),
  due_date      date   not null,
  created_at    timestamptz not null default now(),
  read_at       timestamptz,
  unique (motorcycle_id, rule_id, due_status)
);
create index if not exists reminders_rule_id_idx on public.reminders (rule_id);

create table if not exists public.service_jobs (
  job_id        bigint generated always as identity primary key,
  motorcycle_id uuid not null references public.motorcycles (motorcycle_id) on delete cascade,
  mechanic_id   uuid not null references public.mechanics (user_id) on delete cascade,
  note          text not null default '',
  status        text not null default 'waiting' check (status in ('waiting', 'inProgress', 'done')),
  created_at    timestamptz not null default now()
);
create index if not exists service_jobs_mechanic_id_idx on public.service_jobs (mechanic_id, status);
create index if not exists service_jobs_motorcycle_id_idx on public.service_jobs (motorcycle_id);

create table if not exists public.reviews (
  review_id   bigint generated always as identity primary key,
  mechanic_id uuid not null references public.mechanics (user_id) on delete cascade,
  owner_id    uuid not null references public.motorcycle_owners (user_id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text not null default '',
  created_at  timestamptz not null default now()
);
create index if not exists reviews_mechanic_id_idx on public.reviews (mechanic_id);
create index if not exists reviews_owner_id_idx on public.reviews (owner_id);

-- "Recent changes" on the Admin dashboard and the admin report.
create table if not exists public.activity_logs (
  log_id     bigint generated always as identity primary key,
  actor_id   uuid references public.user_accounts (user_id) on delete set null,
  title      text not null,
  subtitle   text not null default '',
  icon       text not null default 'info',
  created_at timestamptz not null default now()
);
create index if not exists activity_logs_created_at_idx on public.activity_logs (created_at desc);
create index if not exists activity_logs_actor_id_idx on public.activity_logs (actor_id);

-- ================================================================ 2. helpers for RLS (private schema, not exposed)
-- security definer: they read user_accounts/motorcycles without running into those tables' own policies.

create or replace function private.role_of(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select r.role_name
  from public.user_accounts u
  join public.roles r on r.role_id = u.role_id
  where u.user_id = p_user and u.active;          -- inactive accounts have no role, so RLS denies them
$$;

create or replace function private.is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.role_of(auth.uid()) = 'owner', false);
$$;

create or replace function private.is_mechanic()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.role_of(auth.uid()) = 'mechanic', false);
$$;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(private.role_of(auth.uid()) = 'admin', false);
$$;

create or replace function private.owns_motorcycle(p_motorcycle uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.motorcycles m
                 where m.motorcycle_id = p_motorcycle and m.owner_id = auth.uid())
     and private.is_owner();
$$;

-- True when p_user recorded a service on one of the signed-in owner's motorcycles
-- (owners may then see that mechanic's name and review them).
create or replace function private.serviced_my_motorcycle(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.service_records r
                 join public.motorcycles m on m.motorcycle_id = r.motorcycle_id
                 where r.recorded_by_user_id = p_user and m.owner_id = auth.uid());
$$;

-- Receipts: the motorcycle owner and the user who recorded the service may read them.
create or replace function private.can_read_receipt(p_record uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.service_records r
                 join public.motorcycles m on m.motorcycle_id = r.motorcycle_id
                 where r.record_id = p_record
                   and (m.owner_id = auth.uid() or r.recorded_by_user_id = auth.uid()));
$$;

-- Storage object "receipts/<path>": readable when a service_receipts row points at it.
create or replace function private.can_read_receipt_object(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.service_receipts sr
                 where sr.storage_path = p_name and private.can_read_receipt(sr.record_id));
$$;

-- New uploads go to "<record_id>/<file>"; only the user who recorded that service may write there.
create or replace function private.can_write_receipt_object(p_name text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_record uuid;
begin
  begin
    v_record := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return exists (select 1 from public.service_records r
                 where r.record_id = v_record and r.recorded_by_user_id = auth.uid());
end;
$$;

-- ================================================================ 3. triggers
-- Sign-up: every new auth user starts as a Motorcycle Owner. The role is NEVER read from
-- sign-up metadata; Mechanic/Admin are granted by private.register_role after server checks.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_accounts (user_id, email, full_name, role_id)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data ->> 'full_name', ''), 1)
  on conflict (user_id) do nothing;
  insert into public.motorcycle_owners (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Registering a motorcycle also writes its first odometer reading (the status baseline).
create or replace function private.handle_new_motorcycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.odometer_readings (motorcycle_id, value_km, recorded_at, recorded_by)
  values (new.motorcycle_id, new.current_odometer, new.created_at, auth.uid());
  return new;
end;
$$;

drop trigger if exists on_motorcycle_created on public.motorcycles;
create trigger on_motorcycle_created
  after insert on public.motorcycles
  for each row execute function private.handle_new_motorcycle();

-- A reading can't go below the current odometer.
create or replace function private.check_odometer_reading()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_current int;
begin
  select current_odometer into v_current from public.motorcycles where motorcycle_id = new.motorcycle_id;
  if v_current is not null and new.value_km < v_current then
    raise exception 'Odometer can''t be lower than the latest reading (% km).', v_current
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists before_odometer_reading on public.odometer_readings;
create trigger before_odometer_reading
  before insert on public.odometer_readings
  for each row execute function private.check_odometer_reading();

-- Every reading updates motorcycles.current_odometer and odometer_updated_at.
create or replace function private.handle_new_odometer_reading()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.motorcycles
     set current_odometer = new.value_km,
         odometer_updated_at = new.recorded_at
   where motorcycle_id = new.motorcycle_id
     and new.value_km >= current_odometer;
  return new;
end;
$$;

drop trigger if exists on_odometer_reading on public.odometer_readings;
create trigger on_odometer_reading
  after insert on public.odometer_readings
  for each row execute function private.handle_new_odometer_reading();

-- Servicing a component closes its reminders, so the next service cycle can remind again.
create or replace function private.handle_new_service_item()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.reminders rm
   using public.service_records r
   where r.record_id = new.record_id
     and rm.motorcycle_id = r.motorcycle_id
     and rm.rule_id = new.rule_id;
  return new;
end;
$$;

drop trigger if exists on_service_item_created on public.service_record_items;
create trigger on_service_item_created
  after insert on public.service_record_items
  for each row execute function private.handle_new_service_item();

-- ================================================================ 4. server-side role & profile functions
create or replace function private.find_or_create_workshop(p_name text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_name text := trim(coalesce(p_name, ''));
  v_id bigint;
begin
  if v_name = '' then
    raise exception 'Enter the workshop where you work.' using errcode = 'check_violation';
  end if;
  select workshop_id into v_id from public.workshops where lower(name) = lower(v_name);
  if v_id is null then
    insert into public.workshops (name) values (v_name) returning workshop_id into v_id;
  end if;
  return v_id;
end;
$$;

-- Moves a user to another role: role_id + the matching subtype row (motorcycle_owners / mechanics / admins).
create or replace function private.set_user_role(p_user uuid, p_role text, p_workshop_name text, p_staff_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_role_id smallint;
  v_current text;
begin
  select role_id into v_role_id from public.roles where role_name = p_role;
  if v_role_id is null then
    raise exception 'Unknown role %.', p_role using errcode = 'check_violation';
  end if;
  select r.role_name into v_current
    from public.user_accounts u join public.roles r on r.role_id = u.role_id where u.user_id = p_user;

  if v_current = 'owner' and p_role <> 'owner'
     and exists (select 1 from public.motorcycles where owner_id = p_user) then
    raise exception 'This owner still has registered motorcycles, so the role can''t be changed.'
      using errcode = 'check_violation';
  end if;

  if p_role <> 'owner' then delete from public.motorcycle_owners where user_id = p_user; end if;
  if p_role <> 'mechanic' then delete from public.mechanics where user_id = p_user; end if;
  if p_role <> 'admin' then delete from public.admins where user_id = p_user; end if;

  if p_role = 'owner' then
    insert into public.motorcycle_owners (user_id) values (p_user) on conflict (user_id) do nothing;
  elsif p_role = 'mechanic' then
    if p_workshop_name is null and exists (select 1 from public.mechanics where user_id = p_user) then
      null;  -- keep the current workshop
    else
      insert into public.mechanics (user_id, workshop_id)
      values (p_user, private.find_or_create_workshop(p_workshop_name))
      on conflict (user_id) do update set workshop_id = excluded.workshop_id;
    end if;
  else
    insert into public.admins (user_id, staff_code) values (p_user, p_staff_code)
    on conflict (user_id) do update set staff_code = coalesce(excluded.staff_code, public.admins.staff_code);
  end if;

  update public.user_accounts set role_id = v_role_id where user_id = p_user;
end;
$$;

-- Grants the Mechanic or Admin role right after sign-up, after the server checks.
create or replace function private.register_role(p_role text, p_workshop_name text, p_staff_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_created timestamptz;
  v_name text;
  v_code text := upper(trim(coalesce(p_staff_code, '')));
begin
  if v_uid is null then
    raise exception 'Log in first.' using errcode = 'insufficient_privilege';
  end if;
  select r.role_name, u.created_at, u.full_name into v_role, v_created, v_name
    from public.user_accounts u join public.roles r on r.role_id = u.role_id where u.user_id = v_uid;
  if v_role is null then
    raise exception 'Account not found.' using errcode = 'no_data_found';
  end if;
  if p_role = 'owner' then
    return;
  end if;
  if v_role <> 'owner' or v_created < now() - interval '30 minutes'
     or exists (select 1 from public.motorcycles where owner_id = v_uid) then
    raise exception 'A role can only be chosen when the account is created.' using errcode = 'insufficient_privilege';
  end if;

  if p_role = 'admin' then
    if not exists (select 1 from public.staff_codes where code = v_code and active) then
      raise exception 'Staff code is not valid. Ask the head admin for your code.'
        using errcode = 'check_violation', hint = 'invalid_staff_code';
    end if;
    perform private.set_user_role(v_uid, 'admin', null, v_code);
    insert into public.activity_logs (actor_id, title, subtitle, icon)
    values (v_uid, 'New admin registered', v_name, 'shield');
  elsif p_role = 'mechanic' then
    perform private.set_user_role(v_uid, 'mechanic', p_workshop_name, null);
    insert into public.activity_logs (actor_id, title, subtitle, icon)
    values (v_uid, 'New mechanic registered', trim(p_workshop_name), 'wrench');
  else
    raise exception 'Unknown role %.', p_role using errcode = 'check_violation';
  end if;
end;
$$;

-- Removes a fresh, empty account when the role registration failed, so the email can be used again.
create or replace function private.discard_new_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
begin
  if exists (select 1 from public.user_accounts u
             where u.user_id = v_uid and u.role_id = 1 and u.created_at > now() - interval '30 minutes')
     and not exists (select 1 from public.motorcycles where owner_id = v_uid) then
    delete from auth.users where id = v_uid;
  end if;
end;
$$;

-- Personal information (all roles), workshop (mechanic) and notification setting (owner).
create or replace function private.update_my_profile(p_full_name text, p_phone text,
                                                     p_workshop_name text, p_notification_enabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_role text := private.role_of(auth.uid());
begin
  if v_role is null then
    raise exception 'This account is inactive.' using errcode = 'insufficient_privilege';
  end if;
  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'Enter your full name.' using errcode = 'check_violation';
  end if;
  update public.user_accounts
     set full_name = trim(p_full_name), phone = nullif(trim(coalesce(p_phone, '')), '')
   where user_id = v_uid;
  if v_role = 'owner' and p_notification_enabled is not null then
    update public.motorcycle_owners set notification_enabled = p_notification_enabled where user_id = v_uid;
  end if;
  if v_role = 'mechanic' and nullif(trim(coalesce(p_workshop_name, '')), '') is not null then
    update public.mechanics set workshop_id = private.find_or_create_workshop(p_workshop_name) where user_id = v_uid;
  end if;
end;
$$;

-- Admin: edit another account (name, phone, role, active, workshop) in one transaction.
create or replace function private.admin_update_user(p_user_id uuid, p_full_name text, p_phone text,
                                                     p_role text, p_active boolean, p_workshop_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_current text;
begin
  if not private.is_admin() then
    raise exception 'Only admins can change user accounts.' using errcode = 'insufficient_privilege';
  end if;
  if p_user_id = auth.uid() and (p_role <> 'admin' or not p_active) then
    raise exception 'You can''t change your own role or deactivate your own account.'
      using errcode = 'insufficient_privilege';
  end if;
  select r.role_name into v_current
    from public.user_accounts u join public.roles r on r.role_id = u.role_id where u.user_id = p_user_id;
  if v_current is null then
    raise exception 'User not found.' using errcode = 'no_data_found';
  end if;
  update public.user_accounts
     set full_name = trim(p_full_name), phone = nullif(trim(coalesce(p_phone, '')), ''), active = p_active
   where user_id = p_user_id;
  if v_current <> p_role or (p_role = 'mechanic' and p_workshop_name is not null) then
    perform private.set_user_role(p_user_id, p_role, p_workshop_name, null);
  end if;
end;
$$;

-- ---------------------------------------------------------------- RPC (Data API) — thin wrappers
-- Only these four are callable by the app (signed-in users only). The work happens in private.*.
create or replace function public.register_role(p_role text, p_workshop_name text default null,
                                                p_staff_code text default null)
returns void language sql security invoker set search_path = '' as $$
  select private.register_role(p_role, p_workshop_name, p_staff_code);
$$;

create or replace function public.discard_new_account()
returns void language sql security invoker set search_path = '' as $$
  select private.discard_new_account();
$$;

create or replace function public.update_my_profile(p_full_name text, p_phone text default null,
                                                    p_workshop_name text default null,
                                                    p_notification_enabled boolean default null)
returns void language sql security invoker set search_path = '' as $$
  select private.update_my_profile(p_full_name, p_phone, p_workshop_name, p_notification_enabled);
$$;

create or replace function public.admin_update_user(p_user_id uuid, p_full_name text, p_phone text,
                                                    p_role text, p_active boolean,
                                                    p_workshop_name text default null)
returns void language sql security invoker set search_path = '' as $$
  select private.admin_update_user(p_user_id, p_full_name, p_phone, p_role, p_active, p_workshop_name);
$$;

-- ================================================================ 5. privileges
grant usage on schema private to authenticated;

revoke execute on all functions in schema private from public, anon;
grant execute on function private.role_of(uuid), private.is_owner(), private.is_mechanic(), private.is_admin(),
  private.owns_motorcycle(uuid), private.serviced_my_motorcycle(uuid), private.can_read_receipt(uuid),
  private.can_read_receipt_object(text), private.can_write_receipt_object(text),
  private.register_role(text, text, text), private.discard_new_account(),
  private.update_my_profile(text, text, text, boolean),
  private.admin_update_user(uuid, text, text, text, boolean, text) to authenticated;
revoke execute on function private.handle_new_user(), private.handle_new_motorcycle(),
  private.check_odometer_reading(), private.handle_new_odometer_reading(), private.handle_new_service_item(),
  private.find_or_create_workshop(text), private.set_user_role(uuid, text, text, text) from authenticated;

revoke execute on function public.register_role(text, text, text), public.discard_new_account(),
  public.update_my_profile(text, text, text, boolean),
  public.admin_update_user(uuid, text, text, text, boolean, text) from public, anon;
grant execute on function public.register_role(text, text, text), public.discard_new_account(),
  public.update_my_profile(text, text, text, boolean),
  public.admin_update_user(uuid, text, text, text, boolean, text) to authenticated;

-- Tables are reached by signed-in users only (RLS below decides which rows). anon gets nothing.
-- Revoke first so re-running (or running after migration_v2.sql) always ends with exactly these grants.
revoke all on public.roles, public.staff_codes, public.workshops, public.user_accounts, public.motorcycle_owners,
  public.mechanics, public.admins, public.motorcycle_catalog, public.maintenance_rules, public.motorcycles,
  public.odometer_readings, public.service_records, public.service_record_items, public.service_receipts,
  public.reminders, public.service_jobs, public.reviews, public.activity_logs from anon, authenticated;

grant select on public.roles, public.workshops, public.user_accounts, public.motorcycle_owners,
  public.mechanics, public.admins to authenticated;
grant select, insert, update, delete on public.motorcycle_catalog, public.maintenance_rules to authenticated;
grant select, insert on public.motorcycles, public.odometer_readings, public.service_record_items,
  public.reviews, public.activity_logs to authenticated;
grant select, insert, delete on public.service_records, public.service_receipts to authenticated;
grant select, insert on public.reminders to authenticated;
grant update (read_at) on public.reminders to authenticated;
grant select, insert on public.service_jobs to authenticated;
grant update (status, note) on public.service_jobs to authenticated;

-- The Edge Functions use the service role (bypasses RLS) for auth.admin calls and the admin check.
grant all on public.roles, public.staff_codes, public.workshops, public.user_accounts, public.motorcycle_owners,
  public.mechanics, public.admins, public.motorcycle_catalog, public.maintenance_rules, public.motorcycles,
  public.odometer_readings, public.service_records, public.service_record_items, public.service_receipts,
  public.reminders, public.service_jobs, public.reviews, public.activity_logs to service_role;

-- ================================================================ 6. Row Level Security
alter table public.roles                enable row level security;
alter table public.staff_codes          enable row level security;   -- no policies: server functions only
alter table public.workshops            enable row level security;
alter table public.user_accounts        enable row level security;
alter table public.motorcycle_owners    enable row level security;
alter table public.mechanics            enable row level security;
alter table public.admins               enable row level security;
alter table public.motorcycle_catalog   enable row level security;
alter table public.maintenance_rules    enable row level security;
alter table public.motorcycles          enable row level security;
alter table public.odometer_readings    enable row level security;
alter table public.service_records      enable row level security;
alter table public.service_record_items enable row level security;
alter table public.service_receipts     enable row level security;
alter table public.reminders            enable row level security;
alter table public.service_jobs         enable row level security;
alter table public.reviews              enable row level security;
alter table public.activity_logs        enable row level security;

-- roles, workshops: reference data every signed-in user may read
drop policy if exists "roles: read" on public.roles;
create policy "roles: read" on public.roles for select to authenticated using (true);

drop policy if exists "workshops: read" on public.workshops;
create policy "workshops: read" on public.workshops for select to authenticated using (true);

-- user_accounts: own row · admin all · mechanic reads owners · owner reads users who serviced their motorcycles
drop policy if exists "user_accounts: read own" on public.user_accounts;
create policy "user_accounts: read own" on public.user_accounts for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "user_accounts: admin reads all" on public.user_accounts;
create policy "user_accounts: admin reads all" on public.user_accounts for select to authenticated
  using ((select private.is_admin()));
drop policy if exists "user_accounts: mechanic reads owners" on public.user_accounts;
create policy "user_accounts: mechanic reads owners" on public.user_accounts for select to authenticated
  using (role_id = 1 and (select private.is_mechanic()));
drop policy if exists "user_accounts: owner reads own service staff" on public.user_accounts;
create policy "user_accounts: owner reads own service staff" on public.user_accounts for select to authenticated
  using (private.serviced_my_motorcycle(user_id));

-- subtype tables: own row · admin all · mechanics read owners (Select Owner, review names)
drop policy if exists "motorcycle_owners: read own" on public.motorcycle_owners;
create policy "motorcycle_owners: read own" on public.motorcycle_owners for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()) or (select private.is_mechanic()));
drop policy if exists "mechanics: read" on public.mechanics;
create policy "mechanics: read" on public.mechanics for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
drop policy if exists "admins: read" on public.admins;
create policy "admins: read" on public.admins for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));

-- catalog + rules: everybody reads, admins write
drop policy if exists "catalog: read" on public.motorcycle_catalog;
create policy "catalog: read" on public.motorcycle_catalog for select to authenticated using (true);
drop policy if exists "catalog: admin insert" on public.motorcycle_catalog;
create policy "catalog: admin insert" on public.motorcycle_catalog for insert to authenticated
  with check ((select private.is_admin()));
drop policy if exists "catalog: admin update" on public.motorcycle_catalog;
create policy "catalog: admin update" on public.motorcycle_catalog for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "catalog: admin delete" on public.motorcycle_catalog;
create policy "catalog: admin delete" on public.motorcycle_catalog for delete to authenticated
  using ((select private.is_admin()));

drop policy if exists "rules: read" on public.maintenance_rules;
create policy "rules: read" on public.maintenance_rules for select to authenticated using (true);
drop policy if exists "rules: admin insert" on public.maintenance_rules;
create policy "rules: admin insert" on public.maintenance_rules for insert to authenticated
  with check ((select private.is_admin()));
drop policy if exists "rules: admin update" on public.maintenance_rules;
create policy "rules: admin update" on public.maintenance_rules for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "rules: admin delete" on public.maintenance_rules;
create policy "rules: admin delete" on public.maintenance_rules for delete to authenticated
  using ((select private.is_admin()));

-- motorcycles: owner reads/adds own · mechanic searches all and adds for customers · admin reads (catalog usage)
drop policy if exists "motorcycles: read" on public.motorcycles;
create policy "motorcycles: read" on public.motorcycles for select to authenticated
  using (owner_id = (select auth.uid()) or (select private.is_mechanic()) or (select private.is_admin()));
drop policy if exists "motorcycles: insert" on public.motorcycles;
create policy "motorcycles: insert" on public.motorcycles for insert to authenticated
  with check ((owner_id = (select auth.uid()) and (select private.is_owner())) or (select private.is_mechanic()));

-- odometer readings (current_odometer is updated by the trigger, not by the client)
drop policy if exists "odometer: read" on public.odometer_readings;
create policy "odometer: read" on public.odometer_readings for select to authenticated
  using (private.owns_motorcycle(motorcycle_id) or (select private.is_mechanic()));
drop policy if exists "odometer: insert" on public.odometer_readings;
create policy "odometer: insert" on public.odometer_readings for insert to authenticated
  with check (recorded_by = (select auth.uid())
              and (private.owns_motorcycle(motorcycle_id) or (select private.is_mechanic())));

-- service records: owner logs own motorcycles (mechanic_id null) · mechanic logs any motorcycle under their own id
drop policy if exists "records: read" on public.service_records;
create policy "records: read" on public.service_records for select to authenticated
  using (private.owns_motorcycle(motorcycle_id) or (select private.is_mechanic()));
drop policy if exists "records: insert" on public.service_records;
create policy "records: insert" on public.service_records for insert to authenticated
  with check (recorded_by_user_id = (select auth.uid())
              and ((private.owns_motorcycle(motorcycle_id) and mechanic_id is null)
                   or ((select private.is_mechanic()) and mechanic_id = (select auth.uid()))));
drop policy if exists "records: delete own" on public.service_records;
create policy "records: delete own" on public.service_records for delete to authenticated
  using (recorded_by_user_id = (select auth.uid()));

drop policy if exists "record items: read" on public.service_record_items;
create policy "record items: read" on public.service_record_items for select to authenticated
  using (exists (select 1 from public.service_records r where r.record_id = service_record_items.record_id));
drop policy if exists "record items: insert" on public.service_record_items;
create policy "record items: insert" on public.service_record_items for insert to authenticated
  with check (exists (select 1 from public.service_records r
                      where r.record_id = service_record_items.record_id
                        and r.recorded_by_user_id = (select auth.uid())));

drop policy if exists "receipts: read" on public.service_receipts;
create policy "receipts: read" on public.service_receipts for select to authenticated
  using (private.can_read_receipt(record_id));
drop policy if exists "receipts: insert" on public.service_receipts;
create policy "receipts: insert" on public.service_receipts for insert to authenticated
  with check (exists (select 1 from public.service_records r
                      where r.record_id = service_receipts.record_id
                        and r.recorded_by_user_id = (select auth.uid())));
drop policy if exists "receipts: delete" on public.service_receipts;
create policy "receipts: delete" on public.service_receipts for delete to authenticated
  using (exists (select 1 from public.service_records r
                 where r.record_id = service_receipts.record_id
                   and r.recorded_by_user_id = (select auth.uid())));

-- reminders: the owner reads and marks them read; owner or mechanic create them after calculating status
drop policy if exists "reminders: read" on public.reminders;
create policy "reminders: read" on public.reminders for select to authenticated
  using (private.owns_motorcycle(motorcycle_id) or (select private.is_mechanic()));
drop policy if exists "reminders: insert" on public.reminders;
create policy "reminders: insert" on public.reminders for insert to authenticated
  with check (private.owns_motorcycle(motorcycle_id) or (select private.is_mechanic()));
drop policy if exists "reminders: mark read" on public.reminders;
create policy "reminders: mark read" on public.reminders for update to authenticated
  using (private.owns_motorcycle(motorcycle_id)) with check (private.owns_motorcycle(motorcycle_id));

-- service jobs: each mechanic sees and changes only their own queue
drop policy if exists "jobs: own" on public.service_jobs;
create policy "jobs: own" on public.service_jobs for all to authenticated
  using (mechanic_id = (select auth.uid()) and (select private.is_mechanic()))
  with check (mechanic_id = (select auth.uid()) and (select private.is_mechanic()));

-- reviews: owners rate mechanics who serviced their motorcycles; the mechanic reads their reviews
drop policy if exists "reviews: read" on public.reviews;
create policy "reviews: read" on public.reviews for select to authenticated
  using (mechanic_id = (select auth.uid()) or owner_id = (select auth.uid()) or (select private.is_admin()));
drop policy if exists "reviews: owner insert" on public.reviews;
create policy "reviews: owner insert" on public.reviews for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select private.is_owner())
              and private.serviced_my_motorcycle(mechanic_id));

-- activity logs: everyone writes their own entries, admins read them ("Recent changes", report)
drop policy if exists "activity: read" on public.activity_logs;
create policy "activity: read" on public.activity_logs for select to authenticated
  using ((select private.is_admin()));
drop policy if exists "activity: insert own" on public.activity_logs;
create policy "activity: insert own" on public.activity_logs for insert to authenticated
  with check (actor_id = (select auth.uid()));

-- ================================================================ 7. receipt storage
-- Private bucket. New files: "<record_id>/<file name>". Owner of the motorcycle and the
-- recorder (owner or mechanic) can read; only the recorder uploads or removes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "receipts: read own" on storage.objects;      -- v1 policies
drop policy if exists "receipts: upload own" on storage.objects;
drop policy if exists "receipts: delete own" on storage.objects;

drop policy if exists "receipts: read owner or recorder" on storage.objects;
create policy "receipts: read owner or recorder" on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and private.can_read_receipt_object(name));
drop policy if exists "receipts: upload by recorder" on storage.objects;
create policy "receipts: upload by recorder" on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and private.can_write_receipt_object(name));
drop policy if exists "receipts: delete by recorder" on storage.objects;
create policy "receipts: delete by recorder" on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and private.can_write_receipt_object(name));

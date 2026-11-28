-- =====================================================================
-- MotorcycleCare — seed data (run after schema.sql). Safe to run again.
-- Same catalog, intervals, workshops and staff code as the demo data in lib/data/mock_data.dart.
-- Accounts are not seeded: create them in the app (Create Account) or as Admin (Add user).
-- =====================================================================

-- Staff code needed to register an Admin account (Create Account → Admin → Staff code).
insert into public.staff_codes (code, description) values
  ('ADM-2026', 'Demo staff code for registering Admin accounts')
on conflict (code) do update set active = true;

insert into public.workshops (name, address, city, hours, phone) values
  ('Maju Jaya Motor', 'Jl. Raya Bekasi No. 45',    'Jakarta Timur', 'Mon–Sat · 08:00–17:00', '+62 21 4455 6677'),
  ('AHASS Sudirman',  'Jl. Jend. Sudirman No. 12', 'Jakarta Pusat', 'Mon–Sat · 08:00–16:00', '+62 21 5700 1122')
on conflict do nothing;

insert into public.motorcycle_catalog (motorcycle_type, make, model, model_year) values
  ('matic',     'Honda',  'Vario 160',   2023),
  ('matic',     'Honda',  'PCX 160',     2024),
  ('matic',     'Yamaha', 'NMAX 155',    2023),
  ('matic',     'Honda',  'BeAT',        2023),
  ('matic',     'Suzuki', 'Address',     2022),
  ('underbone', 'Honda',  'Supra X 125', 2022),
  ('sport',     'Yamaha', 'R15',         2023)
on conflict (make, model, model_year) do nothing;

insert into public.maintenance_rules
  (catalog_id, component_key, component_name, interval_km, interval_months, source_reference)
select c.catalog_id, t.key, t.name, t.km, t.months, 'Owner''s manual'
from public.motorcycle_catalog c
join (values
  ('matic',     1, 'gear',    'Gear Oil',     4000,  6),
  ('matic',     2, 'engine',  'Engine Oil',   2000,  3),
  ('matic',     3, 'air',     'Air Filter',   8000, 12),
  ('matic',     4, 'spark',   'Spark Plug',   8000, 12),
  ('matic',     5, 'brake',   'Brake Pads',  12000, 12),
  ('matic',     6, 'cvt',     'CVT Belt',    24000, 24),
  ('underbone', 1, 'engine',  'Engine Oil',   2000,  3),
  ('underbone', 2, 'air',     'Air Filter',   8000, 12),
  ('underbone', 3, 'spark',   'Spark Plug',   8000, 12),
  ('underbone', 4, 'chain',   'Drive Chain',  4000,  6),
  ('underbone', 5, 'brake',   'Brake Pads',  12000, 12),
  ('trail',     1, 'engine',  'Engine Oil',   1500,  2),
  ('trail',     2, 'air',     'Air Filter',   3000,  3),
  ('trail',     3, 'spark',   'Spark Plug',   6000, 12),
  ('trail',     4, 'chain',   'Drive Chain',   500,  1),
  ('trail',     5, 'brake',   'Brake Pads',   8000, 12),
  ('sport',     1, 'engine',  'Engine Oil',   3000,  4),
  ('sport',     2, 'air',     'Air Filter',  10000, 12),
  ('sport',     3, 'spark',   'Spark Plug',  10000, 12),
  ('sport',     4, 'chain',   'Drive Chain',  4000,  6),
  ('sport',     5, 'brake',   'Brake Pads',  10000, 12),
  ('sport',     6, 'coolant', 'Coolant',     20000, 24)
) as t(type, ord, key, name, km, months) on t.type = c.motorcycle_type
order by c.catalog_id, t.ord
on conflict (catalog_id, component_key) do nothing;

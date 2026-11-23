-- =====================================================================
-- MotorcycleCare — catalog + maintenance rules
-- Same models and intervals as the "User App Prototype" Figma file.
-- Run after schema.sql. Safe to run again (skips rows that already exist).
-- =====================================================================
insert into public.catalog_models (motorcycle_type, make, model, model_year) values
  ('matic',     'Honda',  'Vario 160',   2023),
  ('matic',     'Honda',  'PCX 160',     2024),
  ('matic',     'Yamaha', 'NMAX 155',    2023),
  ('underbone', 'Honda',  'Supra X 125', 2022),
  ('sport',     'Yamaha', 'R15',         2023)
on conflict (make, model, model_year) do nothing;

insert into public.maintenance_rules
  (catalog_id, component_key, component_name, interval_km, interval_months, source_reference)
select c.id, t.key, t.name, t.km, t.months, 'Owner''s manual'
from public.catalog_models c
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
  ('sport',     1, 'engine',  'Engine Oil',   3000,  4),
  ('sport',     2, 'air',     'Air Filter',  10000, 12),
  ('sport',     3, 'spark',   'Spark Plug',  10000, 12),
  ('sport',     4, 'chain',   'Drive Chain',  4000,  6),
  ('sport',     5, 'brake',   'Brake Pads',  10000, 12),
  ('sport',     6, 'coolant', 'Coolant',     20000, 24)
) as t(type, ord, key, name, km, months) on t.type = c.motorcycle_type
order by c.id, t.ord
on conflict (catalog_id, component_key) do nothing;

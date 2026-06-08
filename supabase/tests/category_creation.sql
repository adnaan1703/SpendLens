begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

insert into auth.users (id)
values
  ('14000000-0000-0000-0000-000000000001'),
  ('14000000-0000-0000-0000-000000000002'),
  ('14000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '24000000-0000-0000-0000-000000000001',
    '14000000-0000-0000-0000-000000000001',
    'Category Owner',
    'category-owner@example.test'
  ),
  (
    '24000000-0000-0000-0000-000000000002',
    '14000000-0000-0000-0000-000000000002',
    'Category Viewer',
    'category-viewer@example.test'
  ),
  (
    '24000000-0000-0000-0000-000000000003',
    '14000000-0000-0000-0000-000000000003',
    'Category Outsider',
    'category-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values (
  '34000000-0000-0000-0000-000000000001',
  'Category Household',
  '24000000-0000-0000-0000-000000000001'
);

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '44000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '44000000-0000-0000-0000-000000000002',
    '34000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000002',
    'viewer'
  );

set local role authenticated;
set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

create temporary table created_category as
select *
from public.create_household_category(
  '34000000-0000-0000-0000-000000000001',
  '  Travel  ',
  ' Flights '
);

select is(
  (select category_name from created_category),
  'Travel',
  'category creation trims and returns category name'
);

select is(
  (select subcategory_name from created_category),
  'Flights',
  'category creation trims and returns subcategory name'
);

select is(
  (
    select count(*)::integer
    from public.categories
    where household_id = '34000000-0000-0000-0000-000000000001'
      and name = 'Travel'
      and not is_system
  ),
  1,
  'category row is persisted for the household'
);

select is(
  (
    select count(*)::integer
    from public.subcategories sc
    join created_category cc
      on cc.category_id = sc.category_id
    where sc.household_id = '34000000-0000-0000-0000-000000000001'
      and sc.name = 'Flights'
      and sc.id = cc.subcategory_id
  ),
  1,
  'subcategory row is linked to the created category'
);

select throws_ok(
  $$
    select *
    from public.create_household_category(
      '34000000-0000-0000-0000-000000000001',
      'travel',
      'Hotels'
    )
  $$,
  'P0001',
  'A category with this name already exists.',
  'duplicate category names are rejected case-insensitively'
);

select throws_ok(
  $$
    select *
    from public.create_household_category(
      '34000000-0000-0000-0000-000000000001',
      '',
      'Hotels'
    )
  $$,
  'P0001',
  'Category name is required.',
  'blank category names are rejected'
);

set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000002';

select throws_ok(
  $$
    select *
    from public.create_household_category(
      '34000000-0000-0000-0000-000000000001',
      'Viewer Category',
      'Blocked'
    )
  $$,
  'P0001',
  'You do not have permission to create categories for this household.',
  'viewers cannot create categories'
);

set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.create_household_category(
      '34000000-0000-0000-0000-000000000001',
      'Outsider Category',
      'Blocked'
    )
  $$,
  'P0001',
  'You do not have permission to create categories for this household.',
  'non-members cannot create categories'
);

select * from finish();

rollback;

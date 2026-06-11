begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(18);

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

insert into public.categories (id, household_id, name, sort_order)
values (
  '34000000-0000-0000-0000-000000000002',
  '34000000-0000-0000-0000-000000000001',
  'Food',
  2
);

insert into public.subcategories (
  id,
  household_id,
  category_id,
  name,
  sort_order
)
values (
  '45000000-0000-0000-0000-000000000002',
  '34000000-0000-0000-0000-000000000001',
  '34000000-0000-0000-0000-000000000002',
  'Dining',
  1
);

create temporary table updated_taxonomy as
select *
from public.update_household_category_taxonomy(
  '34000000-0000-0000-0000-000000000001',
  (select category_id from created_category),
  ' Trips ',
  jsonb_build_array(
    jsonb_build_object(
      'id',
      (select subcategory_id from created_category),
      'name',
      ' Air Travel '
    ),
    jsonb_build_object('name', ' Hotels ')
  )
);

select is(
  (select category_name from updated_taxonomy limit 1),
  'Trips',
  'category update trims and returns renamed category'
);

select is(
  (
    select sc.name
    from public.subcategories sc
    where sc.id = (select subcategory_id from created_category)
  ),
  'Air Travel',
  'existing subcategory is renamed in place'
);

select ok(
  exists (
    select 1
    from updated_taxonomy ut
    join public.subcategories sc
      on sc.id = ut.subcategory_id
    where ut.subcategory_name = 'Hotels'
      and sc.category_id = (select category_id from created_category)
  ),
  'new subcategory is inserted under the edited category'
);

select is(
  (
    select count(*)::integer
    from public.categories c
    where c.id = (select category_id from created_category)
      and c.name = 'Trips'
  ),
  1,
  'category rename preserves the existing category row'
);

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'food',
      jsonb_build_array(
        jsonb_build_object(
          'id',
          (select subcategory_id from created_category),
          'name',
          'Air Travel'
        )
      )
    )
  $$,
  'P0001',
  'A category with this name already exists.',
  'duplicate category names are rejected during update'
);

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'Trips',
      jsonb_build_array(
        jsonb_build_object(
          'id',
          (select subcategory_id from created_category),
          'name',
          'Lodging'
        ),
        jsonb_build_object('name', 'lodging')
      )
    )
  $$,
  'P0001',
  'Subcategory names must be unique within a category.',
  'duplicate subcategory names are rejected within update payloads'
);

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'Trips',
      jsonb_build_array(jsonb_build_object('name', ' '))
    )
  $$,
  'P0001',
  'Subcategory name is required.',
  'blank subcategory names are rejected during update'
);

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'Trips',
      jsonb_build_array(
        jsonb_build_object(
          'id',
          '45000000-0000-0000-0000-000000000002',
          'name',
          'Moved Dining'
        )
      )
    )
  $$,
  'P0001',
  'Subcategory not found for this category.',
  'subcategory ownership is validated during update'
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

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'Viewer Trips',
      jsonb_build_array(
        jsonb_build_object(
          'id',
          (select subcategory_id from created_category),
          'name',
          'Viewer Air Travel'
        )
      )
    )
  $$,
  'P0001',
  'You do not have permission to update categories for this household.',
  'viewers cannot update category taxonomy'
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

select throws_ok(
  $$
    select *
    from public.update_household_category_taxonomy(
      '34000000-0000-0000-0000-000000000001',
      (select category_id from created_category),
      'Outsider Trips',
      jsonb_build_array(
        jsonb_build_object(
          'id',
          (select subcategory_id from created_category),
          'name',
          'Outsider Air Travel'
        )
      )
    )
  $$,
  'P0001',
  'You do not have permission to update categories for this household.',
  'non-members cannot update category taxonomy'
);

select * from finish();

rollback;

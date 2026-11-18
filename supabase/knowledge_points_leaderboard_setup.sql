-- إعداد الإنتاج المعرفي ونقاط الطلاب ولوحة الشرف
-- شغّلي هذا الملف مرة واحدة من Supabase > SQL Editor.

create table if not exists public.student_roster (
  id uuid primary key default gen_random_uuid(),
  student_name text not null,
  class_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint student_roster_name_class_unique unique (student_name, class_name)
);

create table if not exists public.student_points (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_roster(id) on delete cascade,
  points integer not null check (points between 1 and 100),
  reason text not null,
  awarded_at timestamptz not null default now()
);

create table if not exists public.weekly_engagement (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_roster(id) on delete cascade,
  activity_type text not null check (activity_type in ('reading','artwork','challenge','worksheet','resource')),
  source_key text not null,
  created_at timestamptz not null default now(),
  constraint weekly_engagement_once unique (student_id, activity_type, source_key)
);

alter table public.student_roster enable row level security;
alter table public.student_points enable row level security;
alter table public.weekly_engagement enable row level security;

drop policy if exists "Public can view active student roster" on public.student_roster;
create policy "Public can view active student roster" on public.student_roster
for select to anon, authenticated using (active = true);

drop policy if exists "Teacher manages student roster" on public.student_roster;
create policy "Teacher manages student roster" on public.student_roster
for all to authenticated using (public.is_art_teacher()) with check (public.is_art_teacher());

drop policy if exists "Public can view student points" on public.student_points;
create policy "Public can view student points" on public.student_points
for select to anon, authenticated using (true);

drop policy if exists "Teacher manages student points" on public.student_points;
create policy "Teacher manages student points" on public.student_points
for all to authenticated using (public.is_art_teacher()) with check (public.is_art_teacher());

drop policy if exists "Public can view weekly engagement" on public.weekly_engagement;
create policy "Public can view weekly engagement" on public.weekly_engagement
for select to anon, authenticated using (true);

drop policy if exists "Public can record weekly engagement" on public.weekly_engagement;
create policy "Public can record weekly engagement" on public.weekly_engagement
for insert to anon, authenticated with check (
  exists (select 1 from public.student_roster r where r.id = student_id and r.active = true)
);

drop policy if exists "Teacher manages weekly engagement" on public.weekly_engagement;
create policy "Teacher manages weekly engagement" on public.weekly_engagement
for all to authenticated using (public.is_art_teacher()) with check (public.is_art_teacher());

create or replace view public.weekly_honor_roll as
with week_window as (
  select
    (current_date - ((extract(dow from current_date)::int + 3) % 7))::date as week_start
),
counts as (
  select e.student_id, count(*)::int as activity_count
  from public.weekly_engagement e
  cross join week_window w
  where e.created_at >= w.week_start::timestamptz
    and e.created_at < (w.week_start + 7)::timestamptz
  group by e.student_id
)
select
  r.id as student_id,
  r.student_name,
  r.class_name,
  coalesce(c.activity_count, 0) as activity_count,
  dense_rank() over (order by coalesce(c.activity_count, 0) desc) as rank,
  (select week_start from week_window) as week_start
from public.student_roster r
left join counts c on c.student_id = r.id
where r.active = true
order by activity_count desc, r.student_name
limit 10;

grant select on public.weekly_honor_roll to anon, authenticated;

insert into public.site_sections (id, name, icon, description, cards, sort_order)
values
 ('production-knowledge', 'الإنتاج المعرفي', '💡', 'مساحة إثرائية لإضافة النصوص والصور والفيديو والملفات والروابط والمجلدات التعليمية.', '[]'::jsonb, 90),
 ('student-points', 'نقاطي', '⭐', 'تابعوا نقاط الطلاب والطالبات بشفافية، وتُضاف الأسماء والفصول لاحقًا من حساب المعلمة.', '[]'::jsonb, 91),
 ('honor-roll', 'لوحة الشرف', '🏆', 'أفضل عشرة طلاب وطالبات تفاعلًا مع أنشطة المنصة خلال الأسبوع.', '[]'::jsonb, 92)
on conflict (id) do nothing;

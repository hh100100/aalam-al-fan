-- إعداد لوحة التعزيز الأسبوعية في عالم الفن الرقمي
-- شغّلي هذا الملف مرة واحدة في Supabase SQL Editor.

-- يضمن تسجيل تاريخ إضافة كل نقطة جديدة. النقاط القديمة تُستبعد من احتساب الأسبوع
-- حتى لا تُحسب نقاط سابقة على أنها نقاط الأسبوع الحالي.
alter table public.student_points
  add column if not exists created_at timestamptz;

update public.student_points
set created_at = '1970-01-01T00:00:00Z'::timestamptz
where created_at is null;

alter table public.student_points
  alter column created_at set default now(),
  alter column created_at set not null;

-- تُحفظ اللوحة التي تعتمدها المعلمة في سجل مستقل داخل site_sections،
-- وتُتاح قراءتها للطلاب والزوار دون إتاحة تعديلها لهم.
grant select on public.site_sections to anon, authenticated;

drop policy if exists "Public can read weekly boost board" on public.site_sections;
create policy "Public can read weekly boost board"
on public.site_sections
for select
to anon, authenticated
using (id = 'weekly-boost-board');

-- عالم الفن الرقمي: تخزين إجابات الفهم القرائي
-- نفّذي هذا الملف مرة واحدة في Supabase SQL Editor للمشروع المرتبط بالموقع.

create table if not exists public.reading_submissions (
  id uuid primary key default gen_random_uuid(),
  student_name text not null,
  class_name text not null,
  answer_one text not null,
  answer_two text not null,
  created_at timestamptz not null default now(),
  reviewed boolean not null default false
);

alter table public.reading_submissions enable row level security;

drop policy if exists "Anyone can submit reading answers" on public.reading_submissions;
create policy "Anyone can submit reading answers"
on public.reading_submissions
for insert
to anon, authenticated
with check (
  length(trim(student_name)) between 1 and 100
  and length(trim(class_name)) between 1 and 50
  and length(trim(answer_one)) between 1 and 1500
  and length(trim(answer_two)) between 1 and 1500
);

drop policy if exists "Authenticated teacher can view reading answers" on public.reading_submissions;
create policy "Authenticated teacher can view reading answers"
on public.reading_submissions
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists "Authenticated teacher can mark reading answers reviewed" on public.reading_submissions;
create policy "Authenticated teacher can mark reading answers reviewed"
on public.reading_submissions
for update
to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);

grant insert on public.reading_submissions to anon, authenticated;
grant select, update on public.reading_submissions to authenticated;

-- عالم الفن الرقمي: إعداد إرسال ومراجعة الأعمال الفنية
-- نفّذي هذا الملف مرة واحدة في Supabase SQL Editor.

create table if not exists public.gallery_submissions (
  id uuid primary key default gen_random_uuid(),
  student_name text not null check (char_length(student_name) between 1 and 80),
  class_name text not null check (char_length(class_name) between 1 and 40),
  title text not null check (char_length(title) between 1 and 100),
  category text not null check (category in ('weaving','printing','ornament','drawing')),
  storage_path text not null,
  published_path text,
  status text not null default 'pending' check (status in ('pending','revision','private','published')),
  teacher_note text,
  created_at timestamptz not null default now()
);

alter table public.gallery_submissions enable row level security;

-- صلاحية المعلمة تعتمد على role محفوظ في app_metadata من لوحة Supabase.
create or replace function public.is_art_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'teacher', false);
$$;

drop policy if exists "Anyone can submit pending artwork" on public.gallery_submissions;
create policy "Anyone can submit pending artwork"
on public.gallery_submissions for insert to anon, authenticated
with check (
  status = 'pending'
  and published_path is null
  and teacher_note is null
  and storage_path like 'pending/%'
);

drop policy if exists "Public can view approved artworks only" on public.gallery_submissions;
create policy "Public can view approved artworks only"
on public.gallery_submissions for select to anon, authenticated
using (status = 'published');

drop policy if exists "Teacher can view all artwork submissions" on public.gallery_submissions;
create policy "Teacher can view all artwork submissions"
on public.gallery_submissions for select to authenticated
using (public.is_art_teacher());

drop policy if exists "Teacher can moderate artwork submissions" on public.gallery_submissions;
create policy "Teacher can moderate artwork submissions"
on public.gallery_submissions for update to authenticated
using (public.is_art_teacher())
with check (public.is_art_teacher());

drop policy if exists "Teacher can delete artwork submissions" on public.gallery_submissions;
create policy "Teacher can delete artwork submissions"
on public.gallery_submissions for delete to authenticated
using (public.is_art_teacher());

-- ملفات الانتظار خاصة، والملفات المعتمدة فقط تكون في مساحة عامة.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
 ('student-artworks-pending','student-artworks-pending',false,5242880,array['image/jpeg','image/png','image/webp','image/gif']),
 ('student-artworks-public','student-artworks-public',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
 public = excluded.public,
 file_size_limit = excluded.file_size_limit,
 allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Students upload artwork to pending only" on storage.objects;
create policy "Students upload artwork to pending only"
on storage.objects for insert to anon, authenticated
with check (
 bucket_id = 'student-artworks-pending'
 and (storage.foldername(name))[1] = 'pending'
);

drop policy if exists "Teacher reads pending artwork" on storage.objects;
create policy "Teacher reads pending artwork"
on storage.objects for select to authenticated
using (bucket_id = 'student-artworks-pending' and public.is_art_teacher());

drop policy if exists "Teacher removes pending artwork" on storage.objects;
create policy "Teacher removes pending artwork"
on storage.objects for delete to authenticated
using (bucket_id = 'student-artworks-pending' and public.is_art_teacher());

drop policy if exists "Teacher publishes approved artwork" on storage.objects;
create policy "Teacher publishes approved artwork"
on storage.objects for insert to authenticated
with check (bucket_id = 'student-artworks-public' and public.is_art_teacher());

drop policy if exists "Public reads published artwork" on storage.objects;
create policy "Public reads published artwork"
on storage.objects for select to anon, authenticated
using (bucket_id = 'student-artworks-public');

drop policy if exists "Teacher removes published artwork" on storage.objects;
create policy "Teacher removes published artwork"
on storage.objects for delete to authenticated
using (bucket_id = 'student-artworks-public' and public.is_art_teacher());

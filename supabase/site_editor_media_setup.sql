-- إعداد محرر عالم الفن الرقمي (GitHub Pages + Supabase)
-- نفّذي هذا الملف مرة واحدة في Supabase > SQL Editor > New query > Run.

create or replace function public.is_art_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'teacher', false);
$$;

create table if not exists public.site_page_edits (
  section_id text primary key,
  html_content text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.site_page_edits enable row level security;

drop policy if exists "Public can read published page edits" on public.site_page_edits;
create policy "Public can read published page edits"
on public.site_page_edits for select to anon, authenticated
using (true);

drop policy if exists "Teacher manages page edits" on public.site_page_edits;
create policy "Teacher manages page edits"
on public.site_page_edits for all to authenticated
using (public.is_art_teacher())
with check (public.is_art_teacher());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'aalam-site-media',
  'aalam-site-media',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view published site media" on storage.objects;
create policy "Public can view published site media"
on storage.objects for select to anon, authenticated
using (bucket_id = 'aalam-site-media');

drop policy if exists "Teacher uploads site media" on storage.objects;
create policy "Teacher uploads site media"
on storage.objects for insert to authenticated
with check (bucket_id = 'aalam-site-media' and public.is_art_teacher());

drop policy if exists "Teacher updates site media" on storage.objects;
create policy "Teacher updates site media"
on storage.objects for update to authenticated
using (bucket_id = 'aalam-site-media' and public.is_art_teacher())
with check (bucket_id = 'aalam-site-media' and public.is_art_teacher());

drop policy if exists "Teacher deletes site media" on storage.objects;
create policy "Teacher deletes site media"
on storage.objects for delete to authenticated
using (bucket_id = 'aalam-site-media' and public.is_art_teacher());

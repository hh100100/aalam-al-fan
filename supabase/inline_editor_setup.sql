-- إعداد وضع التحرير المباشر لعالم الفن الرقمي
create table if not exists public.site_page_edits (
 section_id text primary key,
 html_content text not null,
 updated_at timestamptz not null default now()
);
alter table public.site_page_edits enable row level security;
drop policy if exists "Public can read published page edits" on public.site_page_edits;
create policy "Public can read published page edits"
on public.site_page_edits for select to anon, authenticated using (true);
drop policy if exists "Teacher manages page edits" on public.site_page_edits;
create policy "Teacher manages page edits"
on public.site_page_edits for all to authenticated
using (public.is_art_teacher())
with check (public.is_art_teacher());

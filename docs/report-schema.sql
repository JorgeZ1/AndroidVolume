create table public.support_reports (
 id uuid primary key,
 category text not null check (category in ('volume','positioning','appearance','ads','crash','other')),
 description text not null check (char_length(description) between 10 and 2000),
 diagnostics jsonb not null default '{}'::jsonb,
 attachment_paths text[] not null default '{}' check (cardinality(attachment_paths) <= 2),
 body_hash text not null check (length(body_hash) = 64),
 status text not null default 'pending' check (status in ('pending','new','in_progress','resolved')),
 created_at timestamptz not null default now()
);
alter table public.support_reports enable row level security;
revoke all on public.support_reports from anon, authenticated;
grant all on public.support_reports to service_role;
create table public.report_daily_quota (
 day date primary key, used integer not null default 0
);
alter table public.report_daily_quota enable row level security;
revoke all on public.report_daily_quota from anon, authenticated;
grant all on public.report_daily_quota to service_role;
create function public.reserve_support_report(p_id uuid, p_hash text, p_category text, p_description text, p_diagnostics jsonb)
returns text language plpgsql security invoker set search_path = public, pg_temp as $$
declare previous public.support_reports; count_value integer;
begin
 perform pg_advisory_xact_lock(hashtext(p_id::text));
 select * into previous from public.support_reports where id = p_id;
 if found then
   if previous.body_hash <> p_hash then return 'conflict'; end if;
   return previous.status;
 end if;
 insert into public.report_daily_quota(day, used) values (current_date, 0) on conflict do nothing;
 update public.report_daily_quota set used = used + 1
 where day = current_date and used < 100 returning used into count_value;
 if not found then return 'limit'; end if;
 delete from public.report_daily_quota where day < current_date - 2;
 insert into public.support_reports(id, body_hash, category, description, diagnostics)
 values (p_id, p_hash, p_category, p_description, p_diagnostics);
 return 'pending';
end;
$$;
revoke all on function public.reserve_support_report(uuid,text,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.reserve_support_report(uuid,text,text,text,jsonb) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values ('report-images','report-images',false,2097152,array['image/jpeg','image/png']);
create policy service_only_reports on public.support_reports for all to service_role using (true) with check (true);
create policy service_only_quota on public.report_daily_quota for all to service_role using (true) with check (true);

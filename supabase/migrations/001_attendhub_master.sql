-- =====================================================================
--  AttendHub  -  MASTER SUPABASE SQL
--  Run the WHOLE file once in: Supabase Dashboard > SQL Editor > New query
--
--  WARNING (destructive): this drops and recreates master_lists,
--  master_students, sessions, session_master_lists and scan_events.
--  Existing lists / sessions / scans are deleted. Logins (auth.users) and
--  the admins table are kept.
--
--  Fixes:
--   * pgp_sym_encrypt / pgp_sym_decrypt "does not exist"  -> no pgcrypto used
--   * column reference "id" is ambiguous                   -> aliased columns
--   * 14,000+ students: paged list loading, indexes, report returned as one
--     JSON value (not cut at the API's 1000-row limit)
--   * roll number not in master list -> recorded as "Scanned student"
--     with roll number and scan date/time
-- =====================================================================

-- ---------- 0. clean old objects ------------------------------------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_session','update_session','end_session','delete_session',
                        'validate_volunteer_session','get_volunteer_session_status',
                        'record_volunteer_scan','record_admin_scan','get_session_report',
                        'get_master_students','import_master_students',
                        'is_approved_admin','_do_scan','_norm_roll')
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end $$;

drop table if exists public.scan_events          cascade;
drop table if exists public.session_master_lists cascade;
drop table if exists public.sessions             cascade;
drop table if exists public.master_students      cascade;
drop table if exists public.master_lists         cascade;

-- ---------- 1. tables -----------------------------------------------
create table if not exists public.admins (
  id          uuid primary key,
  email       text,
  status      text not null default 'pending',
  approved_by text,
  created_at  timestamptz not null default now()
);

create table public.master_lists (
  id         uuid primary key default gen_random_uuid(),
  admin_id   uuid,
  name       text not null,
  created_at timestamptz not null default now()
);

create table public.master_students (
  id             uuid primary key default gen_random_uuid(),
  master_list_id uuid not null references public.master_lists(id) on delete cascade,
  roll_no        text not null,
  student_name   text not null default '',
  department     text,
  category       text not null default 'Aided',
  mobile         text,
  email          text,
  created_at     timestamptz not null default now(),
  constraint master_students_list_roll_uq unique (master_list_id, roll_no)
);
create index master_students_roll_idx on public.master_students (roll_no);

create table public.sessions (
  id                    uuid primary key default gen_random_uuid(),
  admin_id              uuid,
  name                  text not null,
  venue                 text,
  description           text,
  event_date            date not null default current_date,
  status                text not null default 'active',
  share_token           text not null unique
                          default replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-',''),
  allow_duplicate_scans boolean not null default false,
  started_at            timestamptz not null default now(),
  ended_at              timestamptz,
  expires_at            timestamptz not null default (now() + interval '12 hours'),
  encrypted_at          timestamptz
);

create table public.session_master_lists (
  session_id     uuid not null references public.sessions(id)      on delete cascade,
  master_list_id uuid not null references public.master_lists(id)  on delete cascade,
  primary key (session_id, master_list_id)
);

create table public.scan_events (
  id             uuid primary key default gen_random_uuid(),
  session_id     uuid not null references public.sessions(id) on delete cascade,
  roll_no        text not null,
  method         text not null default 'QR Camera',
  added_manually boolean not null default false,
  scanned_by     uuid,
  scanned_at     timestamptz not null default now()
);
create index scan_events_session_roll_idx on public.scan_events (session_id, roll_no);
create index scan_events_session_time_idx on public.scan_events (session_id, scanned_at);

-- ---------- 2. helpers ----------------------------------------------
create or replace function public._norm_roll(p text)
returns text language sql immutable as $$
  select upper(btrim(coalesce(p, '')));
$$;

create or replace function public.is_approved_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a
                 where a.id = auth.uid() and a.status = 'approved');
$$;

-- ---------- 3. row level security -----------------------------------
alter table public.admins              enable row level security;
alter table public.master_lists        enable row level security;
alter table public.master_students     enable row level security;
alter table public.sessions            enable row level security;
alter table public.session_master_lists enable row level security;
alter table public.scan_events         enable row level security;

drop policy if exists admins_select_own   on public.admins;
drop policy if exists admins_insert_own   on public.admins;
drop policy if exists admins_manage       on public.admins;
create policy admins_select_own on public.admins for select to authenticated
  using (id = auth.uid() or public.is_approved_admin());
create policy admins_insert_own on public.admins for insert to authenticated
  with check (id = auth.uid() and status = 'pending');
create policy admins_manage on public.admins for update to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());

-- all approved admins share the data (E-Cell team). Change to
-- "admin_id = auth.uid()" if each admin should only see their own.
create policy master_lists_all on public.master_lists for all to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());
create policy master_students_all on public.master_students for all to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());
create policy sessions_all on public.sessions for all to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());
create policy session_lists_all on public.session_master_lists for all to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());
create policy scan_events_all on public.scan_events for all to authenticated
  using (public.is_approved_admin()) with check (public.is_approved_admin());

-- back-fill: every account that already exists becomes an approved admin.
-- (remove this block if you do not want that)
insert into public.admins (id, email, status, approved_by)
select u.id, u.email, 'approved', 'migration'
from auth.users u
on conflict (id) do update set status = 'approved';

-- ---------- 4. master list functions --------------------------------
create or replace function public.get_master_students(
  p_list_id uuid default null,
  p_query   text default null,
  p_limit   int  default 500,
  p_offset  int  default 0)
returns setof public.master_students
language sql stable security invoker set search_path = public as $$
  select ms.*
  from public.master_students ms
  where (p_list_id is null or ms.master_list_id = p_list_id)
    and (p_query is null or btrim(p_query) = ''
         or ms.roll_no      ilike '%' || btrim(p_query) || '%'
         or ms.student_name ilike '%' || btrim(p_query) || '%'
         or ms.department   ilike '%' || btrim(p_query) || '%'
         or ms.mobile       ilike '%' || btrim(p_query) || '%'
         or ms.email        ilike '%' || btrim(p_query) || '%')
  order by ms.roll_no, ms.id
  limit greatest(p_limit, 1) offset greatest(p_offset, 0);
$$;

-- p_rows = JSON array of {roll_no, student_name, department, category, mobile, email}
-- returns how many NEW students were inserted (existing roll numbers are skipped)
create or replace function public.import_master_students(
  p_list_id uuid,
  p_rows    jsonb)
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.is_approved_admin() then
    raise exception 'Not an approved admin';
  end if;

  with src as (
    select public._norm_roll(x.roll_no)                         as roll_no,
           coalesce(nullif(btrim(x.student_name), ''), 'Unknown') as student_name,
           nullif(btrim(x.department), '')                      as department,
           case when upper(coalesce(x.category,'')) in ('SF','SELF') then 'SF' else 'Aided' end as category,
           nullif(btrim(x.mobile), '')                          as mobile,
           nullif(btrim(x.email), '')                           as email
    from jsonb_to_recordset(p_rows) as x(
           roll_no text, student_name text, department text,
           category text, mobile text, email text)
  ), ins as (
    insert into public.master_students
           (master_list_id, roll_no, student_name, department, category, mobile, email)
    select p_list_id, s.roll_no, s.student_name, s.department, s.category, s.mobile, s.email
    from src s
    where s.roll_no <> ''
    on conflict (master_list_id, roll_no) do nothing
    returning 1
  )
  select count(*) into n from ins;
  return n;
end $$;

-- ---------- 5. session functions ------------------------------------
create or replace function public.create_session(
  p_name                  text,
  p_master_list_ids       uuid[],
  p_venue                 text    default null,
  p_description           text    default null,
  p_event_date            date    default current_date,
  p_duration_hours        numeric default 12,
  p_allow_duplicate_scans boolean default false)
returns public.sessions
language plpgsql security definer set search_path = public as $$
declare s public.sessions;
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  if p_master_list_ids is null or cardinality(p_master_list_ids) = 0 then
    raise exception 'Select at least one saved master list.';
  end if;

  insert into public.sessions (admin_id, name, venue, description, event_date,
                               allow_duplicate_scans, expires_at)
  values (auth.uid(), p_name, p_venue, p_description, coalesce(p_event_date, current_date),
          coalesce(p_allow_duplicate_scans,false),
          now() + make_interval(secs => greatest(coalesce(p_duration_hours,12),0.1) * 3600))
  returning * into s;

  insert into public.session_master_lists (session_id, master_list_id)
  select s.id, x from unnest(p_master_list_ids) as x
  on conflict do nothing;
  return s;
end $$;

create or replace function public.update_session(
  p_session_id            uuid,
  p_name                  text,
  p_master_list_ids       uuid[],
  p_venue                 text    default null,
  p_description           text    default null,
  p_event_date            date    default current_date,
  p_allow_duplicate_scans boolean default false)
returns public.sessions
language plpgsql security definer set search_path = public as $$
declare s public.sessions;
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  if p_master_list_ids is null or cardinality(p_master_list_ids) = 0 then
    raise exception 'A session must keep at least one saved master list.';
  end if;

  update public.sessions ss
     set name = p_name, venue = p_venue, description = p_description,
         event_date = coalesce(p_event_date, ss.event_date),
         allow_duplicate_scans = coalesce(p_allow_duplicate_scans, false)
   where ss.id = p_session_id
   returning * into s;
  if not found then raise exception 'Session not found'; end if;

  delete from public.session_master_lists l where l.session_id = p_session_id;
  insert into public.session_master_lists (session_id, master_list_id)
  select p_session_id, x from unnest(p_master_list_ids) as x
  on conflict do nothing;
  return s;
end $$;

create or replace function public.end_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  update public.sessions ss
     set status = 'ended', ended_at = coalesce(ss.ended_at, now())
   where ss.id = p_session_id;
end $$;

create or replace function public.delete_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  delete from public.sessions ss where ss.id = p_session_id;
end $$;

-- ---------- 6. volunteer link ---------------------------------------
create or replace function public.validate_volunteer_session(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s public.sessions;
begin
  select * into s from public.sessions ss where ss.share_token = btrim(p_token);
  if not found then
    return jsonb_build_object('valid', false, 'reason', 'INVALID_OR_NOT_FOUND');
  end if;
  if s.status <> 'active' or s.expires_at <= now() then
    return jsonb_build_object('valid', false, 'reason', 'SESSION_ENDED');
  end if;
  return jsonb_build_object('valid', true, 'session_id', s.id, 'session_name', s.name,
                            'venue', s.venue, 'expires_at', s.expires_at);
end $$;

create or replace function public.get_volunteer_session_status(p_session_id uuid, p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('active', coalesce(
           (select ss.status = 'active' and ss.expires_at > now()
              from public.sessions ss
             where ss.id = p_session_id and ss.share_token = btrim(p_token)), false));
$$;

-- ---------- 7. scanning ---------------------------------------------
-- status: SUCCESS | ALREADY_CHECKED_IN | NOT_FOUND | SESSION_ENDED
create or replace function public._do_scan(
  p_session_id uuid, p_payload text, p_method text, p_by uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  s     public.sessions;
  v_roll text := public._norm_roll(p_payload);
  st    public.master_students;
  prev  timestamptz;
  v_at  timestamptz := now();
begin
  select * into s from public.sessions ss where ss.id = p_session_id;
  if not found then
    return jsonb_build_object('status','NOT_FOUND','message','Session not found');
  end if;
  if s.status = 'active' and s.expires_at <= now() then
    update public.sessions ss set status='ended', ended_at = coalesce(ss.ended_at, now()) where ss.id = s.id;
    s.status := 'ended';
  end if;
  if s.status <> 'active' then
    return jsonb_build_object('status','SESSION_ENDED','message','Session has ended');
  end if;
  if v_roll = '' then
    return jsonb_build_object('status','NOT_FOUND','message','Empty code');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_session_id::text || v_roll, 0));

  select min(e.scanned_at) into prev
    from public.scan_events e where e.session_id = p_session_id and e.roll_no = v_roll;
  if prev is not null and not s.allow_duplicate_scans then
    return jsonb_build_object('status','ALREADY_CHECKED_IN',
             'message','Already checked in at ' || to_char(prev at time zone 'Asia/Kolkata','DD Mon YYYY HH12:MI:SS AM'),
             'scanned_at', prev);
  end if;

  select ms.* into st
    from public.master_students ms
    join public.session_master_lists l on l.master_list_id = ms.master_list_id
   where l.session_id = p_session_id and ms.roll_no = v_roll
   limit 1;

  insert into public.scan_events (session_id, roll_no, method, scanned_by, scanned_at)
  values (p_session_id, v_roll, coalesce(p_method,'QR Camera'), p_by, v_at);

  if st.id is not null then
    return jsonb_build_object('status','SUCCESS',
             'message', st.student_name || coalesce(' (' || st.department || ')',''),
             'scanned_at', v_at);
  end if;
  return jsonb_build_object('status','SUCCESS',
           'message','Scanned student (not in master list)',
           'scanned_at', v_at);
end $$;

create or replace function public.record_admin_scan(p_session_id uuid, p_scanned_payload text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  return public._do_scan(p_session_id, p_scanned_payload, 'QR Camera', auth.uid());
end $$;

create or replace function public.record_volunteer_scan(
  p_session_id uuid, p_token text, p_scanned_payload text, p_method text default 'QR Camera')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.sessions ss
                 where ss.id = p_session_id and ss.share_token = btrim(p_token)) then
    return jsonb_build_object('status','NOT_FOUND','message','Invalid scan link');
  end if;
  return public._do_scan(p_session_id, p_scanned_payload, p_method, null);
end $$;

-- ---------- 8. report ------------------------------------------------
-- Returns ONE jsonb array (so the API's 1000-row limit does not cut 14,000+ rows).
-- status = 'Attended' | 'Absent'. Roll numbers not in the master list appear as
-- "Scanned student" with category 'Unlisted'.
create or replace function public.get_session_report(p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;

  with first_scan as (
    select distinct on (e.roll_no) e.roll_no, e.id as attendance_id, e.scanned_at
      from public.scan_events e
     where e.session_id = p_session_id
     order by e.roll_no, e.scanned_at, e.id
  ), roster as (
    select distinct on (ms.roll_no)
           ms.roll_no, ms.student_name, ms.department, ms.category, ms.mobile, ms.email
      from public.master_students ms
      join public.session_master_lists l on l.master_list_id = ms.master_list_id
     where l.session_id = p_session_id
     order by ms.roll_no, ms.created_at
  ), combined as (
    select r.roll_no, r.student_name, r.department, r.category, r.mobile, r.email,
           case when f.roll_no is null then 'Absent' else 'Attended' end as status,
           f.scanned_at, f.attendance_id
      from roster r left join first_scan f on f.roll_no = r.roll_no
    union all
    select f.roll_no, 'Scanned student', null, 'Unlisted', null, null,
           'Attended', f.scanned_at, f.attendance_id
      from first_scan f
     where not exists (select 1 from roster r where r.roll_no = f.roll_no)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'roll_no', c.roll_no, 'student_name', c.student_name,
           'department', c.department, 'category', c.category,
           'mobile', c.mobile, 'email', c.email, 'status', c.status,
           'scanned_at', c.scanned_at, 'attendance_id', c.attendance_id::text)
         order by c.roll_no), '[]'::jsonb)
    into result
    from combined c;
  return result;
end $$;

-- ---------- 9. permissions ------------------------------------------
revoke all on function public.get_master_students(uuid,text,int,int)            from public, anon;
revoke all on function public.import_master_students(uuid,jsonb)                from public, anon;
revoke all on function public.create_session(text,uuid[],text,text,date,numeric,boolean)        from public, anon;
revoke all on function public.update_session(uuid,text,uuid[],text,text,date,boolean)           from public, anon;
revoke all on function public.end_session(uuid)                                 from public, anon;
revoke all on function public.delete_session(uuid)                              from public, anon;
revoke all on function public.record_admin_scan(uuid,text)                      from public, anon;
revoke all on function public.get_session_report(uuid)                          from public, anon;
revoke all on function public._do_scan(uuid,text,text,uuid)                     from public, anon, authenticated;
revoke all on function public._norm_roll(text)                                  from public;
revoke all on function public.is_approved_admin()                               from public, anon;

grant execute on function public.get_master_students(uuid,text,int,int)         to authenticated;
grant execute on function public.import_master_students(uuid,jsonb)            to authenticated;
grant execute on function public.create_session(text,uuid[],text,text,date,numeric,boolean)    to authenticated;
grant execute on function public.update_session(uuid,text,uuid[],text,text,date,boolean)       to authenticated;
grant execute on function public.end_session(uuid)                              to authenticated;
grant execute on function public.delete_session(uuid)                           to authenticated;
grant execute on function public.record_admin_scan(uuid,text)                   to authenticated;
grant execute on function public.get_session_report(uuid)                       to authenticated;
grant execute on function public._norm_roll(text)                               to authenticated;
grant execute on function public.is_approved_admin()                            to authenticated;

-- volunteer (no login) functions
grant execute on function public.validate_volunteer_session(text)               to anon, authenticated;
grant execute on function public.get_volunteer_session_status(uuid,text)        to anon, authenticated;
grant execute on function public.record_volunteer_scan(uuid,text,text,text)     to anon, authenticated;

-- make PostgREST pick up the new functions immediately
notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------
-- FIRST ADMIN: if you create a NEW account later it starts as 'pending'.
-- Approve it with (put the real email):
--   update public.admins set status = 'approved' where email = 'you@example.com';
-- ---------------------------------------------------------------------

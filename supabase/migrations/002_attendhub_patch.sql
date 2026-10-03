-- =====================================================================
--  AttendHub - PATCH v2 (non-destructive, safe to run any time)
--  Run in Supabase > SQL Editor. Does NOT delete lists, students,
--  sessions or scans. Run attendhub_master.sql FIRST only if you have
--  never run it (it wipes data); otherwise run only this file.
-- =====================================================================

-- 1. Supabase "Security Definer View" CRITICAL warning.
--    The app never reads this view (it is not referenced in the build),
--    so remove it.
drop view if exists public.master_list_entry_counts;

-- 2. Scan result: when the roll number IS in the master list, return all
--    its details; when it is NOT, return "Scanned student" + roll no +
--    scan date/time (IST). The app shows `message`; the extra JSON keys
--    are there for the next app version.
create or replace function public._do_scan(
  p_session_id uuid, p_payload text, p_method text, p_by uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  s      public.sessions;
  v_roll text := public._norm_roll(p_payload);
  st     public.master_students;
  prev   timestamptz;
  v_at   timestamptz := now();
  v_time text;
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

  -- look the student up first (used by both the duplicate and success replies)
  select ms.* into st
    from public.master_students ms
    join public.session_master_lists l on l.master_list_id = ms.master_list_id
   where l.session_id = p_session_id and ms.roll_no = v_roll
   limit 1;

  select min(e.scanned_at) into prev
    from public.scan_events e where e.session_id = p_session_id and e.roll_no = v_roll;
  if prev is not null and not s.allow_duplicate_scans then
    return jsonb_build_object('status','ALREADY_CHECKED_IN',
             'message', v_roll || ' already checked in at '
                        || to_char(prev at time zone 'Asia/Kolkata','DD Mon YYYY HH12:MI:SS AM'),
             'roll_no', v_roll,
             'student_name', st.student_name,
             'scanned_at', prev);
  end if;

  insert into public.scan_events (session_id, roll_no, method, scanned_by, scanned_at)
  values (p_session_id, v_roll, coalesce(p_method,'QR Camera'), p_by, v_at);

  v_time := to_char(v_at at time zone 'Asia/Kolkata','DD Mon YYYY HH12:MI:SS AM');

  if st.id is not null then
    return jsonb_build_object('status','SUCCESS',
      'message', v_roll || ' | ' || st.student_name
                 || coalesce(' | ' || st.department, '')
                 || ' | ' || st.category
                 || coalesce(' | ' || st.mobile, '')
                 || ' | ' || v_time,
      'roll_no', v_roll, 'student_name', st.student_name,
      'department', st.department, 'category', st.category,
      'mobile', st.mobile, 'email', st.email,
      'listed', true, 'scanned_at', v_at);
  end if;

  return jsonb_build_object('status','SUCCESS',
    'message', 'Scanned student | ' || v_roll || ' | ' || v_time,
    'roll_no', v_roll, 'student_name', 'Scanned student',
    'listed', false, 'scanned_at', v_at);
end $$;

revoke all on function public._do_scan(uuid,text,text,uuid) from public, anon, authenticated;


-- 3. Counts without loading rows (fast for 14,000+ students).
create or replace function public.get_master_list_counts()
returns table (master_list_id uuid, student_count bigint)
language sql stable security invoker set search_path = public as $$
  select ms.master_list_id, count(*)::bigint
    from public.master_students ms
   group by ms.master_list_id;
$$;

create or replace function public.count_master_students(
  p_list_id uuid, p_query text default null)
returns bigint
language sql stable security invoker set search_path = public as $$
  select count(*)::bigint
    from public.master_students ms
   where ms.master_list_id = p_list_id
     and (p_query is null or btrim(p_query) = ''
          or ms.roll_no      ilike '%' || btrim(p_query) || '%'
          or ms.student_name ilike '%' || btrim(p_query) || '%'
          or ms.department   ilike '%' || btrim(p_query) || '%'
          or ms.mobile       ilike '%' || btrim(p_query) || '%'
          or ms.email        ilike '%' || btrim(p_query) || '%');
$$;

-- 4. Admin scan can now record how it was entered (QR Camera / Manual).
drop function if exists public.record_admin_scan(uuid, text);
create or replace function public.record_admin_scan(
  p_session_id uuid, p_scanned_payload text, p_method text default 'QR Camera')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_approved_admin() then raise exception 'Not an approved admin'; end if;
  return public._do_scan(p_session_id, p_scanned_payload,
                         coalesce(nullif(btrim(p_method), ''), 'QR Camera'), auth.uid());
end $$;

revoke all on function public.record_admin_scan(uuid,text,text)       from public, anon;
revoke all on function public.get_master_list_counts()                from public, anon;
revoke all on function public.count_master_students(uuid,text)        from public, anon;
grant execute on function public.record_admin_scan(uuid,text,text)    to authenticated;
grant execute on function public.get_master_list_counts()             to authenticated;
grant execute on function public.count_master_students(uuid,text)     to authenticated;

notify pgrst, 'reload schema';

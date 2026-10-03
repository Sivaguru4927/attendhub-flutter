-- =====================================================================
--  AttendHub - re-open a session (safe to run any time, deletes nothing)
--  Run in Supabase > SQL Editor AFTER the master and patch files.
-- =====================================================================
create or replace function public.reopen_session(
  p_session_id     uuid,
  p_duration_hours numeric default 8)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_approved_admin() then
    raise exception 'Not an approved admin';
  end if;

  update public.sessions ss
     set status     = 'active',
         ended_at   = null,
         expires_at = now() + make_interval(
                        secs => greatest(coalesce(p_duration_hours, 8), 0.1) * 3600)
   where ss.id = p_session_id;

  if not found then
    raise exception 'Session not found';
  end if;
end $$;

revoke all on function public.reopen_session(uuid, numeric) from public, anon;
grant execute on function public.reopen_session(uuid, numeric) to authenticated;

-- (delete_session already exists from the master file; make sure it is allowed)
grant execute on function public.delete_session(uuid) to authenticated;

notify pgrst, 'reload schema';

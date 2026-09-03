-- Keep unpublished drafts confined to the dedicated Drafts dashboard tab.

create or replace function public.dashboard_jobs(p_organization_id uuid, p_tab text default 'open')
returns table(
  id uuid,
  title text,
  listing_summary text,
  status public.job_status,
  visibility public.job_visibility,
  sensitivity public.job_sensitivity,
  effort public.job_effort,
  required_tools text[],
  requester_name text,
  preferred_model text,
  deadline timestamptz,
  claim_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a public.memberships;
begin
  a := private.actor(p_organization_id);
  if a.id is null then raise exception 'not authorized'; end if;
  return query
  select j.id, j.title, j.listing_summary, j.status, j.visibility, j.sensitivity,
    j.effort, j.required_tools, coalesce(requester.display_name, 'Lab member'),
    j.preferred_model_text, j.deadline,
    case when j.assigned_to_membership_id = a.id then j.claim_expires_at end
  from public.jobs j
  join public.memberships requester
    on requester.organization_id = j.organization_id
    and requester.id = j.created_by_membership_id
  where j.organization_id = p_organization_id
    and not j.deletion_pending
    and case p_tab
      when 'drafts' then j.status = 'draft'
        and (j.created_by_membership_id = a.id or a.role = 'admin')
      when 'requests' then j.created_by_membership_id = a.id and j.status <> 'draft'
      when 'claimed' then (
        (j.assigned_to_membership_id = a.id and j.claim_expires_at > now())
        or (j.status = 'submitted' and j.requester_action_at is null and exists (
          select 1 from public.submissions s
          where s.id = (
            select latest.id from public.submissions latest
            where latest.job_id = j.id and latest.status = 'submitted'
            order by latest.revision_number desc, latest.submitted_at desc limit 1
          )
            and s.submitted_by_membership_id = a.id
            and s.edit_locked_at is null
        ))
      )
      when 'review' then j.created_by_membership_id = a.id and j.status = 'submitted'
      when 'completed' then j.status in ('accepted', 'cancelled')
      else j.status in ('open', 'claimed', 'revision_requested')
    end
  order by j.created_at desc;
end
$$;

revoke all on function public.dashboard_jobs(uuid, text)
  from public, anon, authenticated;
grant execute on function public.dashboard_jobs(uuid, text)
  to authenticated;

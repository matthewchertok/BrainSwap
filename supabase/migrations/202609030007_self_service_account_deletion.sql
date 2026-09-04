-- Self-service account deletion is Storage-first and retryable. Shared job and
-- submission history is retained under an anonymous membership tombstone, but
-- the user's profile, invitations, private files, sessions, and Auth identity
-- are removed.

alter table public.memberships
  add column if not exists account_deletion_started_at timestamptz,
  add column if not exists deleted_at timestamptz;

alter table public.memberships
  drop constraint if exists memberships_deleted_state_consistent,
  add constraint memberships_deleted_state_consistent check (
    deleted_at is null
    or (
      not active
      and user_id is null
      and claimed_user_id is null
      and account_deletion_started_at is null
    )
  ) not valid;

alter table public.memberships
  validate constraint memberships_deleted_state_consistent;

-- Once the manifest phase starts, keep ordinary reads available so a failed
-- Storage request can be retried from the profile page, but freeze every
-- mutation that uses the project's locked actor boundary.
create or replace function private.locked_actor(p_org uuid)
returns public.memberships
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  a public.memberships;
begin
  select * into a
  from public.memberships m
  where m.organization_id = p_org
    and m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active
    and m.account_deletion_started_at is null
    and m.deleted_at is null
  for key share;
  return a;
end
$$;

create or replace function private.account_deletion_started()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.claimed_user_id = auth.uid()
      and m.account_deletion_started_at is not null
      and m.deleted_at is null
  )
$$;

create or replace function private.can_delete_account_storage_object(
  p_bucket_id text,
  p_storage_path text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.account_deletion_started() and (
    (
      p_bucket_id = 'profile-photos'
      and exists (
        select 1
        from public.profile_photos p
        join public.memberships m
          on m.organization_id = p.organization_id and m.id = p.membership_id
        where p.storage_path = p_storage_path
          and m.user_id = auth.uid()
          and m.claimed_user_id = auth.uid()
          and m.account_deletion_started_at is not null
      )
    )
    or (
      p_bucket_id = 'job-files'
      and (
        exists (
          select 1
          from public.job_files f
          join public.memberships m
            on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
          where f.storage_path = p_storage_path
            and m.user_id = auth.uid()
            and m.claimed_user_id = auth.uid()
            and m.account_deletion_started_at is not null
        )
        or exists (
          select 1
          from public.submission_files f
          join public.memberships m
            on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
          where f.storage_path = p_storage_path
            and m.user_id = auth.uid()
            and m.claimed_user_id = auth.uid()
            and m.account_deletion_started_at is not null
        )
        or exists (
          -- A draft belongs only to its requester. Include any exact-prefix
          -- orphan left by an interrupted upload before deleting that draft.
          select 1
          from public.jobs j
          join public.memberships m
            on m.organization_id = j.organization_id and m.id = j.created_by_membership_id
          where j.status = 'draft'
            and p_storage_path like (j.organization_id::text || '/' || j.id::text || '/%')
            and m.user_id = auth.uid()
            and m.claimed_user_id = auth.uid()
            and m.account_deletion_started_at is not null
        )
      )
    )
  )
$$;

create or replace function public.begin_account_deletion()
returns table(bucket_id text, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  select lower(btrim(u.email)) into v_email
  from auth.users u
  where u.id = v_user_id and u.email_confirmed_at is not null;
  if v_email is null then
    raise exception 'verified account required';
  end if;
  if not exists (
    select 1 from public.memberships m
    where m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and m.active
      and m.deleted_at is null
  ) then
    raise exception 'active membership required';
  end if;

  -- Serialize with all admin lifecycle changes in the user's organizations.
  perform 1
  from public.organizations o
  where exists (
    select 1 from public.memberships m
    where m.organization_id = o.id
      and (
        (m.user_id = v_user_id and m.claimed_user_id = v_user_id)
        or (m.user_id is null and m.invited_email = v_email)
      )
  )
  order by o.id
  for update;

  if exists (
    select 1
    from public.memberships target
    where target.user_id = v_user_id
      and target.claimed_user_id = v_user_id
      and target.active
      and target.role = 'admin'
      and target.deleted_at is null
      and not exists (
        select 1
        from public.memberships other
        where other.organization_id = target.organization_id
          and other.id <> target.id
          and other.active
          and other.role = 'admin'
          and other.user_id is not null
          and other.claimed_user_id = other.user_id
          and other.deleted_at is null
      )
  ) then
    raise exception 'transfer administrator role before deleting account';
  end if;

  update public.memberships m
  set account_deletion_started_at = coalesce(m.account_deletion_started_at, now()),
      updated_at = now()
  where m.user_id = v_user_id
    and m.claimed_user_id = v_user_id
    and m.deleted_at is null;

  update public.profile_photos p
  set cleanup_started_at = coalesce(p.cleanup_started_at, now())
  where exists (
    select 1 from public.memberships m
    where m.organization_id = p.organization_id
      and m.id = p.membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and m.account_deletion_started_at is not null
  );

  update public.job_files f
  set cleanup_started_at = coalesce(f.cleanup_started_at, now())
  where exists (
    select 1 from public.memberships m
    where m.organization_id = f.organization_id
      and m.id = f.uploaded_by_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and m.account_deletion_started_at is not null
  );

  update public.submission_files f
  set cleanup_started_at = coalesce(f.cleanup_started_at, now())
  where exists (
    select 1 from public.memberships m
    where m.organization_id = f.organization_id
      and m.id = f.uploaded_by_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and m.account_deletion_started_at is not null
  );

  insert into public.audit_events(organization_id, actor_membership_id, event_type)
  select m.organization_id, m.id, 'account_deletion_started'
  from public.memberships m
  where m.user_id = v_user_id
    and m.claimed_user_id = v_user_id
    and m.account_deletion_started_at is not null
    and not exists (
      select 1 from public.audit_events e
      where e.organization_id = m.organization_id
        and e.actor_membership_id = m.id
        and e.event_type = 'account_deletion_started'
    );

  return query
  select 'profile-photos'::text, p.storage_path
  from public.profile_photos p
  join public.memberships m
    on m.organization_id = p.organization_id and m.id = p.membership_id
  where m.user_id = v_user_id and m.claimed_user_id = v_user_id
  union
  select 'job-files'::text, f.storage_path
  from public.job_files f
  join public.memberships m
    on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
  where m.user_id = v_user_id and m.claimed_user_id = v_user_id
  union
  select 'job-files'::text, f.storage_path
  from public.submission_files f
  join public.memberships m
    on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
  where m.user_id = v_user_id and m.claimed_user_id = v_user_id
  union
  select o.bucket_id, o.name
  from storage.objects o
  where o.owner_id = v_user_id::text
  union
  select o.bucket_id, o.name
  from storage.objects o
  join public.jobs j
    on o.bucket_id = 'job-files'
   and o.name like (j.organization_id::text || '/' || j.id::text || '/%')
  join public.memberships m
    on m.organization_id = j.organization_id and m.id = j.created_by_membership_id
  where j.status = 'draft'
    and m.user_id = v_user_id
    and m.claimed_user_id = v_user_id;
end
$$;

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  select lower(btrim(u.email)) into v_email
  from auth.users u
  where u.id = v_user_id and u.email_confirmed_at is not null
  for update;
  if v_email is null then
    raise exception 'verified account required';
  end if;

  perform 1
  from public.organizations o
  where exists (
    select 1 from public.memberships m
    where m.organization_id = o.id
      and (
        (m.user_id = v_user_id and m.claimed_user_id = v_user_id)
        or (m.user_id is null and m.invited_email = v_email)
      )
  )
  order by o.id
  for update;

  -- Workflow RPCs lock a job before taking a membership key-share lock. Match
  -- that order across every job the departing user can still mutate, then lock
  -- memberships, so account deletion cannot deadlock an in-flight workflow or
  -- miss an upload authorized just before finalization.
  perform 1
  from public.jobs j
  where exists (
    select 1 from public.memberships m
    where m.organization_id = j.organization_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and (
        m.id = j.created_by_membership_id
        or m.id = j.assigned_to_membership_id
        or exists (
          select 1 from public.submissions s
          where s.job_id = j.id and s.submitted_by_membership_id = m.id
        )
      )
  )
  order by j.id
  for update;

  perform 1
  from public.memberships m
  where m.user_id = v_user_id or (m.user_id is null and m.invited_email = v_email)
  order by m.organization_id, m.id
  for update;

  if not exists (
    select 1 from public.memberships m
    where m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
      and m.account_deletion_started_at is not null
      and m.deleted_at is null
  ) then
    raise exception 'account deletion has not started';
  end if;

  if exists (
    select 1
    from public.memberships target
    where target.user_id = v_user_id
      and target.claimed_user_id = v_user_id
      and target.active
      and target.role = 'admin'
      and target.deleted_at is null
      and not exists (
        select 1
        from public.memberships other
        where other.organization_id = target.organization_id
          and other.id <> target.id
          and other.active
          and other.role = 'admin'
          and other.user_id is not null
          and other.claimed_user_id = other.user_id
          and other.deleted_at is null
      )
  ) then
    raise exception 'transfer administrator role before deleting account';
  end if;

  if exists (select 1 from storage.objects o where o.owner_id = v_user_id::text)
    or exists (
      select 1
      from storage.objects o
      join public.profile_photos p
        on o.bucket_id = 'profile-photos' and o.name = p.storage_path
      join public.memberships m
        on m.organization_id = p.organization_id and m.id = p.membership_id
      where m.user_id = v_user_id and m.claimed_user_id = v_user_id
    )
    or exists (
      select 1
      from storage.objects o
      join public.job_files f
        on o.bucket_id = 'job-files' and o.name = f.storage_path
      join public.memberships m
        on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
      where m.user_id = v_user_id and m.claimed_user_id = v_user_id
    )
    or exists (
      select 1
      from storage.objects o
      join public.submission_files f
        on o.bucket_id = 'job-files' and o.name = f.storage_path
      join public.memberships m
        on m.organization_id = f.organization_id and m.id = f.uploaded_by_membership_id
      where m.user_id = v_user_id and m.claimed_user_id = v_user_id
    )
    or exists (
      select 1
      from storage.objects o
      join public.jobs j
        on o.bucket_id = 'job-files'
       and o.name like (j.organization_id::text || '/' || j.id::text || '/%')
      join public.memberships m
        on m.organization_id = j.organization_id and m.id = j.created_by_membership_id
      where j.status = 'draft'
        and m.user_id = v_user_id
        and m.claimed_user_id = v_user_id
    )
  then
    raise exception 'storage cleanup required';
  end if;

  delete from public.profile_photos p
  where exists (
    select 1 from public.memberships m
    where m.organization_id = p.organization_id
      and m.id = p.membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  delete from public.job_files f
  where exists (
    select 1 from public.memberships m
    where m.organization_id = f.organization_id
      and m.id = f.uploaded_by_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  delete from public.submission_files f
  where exists (
    select 1 from public.memberships m
    where m.organization_id = f.organization_id
      and m.id = f.uploaded_by_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  delete from public.notifications n
  where exists (
    select 1 from public.memberships m
    where m.organization_id = n.organization_id
      and m.id = n.recipient_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  delete from public.member_models mm
  where exists (
    select 1 from public.memberships m
    where m.organization_id = mm.organization_id
      and m.id = mm.membership_id
      and (
        (m.user_id = v_user_id and m.claimed_user_id = v_user_id)
        or (m.user_id is null and m.invited_email = v_email)
      )
  );

  -- Preserve shared history, but release work that can no longer be completed
  -- by or reviewed by the departing user.
  update public.jobs j
  set status = case when j.status = 'claimed' then 'open'::public.job_status else j.status end,
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      updated_at = now()
  where exists (
    select 1 from public.memberships m
    where m.organization_id = j.organization_id
      and m.id = j.assigned_to_membership_id
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  update public.jobs j
  set status = 'cancelled',
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      updated_at = now()
  where j.status not in ('draft', 'accepted', 'cancelled')
    and exists (
      select 1 from public.memberships m
      where m.organization_id = j.organization_id
        and m.id = j.created_by_membership_id
        and m.user_id = v_user_id
        and m.claimed_user_id = v_user_id
    );

  -- Detach any unusual follow-up before removing a private draft. Published
  -- children are retained rather than cascading away shared work.
  update public.jobs child
  set parent_job_id = null, updated_at = now()
  where child.parent_job_id in (
    select draft.id
    from public.jobs draft
    join public.memberships m
      on m.organization_id = draft.organization_id and m.id = draft.created_by_membership_id
    where draft.status = 'draft'
      and m.user_id = v_user_id
      and m.claimed_user_id = v_user_id
  );

  delete from public.jobs draft
  where draft.status = 'draft'
    and exists (
      select 1 from public.memberships m
      where m.organization_id = draft.organization_id
        and m.id = draft.created_by_membership_id
        and m.user_id = v_user_id
        and m.claimed_user_id = v_user_id
    );

  insert into public.audit_events(organization_id, actor_membership_id, event_type)
  select m.organization_id, m.id, 'account_deleted'
  from public.memberships m
  where m.user_id = v_user_id and m.claimed_user_id = v_user_id;

  update public.memberships m
  set invited_email = 'deleted+' || replace(m.id::text, '-', '') || '@deleted.invalid',
      display_name = 'Deleted user',
      bio = null,
      role = 'member',
      active = false,
      capabilities = '{}'::text[],
      notification_preferences = '{"new_matching_jobs":false}'::jsonb,
      user_id = null,
      claimed_user_id = null,
      claimed_at = null,
      account_deletion_started_at = null,
      deleted_at = now(),
      updated_at = now()
  where (m.user_id = v_user_id and m.claimed_user_id = v_user_id)
    or (m.user_id is null and m.invited_email = v_email);

  delete from auth.users u where u.id = v_user_id;
  if not found then
    raise exception 'account deletion failed';
  end if;
end
$$;

-- Account deletion may remove only exact paths tied to the caller's deletion
-- manifest, plus caller-owned orphan objects. Normal file permissions remain
-- unchanged.
drop policy if exists authorized_download on storage.objects;
create policy authorized_download on storage.objects
for select to authenticated
using (
  bucket_id = 'job-files'
  and (
    (
      private.can_storage_download(name)
      and storage.allow_any_operation(array[
        'storage.object.get_authenticated',
        'object.get_authenticated_info',
        'object.head_authenticated_info'
      ])
    )
    or (
      (
        private.can_storage_delete(name)
        or private.can_delete_account_storage_object(bucket_id, name)
        or (private.account_deletion_started() and owner_id = auth.uid()::text)
      )
      and storage.allow_any_operation(array[
        'storage.object.delete',
        'storage.object.delete_many'
      ])
    )
  )
);

drop policy if exists authorized_delete on storage.objects;
create policy authorized_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'job-files'
  and (
    private.can_storage_delete(name)
    or private.can_delete_account_storage_object(bucket_id, name)
    or (private.account_deletion_started() and owner_id = auth.uid()::text)
  )
);

drop policy if exists authorized_profile_photo_download on storage.objects;
create policy authorized_profile_photo_download on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-photos'
  and (
    (
      private.can_profile_photo_storage_download(name)
      and storage.allow_any_operation(array[
        'storage.object.get_authenticated',
        'object.get_authenticated_info',
        'object.head_authenticated_info'
      ])
    )
    or (
      (
        private.can_profile_photo_storage_delete(name)
        or private.can_delete_account_storage_object(bucket_id, name)
        or (private.account_deletion_started() and owner_id = auth.uid()::text)
      )
      and storage.allow_any_operation(array[
        'storage.object.delete', 'storage.object.delete_many'
      ])
    )
  )
);

drop policy if exists authorized_profile_photo_delete on storage.objects;
create policy authorized_profile_photo_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-photos'
  and (
    private.can_profile_photo_storage_delete(name)
    or private.can_delete_account_storage_object(bucket_id, name)
    or (private.account_deletion_started() and owner_id = auth.uid()::text)
  )
);

create or replace function public.admin_memberships(p_organization_id uuid)
returns table(
  id uuid,
  invited_email text,
  display_name text,
  role public.member_role,
  active boolean,
  claimed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
begin
  a := private.actor(p_organization_id);
  if a.id is null or a.role <> 'admin' then
    raise exception 'administrator access required';
  end if;
  return query
  select m.id, m.invited_email, m.display_name, m.role, m.active,
    m.claimed_user_id is not null
  from public.memberships m
  where m.organization_id = p_organization_id
    and m.deleted_at is null
  order by lower(coalesce(m.display_name, m.invited_email));
end
$$;

revoke all on function private.account_deletion_started(),
  private.can_delete_account_storage_object(text, text)
from public, anon, authenticated;
grant execute on function private.account_deletion_started(),
  private.can_delete_account_storage_object(text, text)
to authenticated;

revoke all on function public.begin_account_deletion(),
  public.delete_own_account()
from public, anon, authenticated;
grant execute on function public.begin_account_deletion(),
  public.delete_own_account()
to authenticated;

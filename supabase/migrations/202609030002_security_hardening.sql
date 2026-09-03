-- Security hardening for the initial BrainSwap schema.
-- This migration is intentionally additive so it can be applied to an existing v0.1 database.

alter table public.memberships
  add column if not exists claimed_user_id uuid;

update public.memberships
set claimed_user_id = user_id
where claimed_user_id is null and user_id is not null;

alter table public.jobs
  add column if not exists deletion_pending boolean not null default false,
  add column if not exists deletion_started_at timestamptz;

-- The original cancel RPC allowed an unpublished draft to become a broadly
-- visible cancelled row. Restore those legacy rows to their private draft state.
update public.jobs
set status = 'draft', updated_at = now()
where status = 'cancelled' and published_at is null;

update public.jobs
set claimed_at = null
where assigned_to_membership_id is null and claimed_at is not null;

alter table public.job_files
  add column if not exists cleanup_started_at timestamptz;

alter table public.submission_files
  add column if not exists cleanup_started_at timestamptz;

alter table public.job_context_items
  add column if not exists organization_id uuid;

update public.job_context_items c
set organization_id = j.organization_id
from public.jobs j
where j.id = c.job_id and c.organization_id is null;

alter table public.job_context_items
  alter column organization_id set not null;

alter table public.revision_requests
  add column if not exists organization_id uuid;

update public.revision_requests r
set organization_id = j.organization_id
from public.jobs j
where j.id = r.job_id and r.organization_id is null;

alter table public.revision_requests
  alter column organization_id set not null;

create or replace function private.valid_text_array(
  p_values text[],
  p_max_items integer,
  p_max_length integer
) returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select p_values is not null
    and cardinality(p_values) <= p_max_items
    and not exists (
      select 1
      from unnest(p_values) as v(value)
      where v.value is null
        or length(btrim(v.value)) = 0
        or length(v.value) > p_max_length
    )
$$;

create or replace function private.valid_job_tools(p_values text[])
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select private.valid_text_array(p_values, 7, 80)
    and p_values <@ array[
      'Web access', 'Deep research', 'Code execution', 'Image understanding',
      'PDF understanding', 'File generation', 'Other'
    ]::text[]
    and cardinality(p_values) = (select count(distinct x) from unnest(p_values) as x)
$$;

create or replace function private.valid_capabilities(p_values text[])
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select private.valid_text_array(p_values, 6, 80)
    and p_values <@ array[
      'Web access', 'Deep research', 'Code execution', 'Image understanding',
      'PDF understanding', 'File generation'
    ]::text[]
    and cardinality(p_values) = (select count(distinct x) from unnest(p_values) as x)
$$;

create or replace function private.valid_https_url(p_url text)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_authority text;
  v_host text;
  v_port text;
  v_octet text;
begin
  if p_url is null
    or length(p_url) not between 9 and 2048
    or p_url <> btrim(p_url)
    or p_url ~ '[[:cntrl:][:space:]]'
    or p_url !~ '^https://'
  then
    return false;
  end if;

  v_authority := substring(p_url from '^https://([^/?#]+)');
  if v_authority is null or position('@' in v_authority) > 0 then
    return false;
  end if;

  if left(v_authority, 1) = '[' then
    -- User-provided links are never fetched by BrainSwap, and the MVP does not
    -- need IP-literal links. Reject brackets rather than approximate IPv6 and
    -- accidentally accept malformed authorities such as [::::].
    return false;
  else
    if v_authority ~ ':[0-9]+$' then
      v_port := substring(v_authority from ':([0-9]+)$');
      v_host := regexp_replace(v_authority, ':[0-9]+$', '');
    else
      if position(':' in v_authority) > 0 then return false; end if;
      v_host := v_authority;
    end if;
    if length(v_host) > 253
      or v_host !~ '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'
    then
      return false;
    end if;
    if v_host ~ '^[0-9.]+$' then
      if v_host !~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' then
        return false;
      end if;
      foreach v_octet in array string_to_array(v_host, '.') loop
        if v_octet::integer > 255 then return false; end if;
      end loop;
    end if;
  end if;

  if v_port is not null then
    if length(v_port) > 5 then return false; end if;
    if v_port::integer < 1 or v_port::integer > 65535 then return false; end if;
  end if;
  return true;
end
$$;

create or replace function private.file_is_allowed(p_filename text, p_mime_type text)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  ext text;
begin
  if p_filename is null
    or length(p_filename) not between 1 and 255
    or p_filename <> btrim(p_filename)
    or position('/' in p_filename) > 0
    or position(chr(92) in p_filename) > 0
    or p_filename ~ '[[:cntrl:]]'
    or p_filename in ('.', '..')
    or p_filename ~ '^\.'
    or p_filename !~ '\.[A-Za-z0-9]+$'
  then
    return false;
  end if;

  ext := lower(substring(p_filename from '\.([A-Za-z0-9]+)$'));
  return case ext
    when 'pdf' then p_mime_type = 'application/pdf'
    when 'txt' then p_mime_type = 'text/plain'
    when 'md' then p_mime_type in ('text/plain', 'text/markdown')
    when 'csv' then p_mime_type in ('text/csv', 'text/plain')
    when 'json' then p_mime_type = 'application/json'
    when 'png' then p_mime_type = 'image/png'
    when 'jpg' then p_mime_type = 'image/jpeg'
    when 'jpeg' then p_mime_type = 'image/jpeg'
    when 'webp' then p_mime_type = 'image/webp'
    when 'docx' then p_mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when 'pptx' then p_mime_type = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    when 'xlsx' then p_mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else false
  end;
end
$$;

create or replace function private.safe_filename(p_filename text)
returns text
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  cleaned text;
begin
  cleaned := regexp_replace(p_filename, '[^A-Za-z0-9._-]', '-', 'g');
  cleaned := regexp_replace(cleaned, '-+', '-', 'g');
  cleaned := btrim(cleaned, '-');
  if cleaned = '' then
    cleaned := 'file';
  end if;
  return left(cleaned, 255);
end
$$;

create or replace function private.actor(p_org uuid)
returns public.memberships
language sql
stable
security definer
set search_path = ''
as $$
  select m
  from public.memberships m
  where m.organization_id = p_org
    and m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active
  limit 1
$$;

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
  -- Mutating RPCs hold this lock through commit. admin_update_membership()
  -- takes FOR UPDATE on the same row, serializing deactivation with actions
  -- that already authenticated and forcing later actions to re-read active.
  select * into a
  from public.memberships m
  where m.organization_id = p_org
    and m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active
  for key share;
  return a;
end
$$;

create or replace function private.can_payload(j public.jobs)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.organization_id = j.organization_id
      and m.user_id = auth.uid()
      and m.claimed_user_id = auth.uid()
      and m.active
      and (
        m.role = 'admin'
        or m.id = j.created_by_membership_id
        or (
          m.id = j.assigned_to_membership_id
          and j.claim_expires_at > now()
        )
        or exists (
          select 1
          from public.submissions s
          where s.job_id = j.id
            and s.submitted_by_membership_id = m.id
            and s.status = 'submitted'
        )
      )
  )
$$;

create or replace function private.can_payload_job(p_job_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(not j.deletion_pending and private.can_payload(j), false)
  from public.jobs j
  where j.id = p_job_id
$$;

create or replace function private.can_read_job_content(p_job_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs j
    where j.id = p_job_id
      and not j.deletion_pending
      and (
        (
          j.visibility = 'lab'
          and j.status <> 'draft'
          and (private.actor(j.organization_id)).id is not null
        )
        or private.can_payload(j)
      )
  )
$$;

create or replace function private.can_read_protected_job(p_job_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs j
    where j.id = p_job_id
      and not j.deletion_pending
      and private.can_payload(j)
  )
$$;

alter table public.memberships
  drop constraint if exists memberships_claimed_user_consistent,
  add constraint memberships_claimed_user_consistent
    check (claimed_user_id is null or user_id is null or claimed_user_id = user_id) not valid,
  drop constraint if exists memberships_display_name_limit,
  add constraint memberships_display_name_limit
    check (display_name is null or length(btrim(display_name)) between 1 and 120) not valid,
  drop constraint if exists memberships_capabilities_limit,
  add constraint memberships_capabilities_limit
    check (private.valid_capabilities(capabilities)) not valid,
  drop constraint if exists memberships_invited_email_valid,
  add constraint memberships_invited_email_valid check (
    length(invited_email) between 3 and 254
    and invited_email = lower(btrim(invited_email))
    and invited_email !~ '[[:cntrl:][:space:]]'
    and invited_email ~ '^[^@]+@[^@]+\.[^@]+$'
  ) not valid;

alter table public.jobs
  drop constraint if exists jobs_title_nonblank,
  add constraint jobs_title_nonblank
    check (length(btrim(title)) between 1 and 120) not valid,
  drop constraint if exists jobs_summary_nonblank,
  add constraint jobs_summary_nonblank
    check (length(btrim(listing_summary)) between 1 and 1000) not valid,
  drop constraint if exists jobs_sensitivity_notes_limit,
  add constraint jobs_sensitivity_notes_limit
    check (sensitivity_notes is null or length(sensitivity_notes) <= 10000) not valid,
  drop constraint if exists jobs_tools_limit,
  add constraint jobs_tools_limit
    check (private.valid_job_tools(required_tools)) not valid,
  drop constraint if exists jobs_claim_fields_consistent,
  add constraint jobs_claim_fields_consistent check (
    (assigned_to_membership_id is null and claimed_at is null and claim_expires_at is null)
    or (assigned_to_membership_id is not null and claimed_at is not null and claim_expires_at is not null)
  ) not valid,
  drop constraint if exists jobs_claimed_state_consistent,
  add constraint jobs_claimed_state_consistent check (
    status <> 'claimed'
    or (assigned_to_membership_id is not null and claim_expires_at is not null)
  ) not valid,
  drop constraint if exists jobs_inactive_state_unassigned,
  add constraint jobs_inactive_state_unassigned check (
    status in ('claimed', 'revision_requested')
    or (assigned_to_membership_id is null and claim_expires_at is null)
  ) not valid,
  drop constraint if exists jobs_accepted_state_consistent,
  add constraint jobs_accepted_state_consistent check (
    (status = 'accepted' and accepted_submission_id is not null)
    or (status <> 'accepted' and accepted_submission_id is null)
  ) not valid,
  drop constraint if exists jobs_cancelled_was_published,
  add constraint jobs_cancelled_was_published check (
    status <> 'cancelled' or published_at is not null
  ) not valid,
  drop constraint if exists jobs_deletion_state_consistent,
  add constraint jobs_deletion_state_consistent check (
    (not deletion_pending and deletion_started_at is null)
    or (deletion_pending and deletion_started_at is not null)
  ) not valid;

alter table public.job_payloads
  drop constraint if exists payload_task_nonblank,
  add constraint payload_task_nonblank
    check (length(btrim(current_task)) > 0 and length(current_task) <= 100000) not valid,
  drop constraint if exists payload_success_nonblank,
  add constraint payload_success_nonblank
    check (length(btrim(success_criteria)) > 0 and length(success_criteria) <= 25000) not valid,
  drop constraint if exists payload_output_nonblank,
  add constraint payload_output_nonblank
    check (length(btrim(output_format)) > 0 and length(output_format) <= 10000) not valid;

alter table public.job_context_items
  drop constraint if exists job_context_items_check,
  drop constraint if exists job_context_items_text_content_check,
  drop constraint if exists context_shape,
  add constraint context_shape check (
    (kind = 'inline_text' and text_content is not null and url is null and source_job_id is null)
    or (kind in ('shared_chat', 'external_link') and url is not null and text_content is null and source_job_id is null)
    or (kind = 'previous_job' and source_job_id is not null and text_content is not null and url is null)
  ) not valid,
  drop constraint if exists context_text_length,
  add constraint context_text_length check (
    length(coalesce(text_content, '')) <=
      case when kind = 'previous_job' then 500000 else 250000 end
  ) not valid,
  drop constraint if exists context_label_limit,
  add constraint context_label_limit
    check (length(btrim(label)) between 1 and 200) not valid,
  drop constraint if exists context_url_limit,
  add constraint context_url_limit
    check (url is null or private.valid_https_url(url)) not valid;

alter table public.submissions
  drop constraint if exists submissions_model_limit,
  add constraint submissions_model_limit
    check (status = 'draft' or (length(btrim(model_used_text)) > 0 and length(model_used_text) <= 200)) not valid,
  drop constraint if exists submissions_notes_limit,
  add constraint submissions_notes_limit
    check (notes is null or length(notes) <= 25000) not valid,
  drop constraint if exists submissions_tools_limit,
  add constraint submissions_tools_limit
    check (private.valid_job_tools(tools_used)) not valid,
  drop constraint if exists submissions_state_consistent,
  add constraint submissions_state_consistent check (
    (status = 'draft' and revision_number is null and submitted_at is null)
    or (
      status = 'submitted'
      and revision_number is not null
      and revision_number > 0
      and submitted_at is not null
      and length(btrim(response_text)) > 0
      and length(response_text) <= 500000
    )
  ) not valid;

alter table public.job_files
  drop constraint if exists job_files_name_limits,
  add constraint job_files_name_limits check (
    length(original_filename) between 1 and 255
    and length(safe_filename) between 1 and 255
    and (description is null or length(description) <= 1000)
  ) not valid;

alter table public.submission_files
  drop constraint if exists submission_files_name_limits,
  add constraint submission_files_name_limits check (
    length(original_filename) between 1 and 255
    and length(safe_filename) between 1 and 255
    and (description is null or length(description) <= 1000)
  ) not valid;

create unique index if not exists submissions_revision_number_uq
  on public.submissions(job_id, revision_number)
  where status = 'submitted';

alter table public.jobs
  drop constraint if exists jobs_parent_same_org_fk,
  add constraint jobs_parent_same_org_fk
    foreign key (organization_id, parent_job_id)
    references public.jobs(organization_id, id)
    not valid;

alter table public.job_context_items
  drop constraint if exists contexts_job_same_org_fk,
  add constraint contexts_job_same_org_fk
    foreign key (organization_id, job_id)
    references public.jobs(organization_id, id)
    on delete cascade
    not valid,
  drop constraint if exists contexts_source_same_org_fk,
  add constraint contexts_source_same_org_fk
    foreign key (organization_id, source_job_id)
    references public.jobs(organization_id, id)
    not valid;

alter table public.revision_requests
  drop constraint if exists revisions_job_same_org_fk,
  add constraint revisions_job_same_org_fk
    foreign key (organization_id, job_id)
    references public.jobs(organization_id, id)
    on delete cascade
    not valid,
  drop constraint if exists revisions_requester_same_org_fk,
  add constraint revisions_requester_same_org_fk
    foreign key (organization_id, requested_by_membership_id)
    references public.memberships(organization_id, id)
    not valid;

alter table public.notifications
  drop constraint if exists notifications_job_same_org_fk,
  add constraint notifications_job_same_org_fk
    foreign key (organization_id, job_id)
    references public.jobs(organization_id, id)
    on delete cascade
    not valid;

alter table public.audit_events
  drop constraint if exists audit_events_job_id_fkey,
  drop constraint if exists audit_job_same_org_fk,
  add constraint audit_job_same_org_fk
    foreign key (organization_id, job_id)
    references public.jobs(organization_id, id)
    on delete set null (job_id)
    not valid,
  drop constraint if exists audit_actor_same_org_fk,
  add constraint audit_actor_same_org_fk
    foreign key (organization_id, actor_membership_id)
    references public.memberships(organization_id, id)
    not valid;

alter table public.memberships validate constraint memberships_claimed_user_consistent;
alter table public.memberships validate constraint memberships_display_name_limit;
alter table public.memberships validate constraint memberships_capabilities_limit;
alter table public.memberships validate constraint memberships_invited_email_valid;
alter table public.jobs validate constraint jobs_title_nonblank;
alter table public.jobs validate constraint jobs_summary_nonblank;
alter table public.jobs validate constraint jobs_sensitivity_notes_limit;
alter table public.jobs validate constraint jobs_tools_limit;
alter table public.jobs validate constraint jobs_claim_fields_consistent;
alter table public.jobs validate constraint jobs_claimed_state_consistent;
alter table public.jobs validate constraint jobs_inactive_state_unassigned;
alter table public.jobs validate constraint jobs_accepted_state_consistent;
alter table public.jobs validate constraint jobs_cancelled_was_published;
alter table public.jobs validate constraint jobs_deletion_state_consistent;
alter table public.job_payloads validate constraint payload_task_nonblank;
alter table public.job_payloads validate constraint payload_success_nonblank;
alter table public.job_payloads validate constraint payload_output_nonblank;
alter table public.job_context_items validate constraint context_label_limit;
alter table public.job_context_items validate constraint context_url_limit;
alter table public.job_context_items validate constraint context_text_length;
alter table public.job_context_items validate constraint context_shape;
alter table public.submissions validate constraint submissions_model_limit;
alter table public.submissions validate constraint submissions_notes_limit;
alter table public.submissions validate constraint submissions_tools_limit;
alter table public.submissions validate constraint submissions_state_consistent;
alter table public.job_files validate constraint job_files_name_limits;
alter table public.submission_files validate constraint submission_files_name_limits;
alter table public.jobs validate constraint jobs_parent_same_org_fk;
alter table public.job_context_items validate constraint contexts_job_same_org_fk;
alter table public.job_context_items validate constraint contexts_source_same_org_fk;
alter table public.revision_requests validate constraint revisions_job_same_org_fk;
alter table public.revision_requests validate constraint revisions_requester_same_org_fk;
alter table public.notifications validate constraint notifications_job_same_org_fk;
alter table public.audit_events validate constraint audit_job_same_org_fk;
alter table public.audit_events validate constraint audit_actor_same_org_fk;

create or replace function private.apply_draft_input(
  p_job_id uuid,
  p_organization_id uuid,
  p_input jsonb
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_summary text;
  v_task text;
  v_success text;
  v_output text;
  v_visibility public.job_visibility;
  v_sensitivity public.job_sensitivity;
  v_sensitivity_notes text;
  v_effort public.job_effort;
  v_deadline timestamptz;
  v_deadline_text text;
  v_tools text[];
  v_acknowledged boolean;
  v_preferred uuid;
  v_acceptable uuid[] := '{}'::uuid[];
  v_contexts jsonb;
  v_context jsonb;
  v_kind text;
  v_label text;
  v_text text;
  v_url text;
  v_model_count integer;
  v_inline_count integer;
  v_link_count integer;
  v_inline_length bigint;
begin
  if jsonb_typeof(p_input) is distinct from 'object' then
    raise exception 'invalid draft input';
  end if;
  if jsonb_typeof(p_input -> 'title') is distinct from 'string'
    or jsonb_typeof(p_input -> 'listing_summary') is distinct from 'string'
    or jsonb_typeof(p_input -> 'current_task') is distinct from 'string'
    or jsonb_typeof(p_input -> 'success_criteria') is distinct from 'string'
    or jsonb_typeof(p_input -> 'output_format') is distinct from 'string'
    or jsonb_typeof(p_input -> 'visibility') is distinct from 'string'
    or jsonb_typeof(p_input -> 'sensitivity') is distinct from 'string'
    or jsonb_typeof(p_input -> 'effort') is distinct from 'string'
    or coalesce(jsonb_typeof(p_input -> 'sensitivity_notes'), 'null') not in ('null', 'string')
    or coalesce(jsonb_typeof(p_input -> 'deadline'), 'null') not in ('null', 'string')
    or jsonb_typeof(p_input -> 'preferred_model_id') is distinct from 'string'
  then
    raise exception 'invalid draft input';
  end if;

  v_title := btrim(coalesce(p_input ->> 'title', ''));
  v_summary := btrim(coalesce(p_input ->> 'listing_summary', ''));
  -- Preserve prompt formatting exactly; trimming is validation-only.
  v_task := coalesce(p_input ->> 'current_task', '');
  v_success := coalesce(p_input ->> 'success_criteria', '');
  v_output := coalesce(p_input ->> 'output_format', '');

  if length(v_title) not between 1 and 120
    or length(v_summary) not between 1 and 1000
    or length(btrim(v_task)) = 0 or length(v_task) > 100000
    or length(btrim(v_success)) = 0 or length(v_success) > 25000
    or length(btrim(v_output)) = 0 or length(v_output) > 10000
  then
    raise exception 'invalid draft text';
  end if;

  begin
    v_visibility := (p_input ->> 'visibility')::public.job_visibility;
    v_sensitivity := (p_input ->> 'sensitivity')::public.job_sensitivity;
    v_effort := (p_input ->> 'effort')::public.job_effort;
  exception when others then
    raise exception 'invalid draft classification';
  end;

  v_sensitivity_notes := nullif(btrim(coalesce(p_input ->> 'sensitivity_notes', '')), '');
  if length(coalesce(v_sensitivity_notes, '')) > 10000 then
    raise exception 'sensitivity notes are too long';
  end if;

  v_deadline_text := nullif(btrim(coalesce(p_input ->> 'deadline', '')), '');
  if v_deadline_text is not null then
    if v_deadline_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$' then
      raise exception 'deadline must be an ISO-8601 date-time with explicit timezone';
    end if;
    begin
      v_deadline := v_deadline_text::timestamptz;
    exception when others then
      raise exception 'invalid deadline';
    end;
    if v_deadline <= now() then
      raise exception 'deadline must be in the future';
    end if;
  end if;

  if jsonb_typeof(coalesce(p_input -> 'required_tools', '[]'::jsonb)) <> 'array' then
    raise exception 'invalid required tools';
  end if;
  v_tools := array(
    select btrim(t.value)
    from jsonb_array_elements_text(coalesce(p_input -> 'required_tools', '[]'::jsonb))
      with ordinality as t(value, position)
    order by t.position
  );
  if not private.valid_job_tools(v_tools) then
    raise exception 'invalid required tools';
  end if;

  if jsonb_typeof(p_input -> 'acknowledged') is distinct from 'boolean' then
    raise exception 'invalid acknowledgement or preferred model';
  end if;
  begin
    v_acknowledged := (p_input ->> 'acknowledged')::boolean;
    v_preferred := (p_input ->> 'preferred_model_id')::uuid;
  exception when others then
    raise exception 'invalid acknowledgement or preferred model';
  end;

  if jsonb_typeof(coalesce(p_input -> 'acceptable_model_ids', '[]'::jsonb)) <> 'array' then
    raise exception 'invalid acceptable models';
  end if;
  begin
    v_acceptable := array(
      select t.value::uuid
      from jsonb_array_elements_text(coalesce(p_input -> 'acceptable_model_ids', '[]'::jsonb))
        with ordinality as t(value, position)
      order by t.position
    );
  exception when others then
    raise exception 'invalid acceptable models';
  end;
  if cardinality(v_acceptable) > 10
    or v_preferred = any(v_acceptable)
    or cardinality(v_acceptable) <> (select count(distinct x) from unnest(v_acceptable) as x)
  then
    raise exception 'invalid acceptable models';
  end if;

  select count(*)
  into v_model_count
  from public.models m
  where m.organization_id = p_organization_id
    and m.active
    and (m.id = v_preferred or m.id = any(v_acceptable));
  if v_model_count <> 1 + cardinality(v_acceptable) then
    raise exception 'models must be active organization models';
  end if;

  v_contexts := coalesce(p_input -> 'contexts', '[]'::jsonb);
  if jsonb_typeof(v_contexts) <> 'array' or jsonb_array_length(v_contexts) > 11 then
    raise exception 'invalid contexts';
  end if;
  select
    count(*) filter (where value ->> 'kind' = 'inline_text'),
    count(*) filter (where value ->> 'kind' in ('external_link', 'shared_chat')),
    coalesce(sum(length(coalesce(value ->> 'text_content', '')))
      filter (where value ->> 'kind' = 'inline_text'), 0)
  into v_inline_count, v_link_count, v_inline_length
  from jsonb_array_elements(v_contexts);
  if v_inline_count > 1 or v_link_count > 10 or v_inline_length > 250000 then
    raise exception 'invalid contexts';
  end if;

  update public.jobs
  set title = v_title,
      listing_summary = v_summary,
      visibility = v_visibility,
      sensitivity = v_sensitivity,
      sensitivity_notes = v_sensitivity_notes,
      effort = v_effort,
      deadline = v_deadline,
      required_tools = v_tools,
      data_handling_acknowledged_at = case when v_acknowledged then coalesce(data_handling_acknowledged_at, now()) end,
      acknowledgement_version = case when v_acknowledged then 'brainswap-data-boundary-v1' end,
      updated_at = now()
  where id = p_job_id and organization_id = p_organization_id;

  update public.job_payloads
  set current_task = v_task,
      success_criteria = v_success,
      output_format = v_output,
      updated_at = now()
  where job_id = p_job_id;

  delete from public.job_models where job_id = p_job_id;
  insert into public.job_models(organization_id, job_id, model_id, preference, sort_order)
  values (p_organization_id, p_job_id, v_preferred, 'preferred', 0);
  insert into public.job_models(organization_id, job_id, model_id, preference, sort_order)
  select p_organization_id, p_job_id, model_id, 'acceptable'::public.model_preference, position::integer
  from unnest(v_acceptable) with ordinality as a(model_id, position);

  -- A follow-up's immutable previous-result snapshot is not replaced by ordinary draft edits.
  delete from public.job_context_items
  where job_id = p_job_id and kind <> 'previous_job';

  for v_context in select value from jsonb_array_elements(v_contexts)
  loop
    if jsonb_typeof(v_context) <> 'object' then
      raise exception 'invalid context';
    end if;
    if jsonb_typeof(v_context -> 'kind') is distinct from 'string'
      or jsonb_typeof(v_context -> 'label') is distinct from 'string'
    then
      raise exception 'invalid context';
    end if;
    v_kind := v_context ->> 'kind';
    v_label := btrim(coalesce(v_context ->> 'label', ''));
    if length(v_label) not between 1 and 200 then
      raise exception 'invalid context label';
    end if;

    if v_kind = 'inline_text' then
      if jsonb_typeof(v_context -> 'text_content') is distinct from 'string' then
        raise exception 'invalid inline context';
      end if;
      v_text := coalesce(v_context ->> 'text_content', '');
      if length(btrim(v_text)) = 0 or length(v_text) > 250000 or v_context ? 'url' then
        raise exception 'invalid inline context';
      end if;
      insert into public.job_context_items(
        organization_id, job_id, kind, label, text_content, sort_order
      ) values (
        p_organization_id, p_job_id, 'inline_text', v_label, v_text,
        (select count(*) from public.job_context_items where job_id = p_job_id)
      );
    elsif v_kind in ('external_link', 'shared_chat') then
      if jsonb_typeof(v_context -> 'url') is distinct from 'string' then
        raise exception 'invalid external context';
      end if;
      v_url := btrim(coalesce(v_context ->> 'url', ''));
      if not private.valid_https_url(v_url) or v_context ? 'text_content' then
        raise exception 'invalid external context';
      end if;
      insert into public.job_context_items(
        organization_id, job_id, kind, label, url, sort_order
      ) values (
        p_organization_id, p_job_id, v_kind::public.context_kind, v_label, v_url,
        (select count(*) from public.job_context_items where job_id = p_job_id)
      );
    else
      raise exception 'unsupported context kind';
    end if;
  end loop;
end
$$;

drop function if exists public.claim_available_memberships();
create function public.claim_available_memberships()
returns table(organization_id uuid, membership_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  select u.email
  into v_email
  from auth.users u
  where u.id = v_user_id and u.email_confirmed_at is not null;
  if v_email is null then
    return;
  end if;

  return query
  update public.memberships m
  set user_id = v_user_id,
      claimed_user_id = coalesce(m.claimed_user_id, v_user_id),
      claimed_at = coalesce(m.claimed_at, now()),
      updated_at = now()
  where m.active
    and m.invited_email = lower(btrim(v_email))
    and (
      (m.user_id = v_user_id and m.claimed_user_id = v_user_id)
      or (m.user_id is null and m.claimed_user_id is null)
    )
  returning m.organization_id, m.id;
end
$$;

drop function if exists public.my_active_memberships();
create function public.my_active_memberships()
returns table(
  organization_id uuid,
  membership_id uuid,
  organization_name text,
  display_name text,
  role public.member_role,
  capabilities text[],
  notification_preferences jsonb
)
language sql
security definer
set search_path = ''
as $$
  select m.organization_id, m.id, o.name, m.display_name, m.role,
    m.capabilities, m.notification_preferences
  from public.memberships m
  join public.organizations o on o.id = m.organization_id
  where m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active
$$;

create or replace function public.create_draft_job(p_organization_id uuid, p_input jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  j uuid := gen_random_uuid();
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null then
    raise exception 'not authorized';
  end if;

  insert into public.jobs(
    id, organization_id, created_by_membership_id, title, listing_summary,
    visibility, sensitivity, effort
  ) values (
    j, p_organization_id, a.id, 'Draft', 'Draft', 'claimed_only', 'general', 'quick'
  );
  insert into public.job_payloads(job_id, current_task, success_criteria, output_format)
  values (j, 'Draft task', 'Draft completion criteria', 'Draft output format');

  perform private.apply_draft_input(j, p_organization_id, p_input);
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (p_organization_id, j, a.id, 'job_draft_created');
  return j;
end
$$;

create or replace function public.update_draft_job(p_job_id uuid, p_input jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then
    raise exception 'not authorized';
  end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
  then
    raise exception 'not authorized';
  end if;

  perform private.apply_draft_input(j.id, j.organization_id, p_input);
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_draft_updated');
end
$$;

drop function if exists public.update_profile(text, text[], uuid[], jsonb);
create function public.update_profile(
  p_organization_id uuid,
  p_display_name text,
  p_capabilities text[],
  p_model_ids uuid[],
  p_preferences jsonb
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  v_name text := btrim(coalesce(p_display_name, ''));
  v_model_count integer;
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null
    or length(v_name) not between 1 and 120
    or not private.valid_capabilities(coalesce(p_capabilities, '{}'::text[]))
    or p_model_ids is null
    or cardinality(p_model_ids) > 50
    or cardinality(p_model_ids) <> (select count(distinct x) from unnest(p_model_ids) as x)
    or jsonb_typeof(p_preferences) is distinct from 'object'
    or (p_preferences - 'new_matching_jobs') <> '{}'::jsonb
    or jsonb_typeof(p_preferences -> 'new_matching_jobs') is distinct from 'boolean'
  then
    raise exception 'invalid profile';
  end if;

  select count(*) into v_model_count
  from public.models m
  where m.organization_id = p_organization_id and m.active and m.id = any(p_model_ids);
  if v_model_count <> cardinality(p_model_ids) then
    raise exception 'invalid profile models';
  end if;

  update public.memberships
  set display_name = v_name,
      capabilities = array(select distinct btrim(x) from unnest(p_capabilities) as x order by btrim(x)),
      notification_preferences = p_preferences,
      updated_at = now()
  where id = a.id and organization_id = p_organization_id;

  delete from public.member_models where membership_id = a.id;
  insert into public.member_models(organization_id, membership_id, model_id)
  select p_organization_id, a.id, m.id
  from public.models m
  where m.organization_id = p_organization_id and m.id = any(p_model_ids);
end
$$;

create or replace function public.admin_upsert_membership(
  p_organization_id uuid,
  p_email text,
  p_role public.member_role default 'member'
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  existing public.memberships;
  r uuid;
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null or a.role <> 'admin' then
    raise exception 'administrator access required';
  end if;
  if p_email is null
    or length(p_email) not between 3 and 254
    or p_email <> lower(btrim(p_email))
    or p_email ~ '[[:cntrl:][:space:]]'
    or p_email !~ '^[^@]+@[^@]+\.[^@]+$'
    or p_role is null
  then
    raise exception 'invalid invitation';
  end if;

  select * into existing
  from public.memberships m
  where m.organization_id = p_organization_id and m.invited_email = p_email
  for update;
  if existing.id is not null then
    if existing.role <> p_role or not existing.active then
      raise exception 'membership exists; use admin_update_membership';
    end if;
    return existing.id;
  end if;

  insert into public.memberships(organization_id, invited_email, role)
  values (p_organization_id, p_email, p_role)
  returning id into r;
  insert into public.audit_events(organization_id, actor_membership_id, event_type, metadata)
  values (
    p_organization_id, a.id, 'membership_invited',
    jsonb_build_object('membership_id', r, 'role', p_role)
  );
  return r;
end
$$;

create or replace function public.admin_update_membership(
  p_organization_id uuid,
  p_membership_id uuid,
  p_role public.member_role,
  p_active boolean
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  target public.memberships;
  v_admins integer;
begin
  -- Serializes all role/deactivation decisions for this organization.
  perform 1 from public.organizations o where o.id = p_organization_id for update;
  a := private.locked_actor(p_organization_id);
  if a.id is null or a.role <> 'admin' or p_role is null or p_active is null then
    raise exception 'administrator access required';
  end if;

  -- Discover the target without a row lock so deactivation can take job locks
  -- first, matching the job-then-membership order used by workflow RPCs.
  select * into target
  from public.memberships m
  where m.organization_id = p_organization_id and m.id = p_membership_id;
  if target.id is null then
    raise exception 'membership not found';
  end if;

  if not p_active then
    perform 1
    from public.jobs j
    where j.organization_id = p_organization_id
      and j.assigned_to_membership_id = target.id
    for update;
  end if;

  select * into target
  from public.memberships m
  where m.organization_id = p_organization_id and m.id = p_membership_id
  for update;

  if target.active and target.role = 'admin' and (not p_active or p_role <> 'admin') then
    select count(*) into v_admins
    from public.memberships m
    where m.organization_id = p_organization_id
      and m.active
      and m.role = 'admin'
      and m.user_id is not null
      and m.claimed_user_id = m.user_id
      and m.id <> target.id;
    if v_admins = 0 then
      raise exception 'cannot remove the last active administrator';
    end if;
  end if;

  if not p_active then
    insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
    select j.organization_id, j.id, a.id, 'claim_released_for_deactivation',
      jsonb_build_object('membership_id', target.id)
    from public.jobs j
    where j.organization_id = p_organization_id
      and j.assigned_to_membership_id = target.id;

    update public.jobs
    set status = case when status = 'claimed' then 'open'::public.job_status else status end,
        assigned_to_membership_id = null,
        claimed_at = null,
        claim_expires_at = null,
        updated_at = now()
    where organization_id = p_organization_id and assigned_to_membership_id = target.id;
  end if;

  update public.memberships
  set role = p_role, active = p_active, updated_at = now()
  where id = target.id and organization_id = p_organization_id;

  insert into public.audit_events(organization_id, actor_membership_id, event_type, metadata)
  values (
    p_organization_id, a.id, 'membership_updated',
    jsonb_build_object('membership_id', target.id, 'role', p_role, 'active', p_active)
  );
end
$$;

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
  order by m.created_at;
end
$$;

create or replace function public.publish_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  p public.job_payloads;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then
    raise exception 'not authorized';
  end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
  then
    raise exception 'not authorized';
  end if;

  select * into p from public.job_payloads where job_id = j.id;
  if p.job_id is null
    or length(btrim(j.title)) not between 1 and 120
    or length(btrim(j.listing_summary)) not between 1 and 1000
    or length(btrim(p.current_task)) not between 1 and 100000
    or length(btrim(p.success_criteria)) not between 1 and 25000
    or length(btrim(p.output_format)) not between 1 and 10000
    or j.data_handling_acknowledged_at is null
    or (j.deadline is not null and j.deadline <= now())
    or (select count(*) from public.job_models jm where jm.job_id = j.id and jm.preference = 'preferred') <> 1
    or exists (
      select 1
      from public.job_models jm
      left join public.models m
        on m.organization_id = jm.organization_id and m.id = jm.model_id
      where jm.job_id = j.id and (m.id is null or not m.active)
    )
    or exists (
      select 1 from public.job_files f
      where f.job_id = j.id and (f.upload_status <> 'ready' or f.cleanup_started_at is not null)
    )
  then
    raise exception 'job is incomplete';
  end if;

  update public.jobs
  set status = 'open', published_at = now(), updated_at = now()
  where id = j.id;

  insert into public.notifications(organization_id, recipient_membership_id, job_id, type, message)
  select j.organization_id, m.id, j.id, 'new_job', 'A new BrainSwap job is available.'
  from public.memberships m
  where m.organization_id = j.organization_id
    and m.active
    and m.user_id is not null
    and m.claimed_user_id = m.user_id
    and m.id <> j.created_by_membership_id
    and m.notification_preferences -> 'new_matching_jobs' = 'true'::jsonb;

  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_published');
end
$$;

create or replace function public.claim_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  old_assignee uuid;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then
    raise exception 'not eligible';
  end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null or a.id = j.created_by_membership_id then
    raise exception 'not eligible';
  end if;
  if j.deletion_pending or j.status not in ('open', 'claimed', 'revision_requested') then
    raise exception 'job is not claimable';
  end if;
  if j.assigned_to_membership_id = a.id and j.claim_expires_at > now() then
    return;
  end if;
  if j.assigned_to_membership_id is not null and j.claim_expires_at > now() then
    raise exception 'already claimed';
  end if;

  old_assignee := j.assigned_to_membership_id;
  update public.jobs
  set assigned_to_membership_id = a.id,
      claimed_at = now(),
      claim_expires_at = now() + interval '4 hours',
      status = case when j.status = 'open' then 'claimed'::public.job_status else j.status end,
      updated_at = now()
  where id = j.id;

  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (
    j.organization_id, j.id, a.id,
    case when old_assignee is null then 'job_claimed' else 'expired_claim_replaced' end,
    jsonb_build_object('prior_assignee_existed', old_assignee is not null)
  );
end
$$;

create or replace function public.release_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not current claimant'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null
    or j.claim_expires_at <= now()
  then
    raise exception 'not current claimant';
  end if;

  update public.jobs
  set assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      status = case when j.status = 'claimed' then 'open'::public.job_status else j.status end,
      updated_at = now()
  where id = j.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_released');
end
$$;

create or replace function public.extend_claim(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'claim expired'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null
    or j.claim_expires_at <= now()
    or j.deletion_pending
  then
    raise exception 'claim expired';
  end if;
  update public.jobs
  set claim_expires_at = now() + interval '4 hours', updated_at = now()
  where id = j.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'claim_extended');
end
$$;

create or replace function public.create_submission_draft(p_job_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s uuid;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not claimant'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null
    or j.claim_expires_at <= now()
    or j.deletion_pending
  then
    raise exception 'not claimant';
  end if;

  select id into s
  from public.submissions
  where job_id = j.id and submitted_by_membership_id = a.id and status = 'draft'
  for update;
  if s is null then
    insert into public.submissions(job_id, organization_id, submitted_by_membership_id)
    values (j.id, j.organization_id, a.id)
    returning id into s;
  end if;
  return s;
end
$$;

drop function if exists public.submit_result(uuid, text, text, text);
create function public.submit_result(
  p_job_id uuid,
  p_model_used_text text,
  p_response_text text,
  p_notes text default '',
  p_tools_used text[] default '{}'::text[]
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
  n integer;
  v_model text := btrim(coalesce(p_model_used_text, ''));
  v_response text := coalesce(p_response_text, '');
  v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'claim expired'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null
    or j.claim_expires_at <= now()
    or j.deletion_pending
  then
    raise exception 'claim expired';
  end if;
  if length(v_model) not between 1 and 200
    or length(btrim(v_response)) = 0 or length(v_response) > 500000
    or length(coalesce(v_notes, '')) > 25000
    or not private.valid_job_tools(coalesce(p_tools_used, '{}'::text[]))
  then
    raise exception 'result incomplete';
  end if;

  select * into s
  from public.submissions
  where job_id = j.id and submitted_by_membership_id = a.id and status = 'draft'
  for update;
  if s.id is null then
    insert into public.submissions(job_id, organization_id, submitted_by_membership_id)
    values (j.id, j.organization_id, a.id)
    returning * into s;
  end if;
  if exists (
    select 1 from public.submission_files f
    where f.submission_id = s.id
      and (f.upload_status <> 'ready' or f.cleanup_started_at is not null)
  ) then
    raise exception 'files pending';
  end if;

  select coalesce(max(revision_number), 0) + 1 into n
  from public.submissions where job_id = j.id and status = 'submitted';
  update public.submissions
  set status = 'submitted',
      model_used_text = v_model,
      response_text = v_response,
      notes = v_notes,
      tools_used = array(select distinct btrim(x) from unnest(p_tools_used) as x order by btrim(x)),
      revision_number = n,
      submitted_at = now()
  where id = s.id and status = 'draft';

  update public.revision_requests
  set resolved_by_submission_id = s.id, resolved_at = now()
  where job_id = j.id and resolved_at is null;
  update public.jobs
  set status = 'submitted',
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      updated_at = now()
  where id = j.id;

  insert into public.notifications(organization_id, recipient_membership_id, job_id, type, message)
  select j.organization_id, m.id, j.id, 'result_submitted', 'A BrainSwap result was submitted.'
  from public.memberships m
  where m.id = j.created_by_membership_id
    and m.organization_id = j.organization_id
    and m.active
    and m.user_id is not null
    and m.claimed_user_id = m.user_id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, j.id, a.id, 'result_submitted', jsonb_build_object('revision_number', n));
end
$$;

create or replace function public.request_revision(p_job_id uuid, p_instructions text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
  helper public.memberships;
  v_helper_available boolean;
  v_instructions text := btrim(coalesce(p_instructions, ''));
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'submitted'
    or length(v_instructions) not between 1 and 25000
    or j.deletion_pending
  then
    raise exception 'not allowed';
  end if;
  select * into s
  from public.submissions
  where job_id = j.id and status = 'submitted'
  order by revision_number desc limit 1;
  if s.id is null then raise exception 'submission not found'; end if;

  insert into public.revision_requests(
    organization_id, job_id, submission_id, requested_by_membership_id, instructions
  ) values (j.organization_id, j.id, s.id, a.id, v_instructions);
  select * into helper
  from public.memberships m
  where m.organization_id = j.organization_id and m.id = s.submitted_by_membership_id
  for key share;
  v_helper_available := coalesce(
    helper.active
    and helper.user_id is not null
    and helper.claimed_user_id = helper.user_id,
    false
  );

  update public.jobs
  set status = 'revision_requested',
      assigned_to_membership_id = case when v_helper_available then helper.id end,
      claimed_at = case when v_helper_available then now() end,
      claim_expires_at = case when v_helper_available then now() + interval '4 hours' end,
      updated_at = now()
  where id = j.id;
  if v_helper_available then
    insert into public.notifications(organization_id, recipient_membership_id, job_id, type, message)
    values (j.organization_id, helper.id, j.id, 'revision_requested', 'A BrainSwap revision was requested.');
  end if;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'revision_requested');
end
$$;

create or replace function public.accept_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'submitted'
    or j.deletion_pending
  then
    raise exception 'not allowed';
  end if;
  select * into s
  from public.submissions
  where job_id = j.id and status = 'submitted'
  order by revision_number desc limit 1;
  if s.id is null then raise exception 'submission not found'; end if;

  update public.jobs
  set status = 'accepted', accepted_submission_id = s.id, updated_at = now()
  where id = j.id;
  insert into public.notifications(organization_id, recipient_membership_id, job_id, type, message)
  select j.organization_id, m.id, j.id, 'job_accepted', 'A BrainSwap result was accepted.'
  from public.memberships m
  where m.organization_id = j.organization_id
    and m.id = s.submitted_by_membership_id
    and m.active
    and m.user_id is not null
    and m.claimed_user_id = m.user_id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_accepted');
end
$$;

create or replace function public.cancel_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or (a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
    or j.status in ('draft', 'accepted')
    or j.deletion_pending
  then
    raise exception 'not allowed';
  end if;
  if j.status = 'cancelled' then return; end if;
  update public.jobs
  set status = 'cancelled',
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      updated_at = now()
  where id = j.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_cancelled');
end
$$;

create or replace function public.reopen_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or (a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
    or j.status not in ('submitted', 'revision_requested', 'cancelled')
    or (j.status = 'cancelled' and j.published_at is null)
    or j.deletion_pending
  then
    raise exception 'not allowed';
  end if;
  update public.jobs
  set status = 'open',
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      accepted_submission_id = null,
      updated_at = now()
  where id = j.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
  values (j.organization_id, j.id, a.id, 'job_reopened');
end
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.notifications n
  set read_at = coalesce(n.read_at, now())
  from public.memberships m
  where n.id = p_notification_id
    and m.id = n.recipient_membership_id
    and m.organization_id = n.organization_id
    and m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active;
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'notification not found'; end if;
end
$$;

create or replace function public.create_follow_up_draft(p_job_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
  n uuid := gen_random_uuid();
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status not in ('submitted', 'revision_requested', 'accepted', 'cancelled')
    or j.deletion_pending
  then
    raise exception 'not allowed';
  end if;
  select * into s
  from public.submissions
  where job_id = j.id and status = 'submitted'
  order by revision_number desc limit 1;
  if s.id is null then raise exception 'finalized result required'; end if;

  insert into public.jobs(
    id, organization_id, created_by_membership_id, parent_job_id, title,
    listing_summary, visibility, sensitivity, effort
  ) values (
    n, j.organization_id, a.id, j.id, 'Follow-up: ' || left(j.title, 109),
    'Follow-up to a prior BrainSwap result', 'claimed_only', j.sensitivity, j.effort
  );
  insert into public.job_payloads(job_id, current_task, success_criteria, output_format)
  values (n, 'Describe the next task', 'Define completion', 'Specify the desired output');
  insert into public.job_context_items(
    organization_id, job_id, kind, label, text_content, source_job_id
  ) values (
    j.organization_id, n, 'previous_job', 'Snapshot of prior finalized result', s.response_text, j.id
  );
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (
    j.organization_id, n, a.id, 'follow_up_draft_created',
    jsonb_build_object('parent_job_id', j.id, 'source_submission_id', s.id)
  );
  return n;
end
$$;

drop function if exists public.dashboard_jobs(uuid, text);
create function public.dashboard_jobs(p_organization_id uuid, p_tab text default 'open')
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
  if a.id is null then
    raise exception 'not authorized';
  end if;
  return query
  select j.id, j.title, j.listing_summary, j.status, j.visibility, j.sensitivity,
    j.effort, j.required_tools, coalesce(requester.display_name, 'Lab member'),
    model.display_name, j.deadline,
    case when j.assigned_to_membership_id = a.id then j.claim_expires_at end
  from public.jobs j
  join public.memberships requester
    on requester.organization_id = j.organization_id and requester.id = j.created_by_membership_id
  left join public.job_models jm
    on jm.organization_id = j.organization_id and jm.job_id = j.id and jm.preference = 'preferred'
  left join public.models model
    on model.organization_id = j.organization_id and model.id = jm.model_id
  where j.organization_id = p_organization_id
    and not j.deletion_pending
    and case p_tab
      when 'drafts' then j.status = 'draft' and (j.created_by_membership_id = a.id or a.role = 'admin')
      when 'requests' then j.created_by_membership_id = a.id
      when 'claimed' then j.assigned_to_membership_id = a.id and j.claim_expires_at > now()
      when 'review' then j.created_by_membership_id = a.id and j.status = 'submitted'
      when 'completed' then j.status in ('accepted', 'cancelled')
      else j.status in ('open', 'claimed', 'revision_requested')
    end
  order by j.created_at desc;
end
$$;

create or replace function public.job_workspace(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  v_participant boolean;
  v_payload_allowed boolean;
  result jsonb;
begin
  select * into j from public.jobs where id = p_job_id;
  if j.id is null then return null; end if;
  a := private.actor(j.organization_id);
  if a.id is null
    or (j.status = 'draft' and a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
    or (j.deletion_pending and a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
  then
    return null;
  end if;

  v_participant := private.can_payload(j);
  v_payload_allowed := not j.deletion_pending and (j.visibility = 'lab' or v_participant);

  select jsonb_build_object(
    'job', jsonb_build_object(
      'id', j.id,
      'title', j.title,
      'listing_summary', j.listing_summary,
      'status', j.status,
      'visibility', j.visibility,
      'sensitivity', j.sensitivity,
      'effort', j.effort,
      'required_tools', j.required_tools,
      'deadline', j.deadline,
      'deletion_pending', j.deletion_pending,
      'published_at', j.published_at,
      'created_at', j.created_at
    ),
    'protected', case when v_payload_allowed then jsonb_build_object(
      'sensitivity_notes', j.sensitivity_notes,
      'claim_expires_at', case when j.assigned_to_membership_id = a.id then j.claim_expires_at end
    ) end,
    'payload', case when v_payload_allowed then (
      select jsonb_build_object(
        'current_task', p.current_task,
        'success_criteria', p.success_criteria,
        'output_format', p.output_format
      )
      from public.job_payloads p where p.job_id = j.id
    ) end,
    'models', case when v_payload_allowed then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'provider', m.provider,
        'display_name', m.display_name,
        'preference', jm.preference,
        'sort_order', jm.sort_order
      ) order by jm.preference desc, jm.sort_order, m.display_name)
      from public.job_models jm
      join public.models m
        on m.organization_id = jm.organization_id and m.id = jm.model_id
      where jm.job_id = j.id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'contexts', case when v_payload_allowed then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'kind', c.kind,
        'label', c.label,
        'text_content', c.text_content,
        'url', c.url,
        'sort_order', c.sort_order
      ) order by c.sort_order, c.created_at)
      from public.job_context_items c where c.job_id = j.id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'files', case when v_payload_allowed then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', f.id,
        'original_filename', f.safe_filename,
        'safe_filename', f.safe_filename,
        'description', f.description,
        'mime_type', f.mime_type,
        'size_bytes', f.size_bytes
      ) order by f.created_at)
      from public.job_files f
      where f.job_id = j.id and f.upload_status = 'ready' and f.cleanup_started_at is null
    ), '[]'::jsonb) else '[]'::jsonb end,
    'submissions', case when v_participant and not j.deletion_pending then coalesce((
      select jsonb_agg(jsonb_build_object(
        'model_used_text', s.model_used_text,
        'tools_used', s.tools_used,
        'response_text', s.response_text,
        'notes', s.notes,
        'revision_number', s.revision_number,
        'submitted_at', s.submitted_at,
        'files', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', sf.id,
            'original_filename', sf.safe_filename,
            'safe_filename', sf.safe_filename,
            'description', sf.description,
            'mime_type', sf.mime_type,
            'size_bytes', sf.size_bytes
          ) order by sf.created_at)
          from public.submission_files sf
          where sf.submission_id = s.id
            and sf.upload_status = 'ready'
            and sf.cleanup_started_at is null
        ), '[]'::jsonb)
      ) order by s.revision_number)
      from public.submissions s
      where s.job_id = j.id and s.status = 'submitted'
    ), '[]'::jsonb) else '[]'::jsonb end,
    'revision_requests', case when v_participant and not j.deletion_pending then coalesce((
      select jsonb_agg(jsonb_build_object(
        'instructions', r.instructions,
        'created_at', r.created_at,
        'resolved_at', r.resolved_at
      ) order by r.created_at)
      from public.revision_requests r where r.job_id = j.id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'pending_files', coalesce((
      select jsonb_agg(x.item order by x.created_at)
      from (
        select jsonb_build_object(
          'kind', 'job',
          'id', f.id,
          'original_filename', f.safe_filename,
          'mime_type', f.mime_type,
          'size_bytes', f.size_bytes,
          'upload_status', f.upload_status,
          'cleanup_started_at', f.cleanup_started_at,
          'stale', false
        ) as item, f.created_at
        from public.job_files f
        where f.job_id = j.id
          and a.id = j.created_by_membership_id
          and j.status = 'draft'
          and (f.upload_status = 'pending' or f.cleanup_started_at is not null)
        union all
        select jsonb_build_object(
          'kind', 'submission',
          'id', sf.id,
          'original_filename', sf.safe_filename,
          'mime_type', sf.mime_type,
          'size_bytes', sf.size_bytes,
          'upload_status', sf.upload_status,
          'cleanup_started_at', sf.cleanup_started_at,
          'stale', false
        ) as item, sf.created_at
        from public.submission_files sf
        join public.submissions draft on draft.id = sf.submission_id and draft.job_id = sf.job_id
        where sf.job_id = j.id
          and draft.status = 'draft'
          and draft.submitted_by_membership_id = a.id
          and j.assigned_to_membership_id = a.id
          and j.claim_expires_at > now()
        union all
        select jsonb_build_object(
          'kind', 'submission',
          'id', sf.id,
          'original_filename', sf.safe_filename,
          'mime_type', sf.mime_type,
          'size_bytes', sf.size_bytes,
          'upload_status', sf.upload_status,
          'cleanup_started_at', sf.cleanup_started_at,
          'stale', true
        ) as item, sf.created_at
        from public.submission_files sf
        join public.submissions draft on draft.id = sf.submission_id and draft.job_id = sf.job_id
        where sf.job_id = j.id
          and draft.status = 'draft'
          and (a.id = j.created_by_membership_id or a.role = 'admin')
          and not (
            j.assigned_to_membership_id = draft.submitted_by_membership_id
            and j.claim_expires_at > now()
            and exists (
              select 1 from public.memberships owner
              where owner.organization_id = j.organization_id
                and owner.id = draft.submitted_by_membership_id
                and owner.active
                and owner.user_id is not null
                and owner.claimed_user_id = owner.user_id
            )
          )
      ) x
    ), '[]'::jsonb),
    'permissions', jsonb_build_object(
      'update', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'draft',
      'publish', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'draft',
      'claim', not j.deletion_pending
        and a.id <> j.created_by_membership_id
        and j.status in ('open', 'claimed', 'revision_requested')
        and (j.assigned_to_membership_id is null or j.claim_expires_at <= now()),
      'extend', not j.deletion_pending and a.id = j.assigned_to_membership_id and j.claim_expires_at > now(),
      'release', not j.deletion_pending and a.id = j.assigned_to_membership_id and j.claim_expires_at > now(),
      'submit', not j.deletion_pending and a.id = j.assigned_to_membership_id
        and j.claim_expires_at > now()
        and j.status in ('claimed', 'revision_requested'),
      'accept', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'submitted',
      'revise', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'submitted',
      'cancel', not j.deletion_pending and (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status not in ('draft', 'accepted'),
      'reopen', not j.deletion_pending and (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status in ('submitted', 'revision_requested', 'cancelled')
        and (j.status <> 'cancelled' or j.published_at is not null),
      'follow_up', not j.deletion_pending and a.id = j.created_by_membership_id
        and j.status in ('submitted', 'revision_requested', 'accepted', 'cancelled')
        and exists (select 1 from public.submissions s where s.job_id = j.id and s.status = 'submitted'),
      'delete', (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status in ('draft', 'cancelled', 'accepted')
    )
  ) into result;
  return result;
end
$$;

create or replace function private.can_storage_upload(p_storage_path text, p_metadata jsonb)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  j public.jobs;
  jf public.job_files;
  sf public.submission_files;
  a public.memberships;
  s public.submissions;
begin
  -- The first lookup only discovers which job must be locked. Authorization is
  -- based on the reservation row re-read with a row lock after the job lock.
  select f.job_id into v_job_id
  from public.job_files f
  where f.storage_path = p_storage_path;
  if v_job_id is not null then
    -- begin_job_deletion() and file_cleanup_info() take FOR UPDATE on this job,
    -- so they wait for uploads already authorized and block future ones.
    select * into j from public.jobs where id = v_job_id for key share;
    if j.id is null then return false; end if;
    select * into jf
    from public.job_files f
    where f.storage_path = p_storage_path and f.job_id = j.id
    for update;
    a := private.locked_actor(j.organization_id);
    return jf.id is not null
      and jf.upload_status = 'pending'
      and jf.cleanup_started_at is null
      and coalesce(p_metadata ->> 'size', '') = jf.size_bytes::text
      and coalesce(p_metadata ->> 'mimetype', '') = jf.mime_type
      and a.id is not null
      and a.id = j.created_by_membership_id
      and a.id = jf.uploaded_by_membership_id
      and j.status = 'draft'
      and not j.deletion_pending;
  end if;

  select f.job_id into v_job_id
  from public.submission_files f
  where f.storage_path = p_storage_path;
  if v_job_id is null then return false; end if;

  select * into j from public.jobs where id = v_job_id for key share;
  if j.id is null then return false; end if;
  select * into sf
  from public.submission_files f
  where f.storage_path = p_storage_path and f.job_id = j.id
  for update;
  if sf.id is null
    or sf.upload_status <> 'pending'
    or sf.cleanup_started_at is not null
  then return false; end if;
  a := private.locked_actor(j.organization_id);
  select * into s
  from public.submissions
  where id = sf.submission_id and job_id = j.id;
  return a.id is not null
    and coalesce(p_metadata ->> 'size', '') = sf.size_bytes::text
    and coalesce(p_metadata ->> 'mimetype', '') = sf.mime_type
    and a.id = sf.uploaded_by_membership_id
    and a.id = j.assigned_to_membership_id
    and a.id = s.submitted_by_membership_id
    and s.status = 'draft'
    and j.status in ('claimed', 'revision_requested')
    and j.claim_expires_at > now()
    and not j.deletion_pending;
end
$$;

create or replace function private.can_storage_download(p_storage_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
  v_job_id uuid;
  v_submission_id uuid;
  v_uploader uuid;
begin
  select job.* into j
  from public.job_files f
  join public.jobs job on job.id = f.job_id and job.organization_id = f.organization_id
  where f.storage_path = p_storage_path
    and f.upload_status = 'ready'
    and f.cleanup_started_at is null;
  if j.id is not null then
    if j.deletion_pending then return false; end if;
    a := private.actor(j.organization_id);
    return private.can_payload(j)
      or (j.visibility = 'lab' and j.status <> 'draft' and a.id is not null);
  end if;

  select f.job_id, f.submission_id, f.uploaded_by_membership_id
  into v_job_id, v_submission_id, v_uploader
  from public.submission_files f
  where f.storage_path = p_storage_path
    and f.upload_status = 'ready'
    and f.cleanup_started_at is null;
  if v_job_id is null then return false; end if;
  select * into j from public.jobs where id = v_job_id;
  select * into s
  from public.submissions
  where id = v_submission_id and job_id = j.id;
  if j.id is null or s.id is null or j.deletion_pending then return false; end if;
  if s.status = 'submitted' then
    return private.can_payload(j);
  end if;
  if s.status <> 'draft' then return false; end if;
  a := private.actor(j.organization_id);
  return a.id is not null
    and a.id = v_uploader
    and a.id = s.submitted_by_membership_id
    and a.id = j.assigned_to_membership_id
    and j.status in ('claimed', 'revision_requested')
    and j.claim_expires_at > now();
end
$$;

create or replace function private.can_storage_delete(p_storage_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  v_job_id uuid;
  v_uploader uuid;
  v_submission_id uuid;
  s public.submissions;
  v_current_owner boolean;
begin
  select f.job_id, f.uploaded_by_membership_id
  into v_job_id, v_uploader
  from public.job_files f
  where f.storage_path = p_storage_path and f.cleanup_started_at is not null;
  if v_job_id is not null then
    select * into j from public.jobs where id = v_job_id;
    a := private.actor(j.organization_id);
    if a.id is null then return false; end if;
    return (j.deletion_pending and (a.id = j.created_by_membership_id or a.role = 'admin'))
      or (not j.deletion_pending and j.status = 'draft' and a.id = j.created_by_membership_id and a.id = v_uploader);
  end if;

  select f.job_id, f.uploaded_by_membership_id, f.submission_id
  into v_job_id, v_uploader, v_submission_id
  from public.submission_files f
  where f.storage_path = p_storage_path and f.cleanup_started_at is not null;
  if v_job_id is null then
    -- Upgrade/incident recovery: an object under the exact UUID job prefix may
    -- predate or outlive its metadata row. It is deletable only after that job
    -- enters its locked deletion workflow and only by its requester/admin.
    select job.* into j
    from public.jobs job
    where job.deletion_pending
      and p_storage_path like (job.organization_id::text || '/' || job.id::text || '/%')
    limit 1;
    if j.id is null then return false; end if;
    a := private.actor(j.organization_id);
    return a.id is not null
      and (a.id = j.created_by_membership_id or a.role = 'admin');
  end if;
  select * into j from public.jobs where id = v_job_id;
  a := private.actor(j.organization_id);
  if a.id is null then return false; end if;
  if j.deletion_pending then
    return a.id = j.created_by_membership_id or a.role = 'admin';
  end if;
  select * into s from public.submissions where id = v_submission_id and job_id = j.id;
  if s.id is null or s.status <> 'draft' then return false; end if;
  v_current_owner := coalesce(j.assigned_to_membership_id = s.submitted_by_membership_id
    and j.status in ('claimed', 'revision_requested')
    and j.claim_expires_at > now()
    and exists (
      select 1
      from public.memberships owner
      where owner.organization_id = j.organization_id
        and owner.id = s.submitted_by_membership_id
        and owner.active
        and owner.user_id is not null
        and owner.claimed_user_id = owner.user_id
    ), false);
  return (
    a.id = v_uploader
    and a.id = j.assigned_to_membership_id
    and a.id = s.submitted_by_membership_id
    and v_current_owner
  ) or (
    not j.deletion_pending
    and not v_current_owner
    and (a.id = j.created_by_membership_id or a.role = 'admin')
  );
end
$$;

-- RLS policies on file/submission tables must not query hidden jobs columns as
-- the invoking browser role. These ID-only predicates evaluate the complete
-- relationship under the function owner while returning only a boolean.
create or replace function private.can_read_job_file(p_file_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.job_files f
    join public.jobs j
      on j.id = f.job_id and j.organization_id = f.organization_id
    where f.id = p_file_id
      and (
        (
          f.upload_status = 'ready'
          and f.cleanup_started_at is null
          and not j.deletion_pending
          and (
            (
              j.visibility = 'lab'
              and j.status <> 'draft'
              and (private.actor(j.organization_id)).id is not null
            )
            or private.can_payload_job(j.id)
          )
        )
        or (
          j.status = 'draft'
          and not j.deletion_pending
          and f.uploaded_by_membership_id = (private.actor(j.organization_id)).id
          and j.created_by_membership_id = (private.actor(j.organization_id)).id
        )
      )
  )
$$;

create or replace function private.can_read_submission(p_submission_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.submissions s
    join public.jobs j on j.id = s.job_id
    where s.id = p_submission_id
      and not j.deletion_pending
      and (
        (s.status = 'submitted' and private.can_payload_job(j.id))
        or (
          s.status = 'draft'
          and s.submitted_by_membership_id = (private.actor(j.organization_id)).id
          and j.assigned_to_membership_id = (private.actor(j.organization_id)).id
          and j.status in ('claimed', 'revision_requested')
          and j.claim_expires_at > now()
        )
      )
  )
$$;

create or replace function private.can_read_submission_file(p_file_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.submission_files f
    join public.jobs j
      on j.id = f.job_id and j.organization_id = f.organization_id
    join public.submissions s
      on s.id = f.submission_id and s.job_id = j.id
    where f.id = p_file_id
      and not j.deletion_pending
      and (
        (
          f.upload_status = 'ready'
          and f.cleanup_started_at is null
          and (
            (s.status = 'submitted' and private.can_payload_job(j.id))
            or (
              s.status = 'draft'
              and s.submitted_by_membership_id = (private.actor(j.organization_id)).id
              and f.uploaded_by_membership_id = (private.actor(j.organization_id)).id
              and j.assigned_to_membership_id = (private.actor(j.organization_id)).id
              and j.status in ('claimed', 'revision_requested')
              and j.claim_expires_at > now()
            )
          )
        )
        or (
          s.status = 'draft'
          and s.submitted_by_membership_id = (private.actor(j.organization_id)).id
          and f.uploaded_by_membership_id = (private.actor(j.organization_id)).id
          and j.assigned_to_membership_id = (private.actor(j.organization_id)).id
          and j.status in ('claimed', 'revision_requested')
          and j.claim_expires_at > now()
        )
      )
  )
$$;

create or replace function public.reserve_job_file(
  p_job_id uuid,
  p_filename text,
  p_mime_type text,
  p_size_bytes bigint,
  p_description text default null
) returns table(id uuid, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  fid uuid := gen_random_uuid();
  v_safe text;
  v_path text;
  v_total bigint;
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  select * into j from public.jobs where public.jobs.id = p_job_id for update;
  if j.id is null then raise exception 'file not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
    or not private.file_is_allowed(p_filename, p_mime_type)
    or p_size_bytes is null or p_size_bytes not between 1 and 26214400
    or length(coalesce(v_description, '')) > 1000
  then
    raise exception 'file not allowed';
  end if;

  select coalesce((select sum(f.size_bytes) from public.job_files f where f.job_id = j.id), 0)
       + coalesce((select sum(f.size_bytes) from public.submission_files f where f.job_id = j.id), 0)
  into v_total;
  if v_total + p_size_bytes > 104857600 then raise exception 'job file limit exceeded'; end if;

  v_safe := private.safe_filename(p_filename);
  v_path := j.organization_id || '/' || j.id || '/job/' || gen_random_uuid();
  insert into public.job_files(
    id, job_id, organization_id, uploaded_by_membership_id, storage_path,
    original_filename, safe_filename, description, mime_type, size_bytes
  ) values (
    fid, j.id, j.organization_id, a.id, v_path,
    p_filename, v_safe, v_description, p_mime_type, p_size_bytes
  );
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, j.id, a.id, 'job_file_reserved', jsonb_build_object('file_id', fid));
  return query select fid, v_path;
end
$$;

create or replace function public.finalize_job_file(p_file_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  f public.job_files;
  j public.jobs;
  a public.memberships;
  o storage.objects;
begin
  select jf.job_id into v_job_id from public.job_files jf where jf.id = p_file_id;
  if v_job_id is null then raise exception 'file not found'; end if;
  select * into j from public.jobs where id = v_job_id for update;
  select * into f from public.job_files where id = p_file_id for update;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or a.id is distinct from f.uploaded_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
    or f.upload_status <> 'pending'
    or f.cleanup_started_at is not null
  then
    raise exception 'file not found';
  end if;
  select * into o from storage.objects
  where bucket_id = 'job-files' and name = f.storage_path;
  if o.id is null
    or coalesce(o.metadata ->> 'size', '') !~ '^[0-9]+$'
    or (o.metadata ->> 'size')::bigint <> f.size_bytes
    or coalesce(o.metadata ->> 'mimetype', '') <> f.mime_type
  then
    raise exception 'uploaded object does not match reservation';
  end if;
  update public.job_files set upload_status = 'ready', ready_at = now() where id = f.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, j.id, a.id, 'job_file_finalized', jsonb_build_object('file_id', f.id));
end
$$;

create or replace function public.reserve_submission_file(
  p_job_id uuid,
  p_filename text,
  p_mime_type text,
  p_size_bytes bigint,
  p_description text default null
) returns table(id uuid, storage_path text, submission_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  sid uuid;
  fid uuid := gen_random_uuid();
  v_safe text;
  v_path text;
  v_total bigint;
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  select * into j from public.jobs where public.jobs.id = p_job_id for update;
  if j.id is null then raise exception 'file not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null or j.claim_expires_at <= now()
    or j.deletion_pending
    or not private.file_is_allowed(p_filename, p_mime_type)
    or p_size_bytes is null or p_size_bytes not between 1 and 26214400
    or length(coalesce(v_description, '')) > 1000
  then
    raise exception 'file not allowed';
  end if;

  select s.id into sid
  from public.submissions s
  where s.job_id = j.id and s.submitted_by_membership_id = a.id and s.status = 'draft'
  for update;
  if sid is null then
    insert into public.submissions(job_id, organization_id, submitted_by_membership_id)
    values (j.id, j.organization_id, a.id) returning public.submissions.id into sid;
  end if;

  select coalesce((select sum(f.size_bytes) from public.job_files f where f.job_id = j.id), 0)
       + coalesce((select sum(f.size_bytes) from public.submission_files f where f.job_id = j.id), 0)
  into v_total;
  if v_total + p_size_bytes > 104857600 then raise exception 'job file limit exceeded'; end if;

  v_safe := private.safe_filename(p_filename);
  v_path := j.organization_id || '/' || j.id || '/submission/' || sid || '/' || gen_random_uuid();
  insert into public.submission_files(
    id, submission_id, job_id, organization_id, uploaded_by_membership_id,
    storage_path, original_filename, safe_filename, description, mime_type, size_bytes
  ) values (
    fid, sid, j.id, j.organization_id, a.id,
    v_path, p_filename, v_safe, v_description, p_mime_type, p_size_bytes
  );
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, j.id, a.id, 'submission_file_reserved', jsonb_build_object('file_id', fid));
  return query select fid, v_path, sid;
end
$$;

create or replace function public.finalize_submission_file(p_file_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  f public.submission_files;
  j public.jobs;
  a public.memberships;
  s public.submissions;
  o storage.objects;
begin
  select sf.job_id into v_job_id from public.submission_files sf where sf.id = p_file_id;
  if v_job_id is null then raise exception 'file not found'; end if;
  select * into j from public.jobs where id = v_job_id for update;
  select * into f from public.submission_files where id = p_file_id for update;
  select * into s from public.submissions where id = f.submission_id and job_id = j.id;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or a.id is distinct from f.uploaded_by_membership_id
    or a.id is distinct from s.submitted_by_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null or j.claim_expires_at <= now()
    or j.deletion_pending
    or s.status <> 'draft'
    or f.upload_status <> 'pending'
    or f.cleanup_started_at is not null
  then
    raise exception 'file not found';
  end if;
  select * into o from storage.objects
  where bucket_id = 'job-files' and name = f.storage_path;
  if o.id is null
    or coalesce(o.metadata ->> 'size', '') !~ '^[0-9]+$'
    or (o.metadata ->> 'size')::bigint <> f.size_bytes
    or coalesce(o.metadata ->> 'mimetype', '') <> f.mime_type
  then
    raise exception 'uploaded object does not match reservation';
  end if;
  update public.submission_files set upload_status = 'ready', ready_at = now() where id = f.id;
  insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, j.id, a.id, 'submission_file_finalized', jsonb_build_object('file_id', f.id));
end
$$;

create or replace function public.file_download_info(p_file_id uuid, p_kind text)
returns table(storage_path text, original_filename text, mime_type text, size_bytes bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_path text;
begin
  if p_kind = 'job' then
    select f.storage_path into v_path
    from public.job_files f
    where f.id = p_file_id
      and f.upload_status = 'ready'
      and f.cleanup_started_at is null;
    if v_path is null or not private.can_storage_download(v_path) then
      raise exception 'file not found';
    end if;
    return query
    select f.storage_path, f.original_filename, f.mime_type, f.size_bytes
    from public.job_files f where f.id = p_file_id;
  elsif p_kind = 'submission' then
    select f.storage_path into v_path
    from public.submission_files f
    where f.id = p_file_id
      and f.upload_status = 'ready'
      and f.cleanup_started_at is null;
    if v_path is null or not private.can_storage_download(v_path) then
      raise exception 'file not found';
    end if;
    return query
    select f.storage_path, f.original_filename, f.mime_type, f.size_bytes
    from public.submission_files f where f.id = p_file_id;
  else
    raise exception 'invalid file kind';
  end if;
end
$$;

create or replace function public.file_cleanup_info(p_file_id uuid, p_kind text)
returns table(storage_path text, original_filename text, mime_type text, size_bytes bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  j public.jobs;
  a public.memberships;
  jf public.job_files;
  sf public.submission_files;
  s public.submissions;
  v_current_owner boolean;
begin
  if p_kind = 'job' then
    select f.job_id into v_job_id from public.job_files f where f.id = p_file_id;
    if v_job_id is null then raise exception 'file not found'; end if;
    select * into j from public.jobs where id = v_job_id for update;
    select * into jf from public.job_files where id = p_file_id for update;
    a := private.locked_actor(j.organization_id);
    if a.id is null
      or a.id is distinct from j.created_by_membership_id
      or a.id is distinct from jf.uploaded_by_membership_id
      or j.status <> 'draft'
      or j.deletion_pending
    then raise exception 'file not found'; end if;
    update public.job_files set cleanup_started_at = coalesce(cleanup_started_at, now()) where id = jf.id;
    return query select jf.storage_path, jf.original_filename, jf.mime_type, jf.size_bytes;
  elsif p_kind = 'submission' then
    select f.job_id into v_job_id from public.submission_files f where f.id = p_file_id;
    if v_job_id is null then raise exception 'file not found'; end if;
    select * into j from public.jobs where id = v_job_id for update;
    select * into sf from public.submission_files where id = p_file_id for update;
    select * into s from public.submissions where id = sf.submission_id and job_id = j.id;
    a := private.locked_actor(j.organization_id);
    v_current_owner := coalesce(j.assigned_to_membership_id = s.submitted_by_membership_id
      and j.status in ('claimed', 'revision_requested')
      and j.claim_expires_at > now()
      and exists (
        select 1 from public.memberships owner
        where owner.organization_id = j.organization_id
          and owner.id = s.submitted_by_membership_id
          and owner.active
          and owner.user_id is not null
          and owner.claimed_user_id = owner.user_id
      ), false);
    if a.id is null or s.id is null or s.status <> 'draft' or j.deletion_pending
      or not (
        (
          v_current_owner
          and a.id = j.assigned_to_membership_id
          and a.id = sf.uploaded_by_membership_id
          and a.id = s.submitted_by_membership_id
        )
        or (
          not v_current_owner
          and (a.id = j.created_by_membership_id or a.role = 'admin')
        )
      )
    then raise exception 'file not found'; end if;
    update public.submission_files set cleanup_started_at = coalesce(cleanup_started_at, now()) where id = sf.id;
    return query select sf.storage_path, sf.original_filename, sf.mime_type, sf.size_bytes;
  else
    raise exception 'invalid file kind';
  end if;
end
$$;

create or replace function public.delete_file_record(p_file_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  v_path text;
  j public.jobs;
  a public.memberships;
  jf public.job_files;
  sf public.submission_files;
  s public.submissions;
  v_current_owner boolean;
begin
  if p_kind = 'job' then
    select f.job_id into v_job_id from public.job_files f where f.id = p_file_id;
    if v_job_id is null then return; end if;
    select * into j from public.jobs where id = v_job_id for update;
    select * into jf from public.job_files where id = p_file_id for update;
    a := private.locked_actor(j.organization_id);
    if a.id is null
      or a.id is distinct from j.created_by_membership_id
      or a.id is distinct from jf.uploaded_by_membership_id
    then return; end if;
    if j.status <> 'draft'
      or j.deletion_pending
      or jf.cleanup_started_at is null
    then raise exception 'file not deletable'; end if;
    v_path := jf.storage_path;
    if exists (select 1 from storage.objects o where o.bucket_id = 'job-files' and o.name = v_path) then
      raise exception 'storage cleanup required';
    end if;
    delete from public.job_files where id = jf.id;
  elsif p_kind = 'submission' then
    select f.job_id into v_job_id from public.submission_files f where f.id = p_file_id;
    if v_job_id is null then return; end if;
    select * into j from public.jobs where id = v_job_id for update;
    select * into sf from public.submission_files where id = p_file_id for update;
    select * into s from public.submissions where id = sf.submission_id and job_id = j.id;
    a := private.locked_actor(j.organization_id);
    v_current_owner := coalesce(j.assigned_to_membership_id = s.submitted_by_membership_id
      and j.status in ('claimed', 'revision_requested')
      and j.claim_expires_at > now()
      and exists (
        select 1 from public.memberships owner
        where owner.organization_id = j.organization_id
          and owner.id = s.submitted_by_membership_id
          and owner.active
          and owner.user_id is not null
          and owner.claimed_user_id = owner.user_id
      ), false);
    if a.id is null or not (
        (
          v_current_owner
          and a.id = j.assigned_to_membership_id
          and a.id = sf.uploaded_by_membership_id
          and a.id = s.submitted_by_membership_id
        )
        or (
          not v_current_owner
          and (a.id = j.created_by_membership_id or a.role = 'admin')
        )
      )
    then return; end if;
    if s.id is null or s.status <> 'draft'
      or j.deletion_pending or sf.cleanup_started_at is null
    then raise exception 'file not deletable'; end if;
    v_path := sf.storage_path;
    if exists (select 1 from storage.objects o where o.bucket_id = 'job-files' and o.name = v_path) then
      raise exception 'storage cleanup required';
    end if;
    delete from public.submission_files where id = sf.id;
  else
    raise exception 'invalid file kind';
  end if;
end
$$;

create or replace function public.begin_job_deletion(p_job_id uuid)
returns table(kind text, file_id uuid, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  v_was_pending boolean;
begin
  -- FOR UPDATE conflicts with the upload policy's FOR KEY SHARE. Once this
  -- lock is acquired, all previously authorized uploads have finished and the
  -- committed deletion_pending flag prevents any new upload authorization.
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then return; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or (a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
  then return; end if;
  if j.status not in ('draft', 'cancelled', 'accepted') then
    raise exception 'not deletable';
  end if;
  if exists (select 1 from public.jobs child where child.parent_job_id = j.id) then
    raise exception 'job has follow-up children';
  end if;

  v_was_pending := j.deletion_pending;
  update public.jobs
  set deletion_pending = true,
      deletion_started_at = coalesce(deletion_started_at, now()),
      updated_at = now()
  where id = j.id;
  update public.job_files
  set cleanup_started_at = coalesce(cleanup_started_at, now())
  where job_id = j.id;
  update public.submission_files
  set cleanup_started_at = coalesce(cleanup_started_at, now())
  where job_id = j.id;

  if not v_was_pending then
    insert into public.audit_events(organization_id, job_id, actor_membership_id, event_type)
    values (j.organization_id, j.id, a.id, 'job_deletion_started');
  end if;
  return query
  select 'job'::text, f.id, f.storage_path from public.job_files f where f.job_id = j.id
  union all
  select 'submission'::text, f.id, f.storage_path from public.submission_files f where f.job_id = j.id
  union all
  select 'orphan'::text, null::uuid, o.name
  from storage.objects o
  where o.bucket_id = 'job-files'
    and o.name like (j.organization_id::text || '/' || j.id::text || '/%')
    and not exists (select 1 from public.job_files f where f.job_id = j.id and f.storage_path = o.name)
    and not exists (select 1 from public.submission_files f where f.job_id = j.id and f.storage_path = o.name);
end
$$;

create or replace function public.delete_job_after_storage_cleanup(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then return; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or (a.id is distinct from j.created_by_membership_id and a.role <> 'admin')
  then return; end if;
  if j.status not in ('draft', 'cancelled', 'accepted') or not j.deletion_pending then
    raise exception 'not deletable';
  end if;
  -- Every legacy and hardened reservation uses <organization>/<job>/ as its
  -- prefix. Refuse metadata deletion for *any* object under that prefix, even
  -- if an earlier bug or interrupted migration left no matching file row.
  if exists (
    select 1
    from storage.objects o
    where o.bucket_id = 'job-files'
      and (
        o.name like (j.organization_id::text || '/' || j.id::text || '/%')
        or exists (select 1 from public.job_files f where f.job_id = j.id and f.storage_path = o.name)
        or exists (select 1 from public.submission_files f where f.job_id = j.id and f.storage_path = o.name)
      )
  ) then
    raise exception 'storage cleanup required';
  end if;
  if exists (select 1 from public.job_files f where f.job_id = j.id and f.cleanup_started_at is null)
    or exists (select 1 from public.submission_files f where f.job_id = j.id and f.cleanup_started_at is null)
  then
    raise exception 'cleanup manifest incomplete';
  end if;

  delete from public.jobs where id = j.id;
  insert into public.audit_events(organization_id, actor_membership_id, event_type, metadata)
  values (j.organization_id, a.id, 'job_deleted', jsonb_build_object('job_id', j.id));
end
$$;

drop policy if exists org_read on public.organizations;
create policy org_read on public.organizations
for select to authenticated
using ((private.actor(id)).id is not null);

drop policy if exists membership_self on public.memberships;
create policy membership_self on public.memberships
for select to authenticated
using (user_id = auth.uid() and claimed_user_id = auth.uid() and active);

drop policy if exists model_org on public.models;
create policy model_org on public.models
for select to authenticated
using ((private.actor(organization_id)).id is not null);

drop policy if exists member_models_org on public.member_models;
create policy member_models_org on public.member_models
for select to authenticated
using (
  (private.actor(organization_id)).id = membership_id
  or (private.actor(organization_id)).role = 'admin'
);

drop policy if exists jobs_org on public.jobs;
create policy jobs_org on public.jobs
for select to authenticated
using (
  (private.actor(organization_id)).id is not null
  and (
    status <> 'draft'
    or created_by_membership_id = (private.actor(organization_id)).id
    or (private.actor(organization_id)).role = 'admin'
  )
  and (
    not deletion_pending
    or created_by_membership_id = (private.actor(organization_id)).id
    or (private.actor(organization_id)).role = 'admin'
  )
);

drop policy if exists payload_authorized on public.job_payloads;
create policy payload_authorized on public.job_payloads
for select to authenticated
using (private.can_read_job_content(job_id));

drop policy if exists job_models_org on public.job_models;
create policy job_models_org on public.job_models
for select to authenticated
using (private.can_read_job_content(job_id));

drop policy if exists context_authorized on public.job_context_items;
create policy context_authorized on public.job_context_items
for select to authenticated
using (private.can_read_job_content(job_id));

drop policy if exists job_files_authorized on public.job_files;
create policy job_files_authorized on public.job_files
for select to authenticated
using (private.can_read_job_file(id));

drop policy if exists submissions_authorized on public.submissions;
create policy submissions_authorized on public.submissions
for select to authenticated
using (private.can_read_submission(id));

drop policy if exists submission_files_authorized on public.submission_files;
create policy submission_files_authorized on public.submission_files
for select to authenticated
using (private.can_read_submission_file(id));

drop policy if exists revision_authorized on public.revision_requests;
create policy revision_authorized on public.revision_requests
for select to authenticated
using (private.can_read_protected_job(job_id));

drop policy if exists notification_own on public.notifications;
create policy notification_own on public.notifications
for select to authenticated
using ((private.actor(organization_id)).id = recipient_membership_id);

drop policy if exists audit_admin on public.audit_events;
create policy audit_admin on public.audit_events
for select to authenticated
using ((private.actor(organization_id)).role = 'admin');

drop policy if exists exact_reserved_upload on storage.objects;
create policy exact_reserved_upload on storage.objects
for insert to authenticated
with check (bucket_id = 'job-files' and private.can_storage_upload(name, metadata));

do $$
begin
  if to_regprocedure('storage.allow_any_operation(text[])') is null then
    raise exception using
      message = 'Supabase Storage operation-aware RLS helpers are required',
      hint = 'Update the Supabase Storage service/schema before applying this migration.';
  end if;
end
$$;

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
      private.can_storage_delete(name)
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
using (bucket_id = 'job-files' and private.can_storage_delete(name));

-- Remove broad column access to sensitive identifiers and Storage paths.
revoke select on public.memberships from authenticated;
grant select(
  id, organization_id, display_name, role, active, capabilities,
  notification_preferences, created_at, updated_at
) on public.memberships to authenticated;

revoke select on public.jobs from authenticated;
grant select(
  id, organization_id, title, listing_summary, status, visibility, sensitivity,
  effort, required_tools, deadline, published_at, created_at, updated_at,
  deletion_pending
) on public.jobs to authenticated;

revoke select on public.job_files from authenticated;
grant select(
  id, job_id, safe_filename, description, mime_type,
  size_bytes, upload_status, created_at, ready_at, cleanup_started_at
) on public.job_files to authenticated;

revoke select on public.submission_files from authenticated;
grant select(
  id, submission_id, job_id, safe_filename, description,
  mime_type, size_bytes, upload_status, created_at, ready_at, cleanup_started_at
) on public.submission_files to authenticated;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function
  private.actor(uuid),
  private.can_payload(public.jobs),
  private.can_payload_job(uuid),
  private.can_read_job_content(uuid),
  private.can_read_protected_job(uuid),
  private.can_read_job_file(uuid),
  private.can_read_submission(uuid),
  private.can_read_submission_file(uuid),
  private.can_storage_upload(text, jsonb),
  private.can_storage_download(text),
  private.can_storage_delete(text)
to authenticated;

revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.claim_available_memberships(),
  public.my_active_memberships(),
  public.create_draft_job(uuid, jsonb),
  public.update_draft_job(uuid, jsonb),
  public.publish_job(uuid),
  public.claim_job(uuid),
  public.release_job(uuid),
  public.extend_claim(uuid),
  public.create_submission_draft(uuid),
  public.submit_result(uuid, text, text, text, text[]),
  public.request_revision(uuid, text),
  public.accept_job(uuid),
  public.cancel_job(uuid),
  public.reopen_job(uuid),
  public.mark_notification_read(uuid),
  public.dashboard_jobs(uuid, text),
  public.job_workspace(uuid),
  public.update_profile(uuid, text, text[], uuid[], jsonb),
  public.admin_upsert_membership(uuid, text, public.member_role),
  public.admin_update_membership(uuid, uuid, public.member_role, boolean),
  public.admin_memberships(uuid),
  public.create_follow_up_draft(uuid),
  public.reserve_job_file(uuid, text, text, bigint, text),
  public.finalize_job_file(uuid),
  public.reserve_submission_file(uuid, text, text, bigint, text),
  public.finalize_submission_file(uuid),
  public.file_download_info(uuid, text),
  public.file_cleanup_info(uuid, text),
  public.delete_file_record(uuid, text),
  public.begin_job_deletion(uuid),
  public.delete_job_after_storage_cleanup(uuid)
to authenticated;

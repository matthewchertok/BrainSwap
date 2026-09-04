-- A shared chat is the primary handoff context. Drafts may remain incomplete,
-- but publication now requires exactly one valid protected chat link.
-- Requester notes are protected alongside the prompt, and new job attachments
-- are limited to one private ZIP reservation per draft.

alter table public.job_payloads
  add column if not exists helper_instructions text not null default '';

alter table public.job_payloads
  add constraint job_payloads_helper_instructions_limit
  check (length(helper_instructions) <= 25000) not valid;
alter table public.job_payloads
  validate constraint job_payloads_helper_instructions_limit;

update storage.buckets
set public = false,
    file_size_limit = 26214400,
    allowed_mime_types = array[
      'application/pdf',
      'text/plain',
      'text/markdown',
      'text/csv',
      'application/json',
      'image/png',
      'image/jpeg',
      'image/webp',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/zip',
      'application/x-zip-compressed'
    ]
where id = 'job-files';

create or replace function private.job_attachment_zip_is_allowed(
  p_filename text,
  p_mime_type text
) returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
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

  return lower(substring(p_filename from '\.([A-Za-z0-9]+)$')) = 'zip'
    and p_mime_type in ('application/zip', 'application/x-zip-compressed');
end
$$;

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
  v_prompt text;
  v_helper_instructions text;
  v_chat_url text;
  v_preferred text;
  v_acceptable text;
  v_deadline_text text;
  v_deadline timestamptz;
begin
  if jsonb_typeof(p_input) is distinct from 'object'
    or jsonb_typeof(p_input -> 'title') is distinct from 'string'
    or jsonb_typeof(p_input -> 'task_summary') is distinct from 'string'
    or jsonb_typeof(p_input -> 'prompt') is distinct from 'string'
    or jsonb_typeof(p_input -> 'helper_instructions') is distinct from 'string'
    or jsonb_typeof(p_input -> 'chat_url') is distinct from 'string'
    or jsonb_typeof(p_input -> 'preferred_model_text') is distinct from 'string'
    or jsonb_typeof(p_input -> 'acceptable_models_text') is distinct from 'string'
    or coalesce(jsonb_typeof(p_input -> 'deadline'), 'null') not in ('null', 'string')
  then
    raise exception 'invalid draft input';
  end if;

  v_title := btrim(coalesce(p_input ->> 'title', ''));
  v_summary := btrim(coalesce(p_input ->> 'task_summary', ''));
  v_prompt := coalesce(p_input ->> 'prompt', '');
  v_helper_instructions := coalesce(p_input ->> 'helper_instructions', '');
  v_chat_url := btrim(coalesce(p_input ->> 'chat_url', ''));
  v_preferred := btrim(coalesce(p_input ->> 'preferred_model_text', ''));
  v_acceptable := btrim(coalesce(p_input ->> 'acceptable_models_text', ''));

  if length(v_title) > 120
    or length(v_summary) > 1000
    or length(v_prompt) > 100000
    or length(v_helper_instructions) > 25000
    or length(v_preferred) > 200
    or length(v_acceptable) > 1000
    or (v_chat_url <> '' and not private.valid_https_url(v_chat_url))
  then
    raise exception 'invalid draft value';
  end if;

  v_deadline_text := nullif(btrim(coalesce(p_input ->> 'deadline', '')), '');
  if v_deadline_text is not null then
    if v_deadline_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$'
    then
      raise exception 'deadline must be an ISO-8601 date-time with explicit timezone';
    end if;
    begin
      v_deadline := v_deadline_text::timestamptz;
    exception when others then
      raise exception 'invalid deadline';
    end;
    if v_deadline <= now() then raise exception 'deadline must be in the future'; end if;
  end if;

  update public.jobs
  set title = v_title,
      listing_summary = v_summary,
      preferred_model_text = v_preferred,
      acceptable_models_text = v_acceptable,
      visibility = 'claimed_only',
      sensitivity = 'general',
      sensitivity_notes = null,
      effort = 'medium',
      required_tools = '{}'::text[],
      deadline = v_deadline,
      data_handling_acknowledged_at = coalesce(data_handling_acknowledged_at, now()),
      acknowledgement_version = 'brainswap-default-public-sharing-v1',
      updated_at = now()
  where id = p_job_id and organization_id = p_organization_id;

  update public.job_payloads
  set prompt = v_prompt,
      helper_instructions = v_helper_instructions,
      success_criteria = '',
      output_format = '',
      updated_at = now()
  where job_id = p_job_id;

  delete from public.job_models where job_id = p_job_id;
  delete from public.job_context_items
  where job_id = p_job_id and kind <> 'previous_job';
  if v_chat_url <> '' then
    insert into public.job_context_items(
      organization_id, job_id, kind, label, url, sort_order
    ) values (
      p_organization_id, p_job_id, 'shared_chat', 'Link to chat', v_chat_url, 0
    );
  end if;
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
  if j.id is null then raise exception 'not authorized'; end if;
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
    or length(btrim(p.prompt)) not between 1 and 100000
    or length(p.helper_instructions) > 25000
    or length(btrim(j.preferred_model_text)) not between 1 and 200
    or (j.deadline is not null and j.deadline <= now())
    or exists (
      select 1 from public.job_context_items c
      where c.job_id = j.id
        and c.kind not in ('shared_chat', 'previous_job')
    )
    or (select count(*) from public.job_context_items c
        where c.job_id = j.id and c.kind = 'shared_chat') <> 1
    or exists (
      select 1 from public.job_context_items c
      where c.job_id = j.id and c.kind = 'shared_chat'
        and (c.url is null or not private.valid_https_url(c.url))
    )
    or exists (
      select 1 from public.job_files f
      where f.job_id = j.id
        and (f.upload_status <> 'ready' or f.cleanup_started_at is not null)
    )
  then
    raise exception 'job is incomplete';
  end if;

  update public.jobs
  set status = 'open',
      visibility = 'claimed_only', sensitivity = 'general',
      sensitivity_notes = null, effort = 'medium', required_tools = '{}'::text[],
      published_at = now(), updated_at = now()
  where id = j.id;

  insert into public.notifications(
    organization_id, recipient_membership_id, job_id, type, message
  )
  select j.organization_id, m.id, j.id, 'new_job', 'A new BrainSwap job is available.'
  from public.memberships m
  where m.organization_id = j.organization_id
    and m.active
    and m.user_id is not null
    and m.claimed_user_id = m.user_id
    and m.id <> j.created_by_membership_id
    and m.notification_preferences -> 'new_matching_jobs' = 'true'::jsonb;

  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type
  ) values (j.organization_id, j.id, a.id, 'job_published');
end
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
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  select * into j from public.jobs where public.jobs.id = p_job_id for update;
  if j.id is null then raise exception 'file not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
    or not private.job_attachment_zip_is_allowed(p_filename, p_mime_type)
    or p_size_bytes is null or p_size_bytes not between 1 and 26214400
    or length(coalesce(v_description, '')) > 1000
    or exists (select 1 from public.job_files f where f.job_id = j.id)
  then
    raise exception 'file not allowed';
  end if;

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

-- Raw binary uploads expose an exact contentLength during Storage preflight.
-- Keep the reservation-size check and accept the completed-object `size` key
-- used by Storage when policies are re-evaluated against persisted metadata.
create or replace function private.can_storage_upload(
  p_storage_path text,
  p_metadata jsonb
) returns boolean
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
  v_latest_id uuid;
  v_upload_size text := coalesce(p_metadata ->> 'contentLength', p_metadata ->> 'size', '');
begin
  select f.job_id into v_job_id
  from public.job_files f where f.storage_path = p_storage_path;
  if v_job_id is not null then
    select * into j from public.jobs where id = v_job_id for key share;
    if j.id is null then return false; end if;
    select * into jf from public.job_files f
    where f.storage_path = p_storage_path and f.job_id = j.id for update;
    a := private.locked_actor(j.organization_id);
    return jf.id is not null
      and jf.upload_status = 'pending' and jf.cleanup_started_at is null
      and v_upload_size = jf.size_bytes::text
      and coalesce(p_metadata ->> 'mimetype', '') = jf.mime_type
      and a.id is not null and a.id = j.created_by_membership_id
      and a.id = jf.uploaded_by_membership_id
      and j.status = 'draft' and not j.deletion_pending;
  end if;

  select f.job_id into v_job_id
  from public.submission_files f where f.storage_path = p_storage_path;
  if v_job_id is null then return false; end if;
  select * into j from public.jobs where id = v_job_id for key share;
  if j.id is null then return false; end if;
  select * into sf from public.submission_files f
  where f.storage_path = p_storage_path and f.job_id = j.id for update;
  if sf.id is null or sf.upload_status <> 'pending' or sf.cleanup_started_at is not null
  then return false; end if;
  a := private.locked_actor(j.organization_id);
  select * into s from public.submissions
  where id = sf.submission_id and job_id = j.id;
  select submitted.id into v_latest_id
  from public.submissions submitted
  where submitted.job_id = j.id and submitted.status = 'submitted'
  order by submitted.revision_number desc, submitted.submitted_at desc limit 1;
  return a.id is not null
    and a.id = sf.uploaded_by_membership_id
    and a.id = s.submitted_by_membership_id
    and v_upload_size = sf.size_bytes::text
    and coalesce(p_metadata ->> 'mimetype', '') = sf.mime_type
    and not j.deletion_pending
    and (
      (s.status = 'draft'
        and a.id = j.assigned_to_membership_id
        and j.status in ('claimed', 'revision_requested')
        and j.claim_expires_at > now())
      or (s.status = 'submitted'
        and s.id = v_latest_id
        and j.status = 'submitted'
        and j.requester_action_at is null
        and s.edit_locked_at is null)
    );
end
$$;

revoke all on function private.job_attachment_zip_is_allowed(text, text)
  from public, anon, authenticated;


-- BrainSwap workflow simplification and profile/result hardening.
-- This migration is additive: legacy columns and normalized job-model rows are
-- retained for existing records, but new application writes use the fields and
-- RPCs defined here.

alter table public.memberships
  add column if not exists bio text;

alter table public.memberships
  drop constraint if exists memberships_bio_limit,
  add constraint memberships_bio_limit
    check (bio is null or length(bio) <= 2000) not valid;

alter table public.jobs
  add column if not exists preferred_model_text text not null default '',
  add column if not exists acceptable_models_text text not null default '',
  add column if not exists requester_action_at timestamptz;

alter table public.job_payloads
  add column if not exists prompt text not null default '';

alter table public.submissions
  add column if not exists reasoning_effort text,
  add column if not exists reasoning_effort_other text,
  add column if not exists edited_at timestamptz,
  add column if not exists edit_locked_at timestamptz;

-- A follow-up child proves that the requester already acted on the parent's
-- finalized result. Preserve that pre-migration decision instead of granting
-- its author a new correction window when the edit-lock columns are added.
with prior_follow_ups as (
  select child.parent_job_id as job_id, min(child.created_at) as responded_at
  from public.jobs child
  where child.parent_job_id is not null
  group by child.parent_job_id
)
update public.jobs parent
set requester_action_at = coalesce(parent.requester_action_at, follow_up.responded_at)
from prior_follow_ups follow_up
where parent.id = follow_up.job_id
  and parent.status = 'submitted';

update public.submissions submission
set edit_locked_at = coalesce(submission.edit_locked_at, parent.requester_action_at)
from public.jobs parent
where submission.job_id = parent.id
  and submission.status = 'submitted'
  and parent.requester_action_at is not null;

create or replace function private.merge_legacy_prompt(
  p_success_criteria text,
  p_output_format text
) returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select concat_ws(E'\n\n',
    case when length(coalesce(p_success_criteria, '')) > 0
      then E'DEFINITION OF DONE\n' || p_success_criteria end,
    case when length(coalesce(p_output_format, '')) > 0
      then E'DESIRED OUTPUT FORMAT\n' || p_output_format end
  )
$$;

update public.job_payloads
set prompt = private.merge_legacy_prompt(success_criteria, output_format)
where prompt = ''
  and (length(success_criteria) > 0 or length(output_format) > 0);

update public.jobs j
set preferred_model_text = coalesce((
      select m.display_name
      from public.job_models jm
      join public.models m
        on m.organization_id = jm.organization_id and m.id = jm.model_id
      where jm.job_id = j.id and jm.preference = 'preferred'
      order by jm.sort_order, m.display_name
      limit 1
    ), preferred_model_text),
    acceptable_models_text = coalesce((
      select string_agg(m.display_name, ', ' order by jm.sort_order, m.display_name)
      from public.job_models jm
      join public.models m
        on m.organization_id = jm.organization_id and m.id = jm.model_id
      where jm.job_id = j.id and jm.preference = 'acceptable'
    ), acceptable_models_text);

-- The simplified product has one classification. Existing rows are migrated so
-- no old lab-visible branch can continue exposing protected content.
update public.jobs
set visibility = 'claimed_only',
    sensitivity = 'general',
    sensitivity_notes = null,
    effort = 'medium';

alter table public.jobs
  alter column visibility set default 'claimed_only',
  alter column sensitivity set default 'general',
  alter column effort set default 'medium',
  drop constraint if exists jobs_title_nonblank,
  add constraint jobs_title_complete check (
    length(title) <= 120
    and (status = 'draft' or length(btrim(title)) between 1 and 120)
  ) not valid,
  drop constraint if exists jobs_summary_nonblank,
  add constraint jobs_summary_complete check (
    length(listing_summary) <= 1000
    and (status = 'draft' or length(btrim(listing_summary)) between 1 and 1000)
  ) not valid,
  drop constraint if exists jobs_preferred_model_text_complete,
  add constraint jobs_preferred_model_text_complete check (
    length(preferred_model_text) <= 200
    and (status = 'draft' or length(btrim(preferred_model_text)) between 1 and 200)
  ) not valid,
  drop constraint if exists jobs_acceptable_models_text_limit,
  add constraint jobs_acceptable_models_text_limit
    check (length(acceptable_models_text) <= 1000) not valid,
  drop constraint if exists jobs_fixed_classification,
  add constraint jobs_fixed_classification check (
    visibility = 'claimed_only'
    and sensitivity = 'general'
    and sensitivity_notes is null
    and effort = 'medium'
  ) not valid;

alter table public.job_payloads
  drop constraint if exists payload_task_nonblank,
  add constraint payload_task_length check (length(current_task) <= 100000) not valid,
  drop constraint if exists payload_success_nonblank,
  add constraint payload_success_length check (length(success_criteria) <= 25000) not valid,
  drop constraint if exists payload_output_nonblank,
  add constraint payload_output_length check (length(output_format) <= 10000) not valid,
  drop constraint if exists payload_prompt_limit,
  add constraint payload_prompt_limit check (length(prompt) <= 100000) not valid;

-- Prompt is now the sole new instruction body. Preserve legacy current_task as
-- protected compatibility data for old jobs; success criteria and output
-- format have both been losslessly labeled and merged into prompt above.
update public.job_payloads
set success_criteria = '', output_format = '';

-- Earlier UI versions stored a shared-chat URL as the entire inline context.
-- Preserve that real data as the one supported shared_chat item. BrainSwap
-- never fetches the URL; it remains participant-only text/link metadata.
with url_candidates as (
  select c.id, c.job_id,
    row_number() over (
      partition by c.job_id order by c.sort_order, c.created_at, c.id
    ) as candidate_rank
  from public.job_context_items c
  where c.kind = 'inline_text'
    and private.valid_https_url(btrim(c.text_content))
), selected as (
  select candidate.id
  from url_candidates candidate
  where candidate.candidate_rank = 1
    and not exists (
      select 1 from public.job_context_items existing
      where existing.job_id = candidate.job_id and existing.kind = 'shared_chat'
    )
)
update public.job_context_items c
set kind = 'shared_chat',
    label = 'Link to chat',
    url = btrim(c.text_content),
    text_content = null,
    updated_at = now()
from selected
where c.id = selected.id;

alter table public.submissions
  drop constraint if exists submissions_reasoning_effort_valid,
  add constraint submissions_reasoning_effort_valid check (
    reasoning_effort is null
    or reasoning_effort in ('low', 'medium', 'high', 'extra_high', 'max', 'ultra', 'other')
  ) not valid,
  drop constraint if exists submissions_reasoning_other_valid,
  add constraint submissions_reasoning_other_valid check (
    (reasoning_effort = 'other'
      and reasoning_effort_other is not null
      and length(btrim(reasoning_effort_other)) between 1 and 200)
    or (reasoning_effort is distinct from 'other' and reasoning_effort_other is null)
  ) not valid;

alter table public.memberships validate constraint memberships_bio_limit;
alter table public.jobs validate constraint jobs_title_complete;
alter table public.jobs validate constraint jobs_summary_complete;
alter table public.jobs validate constraint jobs_preferred_model_text_complete;
alter table public.jobs validate constraint jobs_acceptable_models_text_limit;
alter table public.jobs validate constraint jobs_fixed_classification;
alter table public.job_payloads validate constraint payload_task_length;
alter table public.job_payloads validate constraint payload_success_length;
alter table public.job_payloads validate constraint payload_output_length;
alter table public.job_payloads validate constraint payload_prompt_limit;
alter table public.submissions validate constraint submissions_reasoning_effort_valid;
alter table public.submissions validate constraint submissions_reasoning_other_valid;

-- Profile photos have a separate private bucket and metadata table. The path is
-- always server-generated, exact-object authorized, and never browser authority.
create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  membership_id uuid not null,
  storage_path text not null unique,
  original_filename text not null,
  safe_filename text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 5242880),
  upload_status public.upload_status not null default 'pending',
  cleanup_started_at timestamptz,
  created_at timestamptz not null default now(),
  ready_at timestamptz,
  foreign key (organization_id, membership_id)
    references public.memberships(organization_id, id) on delete cascade,
  check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  check (length(original_filename) between 1 and 255),
  check (length(safe_filename) between 1 and 255)
);

create unique index if not exists one_profile_photo_reservation
  on public.profile_photos(membership_id);

alter table public.profile_photos enable row level security;
revoke all on public.profile_photos from anon, authenticated;
grant select(
  id, organization_id, membership_id, safe_filename, mime_type, size_bytes,
  upload_status, cleanup_started_at, created_at, ready_at
) on public.profile_photos to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos', 'profile-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.valid_reasoning_effort(
  p_effort text,
  p_other text
) returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select p_effort in ('low', 'medium', 'high', 'extra_high', 'max', 'ultra', 'other')
    and (
      (p_effort = 'other' and p_other is not null and length(btrim(p_other)) between 1 and 200)
      or (p_effort <> 'other' and p_other is null)
    )
$$;

create or replace function private.profile_photo_is_allowed(
  p_filename text,
  p_mime_type text
) returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_ext text;
begin
  if p_filename is null
    or length(p_filename) not between 1 and 255
    or p_filename <> btrim(p_filename)
    or position('/' in p_filename) > 0
    or position(chr(92) in p_filename) > 0
    or p_filename ~ '[[:cntrl:]]'
    or p_filename ~ '^\.'
    or p_filename !~ '\.[A-Za-z0-9]+$'
  then
    return false;
  end if;
  v_ext := lower(substring(p_filename from '\.([A-Za-z0-9]+)$'));
  return case v_ext
    when 'png' then p_mime_type = 'image/png'
    when 'jpg' then p_mime_type = 'image/jpeg'
    when 'jpeg' then p_mime_type = 'image/jpeg'
    when 'webp' then p_mime_type = 'image/webp'
    else false
  end;
end
$$;

create or replace function private.can_read_profile_photo(p_photo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos p
    where p.id = p_photo_id
      and (
        (p.upload_status = 'ready' and p.cleanup_started_at is null
          and (private.actor(p.organization_id)).id is not null)
        or (p.membership_id = (private.actor(p.organization_id)).id)
      )
  )
$$;

create or replace function private.can_profile_photo_storage_upload(
  p_storage_path text,
  p_metadata jsonb
) returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  p public.profile_photos;
  a public.memberships;
begin
  select * into p
  from public.profile_photos photo
  where photo.storage_path = p_storage_path
  for update;
  if p.id is null then return false; end if;
  a := private.locked_actor(p.organization_id);
  return a.id is not null
    and a.id = p.membership_id
    and p.upload_status = 'pending'
    and p.cleanup_started_at is null
    and coalesce(p_metadata ->> 'size', '') = p.size_bytes::text
    and coalesce(p_metadata ->> 'mimetype', '') = p.mime_type;
end
$$;

create or replace function private.can_profile_photo_storage_download(p_storage_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos p
    where p.storage_path = p_storage_path
      and p.upload_status = 'ready'
      and p.cleanup_started_at is null
      and (private.actor(p.organization_id)).id is not null
  )
$$;

create or replace function private.can_profile_photo_storage_delete(p_storage_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos p
    where p.storage_path = p_storage_path
      and p.cleanup_started_at is not null
      and p.membership_id = (private.actor(p.organization_id)).id
  )
$$;

drop policy if exists profile_photos_read on public.profile_photos;
create policy profile_photos_read on public.profile_photos
for select to authenticated
using (private.can_read_profile_photo(id));

drop policy if exists exact_profile_photo_upload on storage.objects;
create policy exact_profile_photo_upload on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-photos'
  and private.can_profile_photo_storage_upload(name, metadata)
);

drop policy if exists authorized_profile_photo_download on storage.objects;
create policy authorized_profile_photo_download on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-photos'
  and (
    (private.can_profile_photo_storage_download(name)
      and storage.allow_any_operation(array[
        'storage.object.get_authenticated',
        'object.get_authenticated_info',
        'object.head_authenticated_info'
      ]))
    or (private.can_profile_photo_storage_delete(name)
      and storage.allow_any_operation(array[
        'storage.object.delete', 'storage.object.delete_many'
      ]))
  )
);

drop policy if exists authorized_profile_photo_delete on storage.objects;
create policy authorized_profile_photo_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-photos'
  and private.can_profile_photo_storage_delete(name)
);

-- All protected job content is participant-only. A listing remains visible to
-- active organization members; its prompt, chat link, and files do not.
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
      and private.can_payload(j)
  )
$$;

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
        (f.upload_status = 'ready'
          and f.cleanup_started_at is null
          and not j.deletion_pending
          and private.can_payload_job(j.id))
        or (j.status = 'draft'
          and not j.deletion_pending
          and f.uploaded_by_membership_id = (private.actor(j.organization_id)).id
          and j.created_by_membership_id = (private.actor(j.organization_id)).id)
      )
  )
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
  v_chat_url text;
  v_preferred text;
  v_acceptable text;
  v_deadline_text text;
  v_deadline timestamptz;
  v_tools text[];
begin
  if jsonb_typeof(p_input) is distinct from 'object'
    or jsonb_typeof(p_input -> 'title') is distinct from 'string'
    or jsonb_typeof(p_input -> 'task_summary') is distinct from 'string'
    or jsonb_typeof(p_input -> 'prompt') is distinct from 'string'
    or jsonb_typeof(p_input -> 'chat_url') is distinct from 'string'
    or jsonb_typeof(p_input -> 'preferred_model_text') is distinct from 'string'
    or jsonb_typeof(p_input -> 'acceptable_models_text') is distinct from 'string'
    or coalesce(jsonb_typeof(p_input -> 'deadline'), 'null') not in ('null', 'string')
    or jsonb_typeof(p_input -> 'required_tools') is distinct from 'array'
  then
    raise exception 'invalid draft input';
  end if;

  v_title := btrim(coalesce(p_input ->> 'title', ''));
  v_summary := btrim(coalesce(p_input ->> 'task_summary', ''));
  v_prompt := coalesce(p_input ->> 'prompt', '');
  v_chat_url := btrim(coalesce(p_input ->> 'chat_url', ''));
  v_preferred := btrim(coalesce(p_input ->> 'preferred_model_text', ''));
  v_acceptable := btrim(coalesce(p_input ->> 'acceptable_models_text', ''));

  if length(v_title) > 120
    or length(v_summary) > 1000
    or length(v_prompt) > 100000
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

  begin
    v_tools := array(
      select btrim(t.value)
      from jsonb_array_elements_text(p_input -> 'required_tools')
        with ordinality as t(value, position)
      order by t.position
    );
  exception when others then
    raise exception 'invalid required tools';
  end;
  if not private.valid_job_tools(v_tools) then
    raise exception 'invalid required tools';
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
      required_tools = v_tools,
      deadline = v_deadline,
      data_handling_acknowledged_at = coalesce(data_handling_acknowledged_at, now()),
      acknowledgement_version = 'brainswap-default-public-sharing-v1',
      updated_at = now()
  where id = p_job_id and organization_id = p_organization_id;

  update public.job_payloads
  set prompt = v_prompt,
      -- Existing legacy current_task stays intact; new rows begin blank.
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

create or replace function public.create_draft_job(
  p_organization_id uuid,
  p_input jsonb
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  j uuid := gen_random_uuid();
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null then raise exception 'not authorized'; end if;

  insert into public.jobs(
    id, organization_id, created_by_membership_id, title, listing_summary,
    preferred_model_text, acceptable_models_text,
    visibility, sensitivity, effort, required_tools
  ) values (
    j, p_organization_id, a.id, '', '', '', '',
    'claimed_only', 'general', 'medium', '{}'::text[]
  );
  insert into public.job_payloads(
    job_id, current_task, success_criteria, output_format, prompt
  ) values (j, '', '', '', '');

  perform private.apply_draft_input(j, p_organization_id, p_input);
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type
  ) values (p_organization_id, j, a.id, 'job_draft_created');
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
  select * into j from public.jobs where public.jobs.id = p_job_id for update;
  if j.id is null then raise exception 'not authorized'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
  then
    raise exception 'not authorized';
  end if;
  perform private.apply_draft_input(j.id, j.organization_id, p_input);
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type
  ) values (j.organization_id, j.id, a.id, 'job_draft_updated');
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
    or length(btrim(j.preferred_model_text)) not between 1 and 200
    or (j.deadline is not null and j.deadline <= now())
    or exists (
      select 1 from public.job_context_items c
      where c.job_id = j.id
        and c.kind not in ('shared_chat', 'previous_job')
    )
    or (select count(*) from public.job_context_items c
        where c.job_id = j.id and c.kind = 'shared_chat') > 1
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
      sensitivity_notes = null, effort = 'medium',
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

create or replace function public.update_and_publish_job(p_job_id uuid, p_input jsonb)
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
  if j.id is null then raise exception 'not authorized'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.created_by_membership_id
    or j.status <> 'draft'
    or j.deletion_pending
  then
    raise exception 'not authorized';
  end if;

  -- The visible editor and publication transition commit together. If the
  -- publish-ready checks fail, PostgreSQL rolls the draft edits back too.
  perform private.apply_draft_input(j.id, j.organization_id, p_input);
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type
  ) values (j.organization_id, j.id, a.id, 'job_draft_updated');
  perform public.publish_job(j.id);
end
$$;

create or replace function public.admin_delete_unclaimed_invitation(
  p_organization_id uuid,
  p_membership_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  target public.memberships;
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null or a.role <> 'admin' then
    raise exception 'administrator access required';
  end if;
  select * into target
  from public.memberships m
  where m.organization_id = p_organization_id and m.id = p_membership_id
  for update;
  if target.id is null
    or target.user_id is not null
    or target.claimed_user_id is not null
    or target.claimed_at is not null
  then
    raise exception 'only an unclaimed invitation can be removed';
  end if;
  delete from public.memberships
  where organization_id = p_organization_id and id = p_membership_id;
  insert into public.audit_events(
    organization_id, actor_membership_id, event_type, metadata
  ) values (
    p_organization_id, a.id, 'membership_invitation_deleted',
    jsonb_build_object('membership_id', p_membership_id, 'role', target.role)
  );
end
$$;

-- The fixed profile catalog remains normalized and organization-scoped. It is
-- seeded for every organization, while legacy catalog rows are retained but no
-- longer offered as active choices.
update public.models
set active = false, updated_at = now()
where display_name not in (
  'GPT-6 Astra', 'GPT-5.6 Sol', 'GPT-5.6 Terra', 'GPT-5.6 Luna',
  'Claude Fable 5.1', 'Claude Opus 5', 'Gemini Pro', 'SuperGrok'
);

insert into public.models(organization_id, provider, display_name, active, sort_order)
select o.id, x.provider, x.display_name, true, x.sort_order
from public.organizations o
cross join (values
  ('OpenAI', 'GPT-6 Astra', 10),
  ('OpenAI', 'GPT-5.6 Sol', 20),
  ('OpenAI', 'GPT-5.6 Terra', 30),
  ('OpenAI', 'GPT-5.6 Luna', 40),
  ('Anthropic', 'Claude Fable 5.1', 50),
  ('Anthropic', 'Claude Opus 5', 60),
  ('Google', 'Gemini Pro', 70),
  ('xAI', 'SuperGrok', 80)
) as x(provider, display_name, sort_order)
on conflict (organization_id, (lower(btrim(display_name)))) do update
set provider = excluded.provider,
    active = true,
    sort_order = excluded.sort_order,
    updated_at = now();

drop function if exists public.my_active_memberships();
create function public.my_active_memberships()
returns table(
  organization_id uuid,
  membership_id uuid,
  organization_name text,
  display_name text,
  bio text,
  role public.member_role,
  capabilities text[],
  notification_preferences jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.organization_id, m.id, o.name, m.display_name, m.bio, m.role,
    m.capabilities, m.notification_preferences
  from public.memberships m
  join public.organizations o on o.id = m.organization_id
  where m.user_id = auth.uid()
    and m.claimed_user_id = auth.uid()
    and m.active
$$;

drop function if exists public.update_profile(uuid, text, text[], uuid[], jsonb);
create function public.update_profile(
  p_organization_id uuid,
  p_display_name text,
  p_bio text,
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
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
  v_model_count integer;
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null
    or length(v_name) not between 1 and 120
    or length(coalesce(v_bio, '')) > 2000
    or p_model_ids is null
    or cardinality(p_model_ids) > 8
    or cardinality(p_model_ids) <> (select count(distinct x) from unnest(p_model_ids) x)
    or jsonb_typeof(p_preferences) is distinct from 'object'
    or (p_preferences - 'new_matching_jobs') <> '{}'::jsonb
    or jsonb_typeof(p_preferences -> 'new_matching_jobs') is distinct from 'boolean'
  then
    raise exception 'invalid profile';
  end if;

  select count(*) into v_model_count
  from public.models m
  where m.organization_id = p_organization_id
    and m.active
    and m.display_name in (
      'GPT-6 Astra', 'GPT-5.6 Sol', 'GPT-5.6 Terra', 'GPT-5.6 Luna',
      'Claude Fable 5.1', 'Claude Opus 5', 'Gemini Pro', 'SuperGrok'
    )
    and m.id = any(p_model_ids);
  if v_model_count <> cardinality(p_model_ids) then
    raise exception 'invalid profile models';
  end if;

  update public.memberships
  set display_name = v_name,
      bio = v_bio,
      capabilities = '{}'::text[],
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

create or replace function public.reserve_profile_photo(
  p_organization_id uuid,
  p_filename text,
  p_mime_type text,
  p_size_bytes bigint
) returns table(id uuid, storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.memberships;
  v_id uuid := gen_random_uuid();
  v_safe text;
  v_path text;
begin
  a := private.locked_actor(p_organization_id);
  if a.id is null
    or not private.profile_photo_is_allowed(p_filename, p_mime_type)
    or p_size_bytes is null or p_size_bytes not between 1 and 5242880
    or exists (select 1 from public.profile_photos p where p.membership_id = a.id)
  then
    raise exception 'profile photo not allowed';
  end if;
  v_safe := private.safe_filename(p_filename);
  v_path := p_organization_id || '/member/' || a.id || '/' || gen_random_uuid();
  insert into public.profile_photos(
    id, organization_id, membership_id, storage_path, original_filename,
    safe_filename, mime_type, size_bytes
  ) values (
    v_id, p_organization_id, a.id, v_path, p_filename,
    v_safe, p_mime_type, p_size_bytes
  );
  return query select v_id, v_path;
end
$$;

create or replace function public.finalize_profile_photo(p_photo_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profile_photos;
  a public.memberships;
  o storage.objects;
begin
  select * into p from public.profile_photos where id = p_photo_id for update;
  if p.id is null then raise exception 'profile photo not found'; end if;
  a := private.locked_actor(p.organization_id);
  if a.id is null or a.id <> p.membership_id
    or p.upload_status <> 'pending' or p.cleanup_started_at is not null
  then
    raise exception 'profile photo not found';
  end if;
  select * into o from storage.objects
  where bucket_id = 'profile-photos' and name = p.storage_path;
  if o.id is null
    or coalesce(o.metadata ->> 'size', '') !~ '^[0-9]+$'
    or (o.metadata ->> 'size')::bigint <> p.size_bytes
    or coalesce(o.metadata ->> 'mimetype', '') <> p.mime_type
  then
    raise exception 'uploaded object does not match reservation';
  end if;
  update public.profile_photos
  set upload_status = 'ready', ready_at = now()
  where id = p.id;
end
$$;

create or replace function public.profile_photo_download_info(p_membership_id uuid)
returns table(
  storage_path text,
  original_filename text,
  mime_type text,
  size_bytes bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p public.profile_photos;
begin
  select * into p
  from public.profile_photos photo
  where photo.membership_id = p_membership_id
    and photo.upload_status = 'ready'
    and photo.cleanup_started_at is null;
  if p.id is null or (private.actor(p.organization_id)).id is null then
    raise exception 'profile photo not found';
  end if;
  return query select p.storage_path, p.safe_filename, p.mime_type, p.size_bytes;
end
$$;

create or replace function public.profile_photo_cleanup_info(p_photo_id uuid)
returns table(
  storage_path text,
  original_filename text,
  mime_type text,
  size_bytes bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profile_photos;
  a public.memberships;
begin
  select * into p from public.profile_photos where id = p_photo_id for update;
  if p.id is null then raise exception 'profile photo not found'; end if;
  a := private.locked_actor(p.organization_id);
  if a.id is null or a.id <> p.membership_id then
    raise exception 'profile photo not found';
  end if;
  update public.profile_photos
  set cleanup_started_at = coalesce(cleanup_started_at, now())
  where id = p.id;
  return query select p.storage_path, p.safe_filename, p.mime_type, p.size_bytes;
end
$$;

create or replace function public.delete_profile_photo_record(p_photo_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profile_photos;
  a public.memberships;
begin
  select * into p from public.profile_photos where id = p_photo_id for update;
  if p.id is null then return; end if;
  a := private.locked_actor(p.organization_id);
  if a.id is null or a.id <> p.membership_id then return; end if;
  if p.cleanup_started_at is null then raise exception 'profile photo not deletable'; end if;
  if exists (
    select 1 from storage.objects o
    where o.bucket_id = 'profile-photos' and o.name = p.storage_path
  ) then
    raise exception 'storage cleanup required';
  end if;
  delete from public.profile_photos where id = p.id;
end
$$;

create or replace function private.lock_result_edits(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_submission_id uuid;
begin
  update public.jobs
  set requester_action_at = coalesce(requester_action_at, now()),
      updated_at = now()
  where id = p_job_id;
  select s.id into v_submission_id
  from public.submissions s
  where s.job_id = p_job_id and s.status = 'submitted'
  order by s.revision_number desc, s.submitted_at desc
  limit 1;
  if v_submission_id is not null then
    update public.submissions
    set edit_locked_at = coalesce(edit_locked_at, now())
    where id = v_submission_id;
    -- An upload authorized before the requester took the job lock has finished.
    -- Unfinalized reservations are made explicit cleanup work rather than being
    -- left uploadable after the edit window closes.
    update public.submission_files
    set cleanup_started_at = coalesce(cleanup_started_at, now())
    where submission_id = v_submission_id and upload_status = 'pending';
  end if;
end
$$;

drop function if exists public.submit_result(uuid, text, text, text, text[]);
create function public.submit_result(
  p_job_id uuid,
  p_model_used_text text,
  p_response_text text,
  p_notes text,
  p_reasoning_effort text,
  p_reasoning_effort_other text
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
  v_effort text := btrim(coalesce(p_reasoning_effort, ''));
  v_other text := nullif(btrim(coalesce(p_reasoning_effort_other, '')), '');
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'claim expired'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null
    or a.id is distinct from j.assigned_to_membership_id
    or j.status not in ('claimed', 'revision_requested')
    or j.claim_expires_at is null or j.claim_expires_at <= now()
    or j.deletion_pending
    or length(v_model) not between 1 and 200
    or length(btrim(v_response)) = 0 or length(v_response) > 500000
    or length(coalesce(v_notes, '')) > 25000
    or not private.valid_reasoning_effort(v_effort, v_other)
  then
    raise exception 'result incomplete';
  end if;

  select * into s
  from public.submissions
  where job_id = j.id
    and submitted_by_membership_id = a.id
    and status = 'draft'
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
      tools_used = '{}'::text[],
      reasoning_effort = v_effort,
      reasoning_effort_other = v_other,
      revision_number = n,
      submitted_at = now(),
      edited_at = null,
      edit_locked_at = null
  where id = s.id and status = 'draft';

  update public.revision_requests
  set resolved_by_submission_id = s.id, resolved_at = now()
  where job_id = j.id and resolved_at is null;
  update public.jobs
  set status = 'submitted',
      assigned_to_membership_id = null,
      claimed_at = null,
      claim_expires_at = null,
      requester_action_at = null,
      updated_at = now()
  where id = j.id;

  insert into public.notifications(
    organization_id, recipient_membership_id, job_id, type, message
  )
  select j.organization_id, m.id, j.id, 'result_submitted',
    'A BrainSwap result was submitted.'
  from public.memberships m
  where m.id = j.created_by_membership_id
    and m.organization_id = j.organization_id
    and m.active and m.user_id is not null and m.claimed_user_id = m.user_id;
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type, metadata
  ) values (
    j.organization_id, j.id, a.id, 'result_submitted',
    jsonb_build_object('revision_number', n, 'reasoning_effort', v_effort)
  );
end
$$;

create or replace function public.edit_submitted_result(
  p_job_id uuid,
  p_model_used_text text,
  p_response_text text,
  p_notes text,
  p_reasoning_effort text,
  p_reasoning_effort_other text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  j public.jobs;
  a public.memberships;
  s public.submissions;
  v_model text := btrim(coalesce(p_model_used_text, ''));
  v_response text := coalesce(p_response_text, '');
  v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
  v_effort text := btrim(coalesce(p_reasoning_effort, ''));
  v_other text := nullif(btrim(coalesce(p_reasoning_effort_other, '')), '');
begin
  select * into j from public.jobs where id = p_job_id for update;
  if j.id is null then raise exception 'result is not editable'; end if;
  a := private.locked_actor(j.organization_id);
  select * into s
  from public.submissions submitted
  where submitted.job_id = j.id and submitted.status = 'submitted'
  order by submitted.revision_number desc, submitted.submitted_at desc
  limit 1
  for update;
  if a.id is null
    or s.id is null
    or a.id is distinct from s.submitted_by_membership_id
    or j.status <> 'submitted'
    or j.requester_action_at is not null
    or s.edit_locked_at is not null
    or j.deletion_pending
    or length(v_model) not between 1 and 200
    or length(btrim(v_response)) = 0 or length(v_response) > 500000
    or length(coalesce(v_notes, '')) > 25000
    or not private.valid_reasoning_effort(v_effort, v_other)
    or exists (
      select 1 from public.submission_files f
      where f.submission_id = s.id
        and (f.upload_status <> 'ready' or f.cleanup_started_at is not null)
    )
  then
    raise exception 'result is not editable';
  end if;

  update public.submissions
  set model_used_text = v_model,
      response_text = v_response,
      notes = v_notes,
      tools_used = '{}'::text[],
      reasoning_effort = v_effort,
      reasoning_effort_other = v_other,
      edited_at = now()
  where id = s.id;
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type, metadata
  ) values (
    j.organization_id, j.id, a.id, 'result_edited',
    jsonb_build_object('revision_number', s.revision_number, 'reasoning_effort', v_effort)
  );
end
$$;

create or replace function private.lock_result_edits_on_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_submission_id uuid;
begin
  if old.status = 'submitted' and new.status is distinct from old.status then
    new.requester_action_at := coalesce(old.requester_action_at, now());
    select s.id into v_submission_id
    from public.submissions s
    where s.job_id = old.id and s.status = 'submitted'
    order by s.revision_number desc, s.submitted_at desc
    limit 1;
    if v_submission_id is not null then
      update public.submissions
      set edit_locked_at = coalesce(edit_locked_at, now())
      where id = v_submission_id;
      update public.submission_files
      set cleanup_started_at = coalesce(cleanup_started_at, now())
      where submission_id = v_submission_id and upload_status = 'pending';
    end if;
  end if;
  return new;
end
$$;

drop trigger if exists lock_result_edits_on_status_change on public.jobs;
create trigger lock_result_edits_on_status_change
before update of status on public.jobs
for each row execute function private.lock_result_edits_on_status_change();

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

  perform private.lock_result_edits(j.id);
  insert into public.jobs(
    id, organization_id, created_by_membership_id, parent_job_id, title,
    listing_summary, preferred_model_text, acceptable_models_text,
    visibility, sensitivity, effort, required_tools
  ) values (
    n, j.organization_id, a.id, j.id, '', '', '', '',
    'claimed_only', 'general', 'medium', '{}'::text[]
  );
  insert into public.job_payloads(
    job_id, current_task, success_criteria, output_format, prompt
  ) values (n, '', '', '', '');
  insert into public.job_context_items(
    organization_id, job_id, kind, label, text_content, source_job_id
  ) values (
    j.organization_id, n, 'previous_job', 'Snapshot of prior finalized result',
    s.response_text, j.id
  );
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type, metadata
  ) values (
    j.organization_id, n, a.id, 'follow_up_draft_created',
    jsonb_build_object('parent_job_id', j.id, 'source_submission_id', s.id)
  );
  return n;
end
$$;

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
      and coalesce(p_metadata ->> 'size', '') = jf.size_bytes::text
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
    and coalesce(p_metadata ->> 'size', '') = sf.size_bytes::text
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
    and f.upload_status = 'ready' and f.cleanup_started_at is null;
  if j.id is not null then
    return not j.deletion_pending and private.can_payload(j);
  end if;
  select f.job_id, f.submission_id, f.uploaded_by_membership_id
  into v_job_id, v_submission_id, v_uploader
  from public.submission_files f
  where f.storage_path = p_storage_path
    and f.upload_status = 'ready' and f.cleanup_started_at is null;
  if v_job_id is null then return false; end if;
  select * into j from public.jobs where id = v_job_id;
  select * into s from public.submissions where id = v_submission_id and job_id = j.id;
  if j.id is null or s.id is null or j.deletion_pending then return false; end if;
  if s.status = 'submitted' then return private.can_payload(j); end if;
  if s.status <> 'draft' then return false; end if;
  a := private.actor(j.organization_id);
  return a.id is not null
    and a.id = v_uploader and a.id = s.submitted_by_membership_id
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
  v_latest_id uuid;
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
      or (not j.deletion_pending and j.status = 'draft'
        and a.id = j.created_by_membership_id and a.id = v_uploader);
  end if;

  select f.job_id, f.uploaded_by_membership_id, f.submission_id
  into v_job_id, v_uploader, v_submission_id
  from public.submission_files f
  where f.storage_path = p_storage_path and f.cleanup_started_at is not null;
  if v_job_id is null then
    select job.* into j from public.jobs job
    where job.deletion_pending
      and p_storage_path like (job.organization_id::text || '/' || job.id::text || '/%')
    limit 1;
    if j.id is null then return false; end if;
    a := private.actor(j.organization_id);
    return a.id is not null and (a.id = j.created_by_membership_id or a.role = 'admin');
  end if;
  select * into j from public.jobs where id = v_job_id;
  a := private.actor(j.organization_id);
  if a.id is null then return false; end if;
  if j.deletion_pending then
    return a.id = j.created_by_membership_id or a.role = 'admin';
  end if;
  select * into s from public.submissions where id = v_submission_id and job_id = j.id;
  if s.id is null then return false; end if;
  if s.status = 'submitted' then
    select submitted.id into v_latest_id
    from public.submissions submitted
    where submitted.job_id = j.id and submitted.status = 'submitted'
    order by submitted.revision_number desc, submitted.submitted_at desc limit 1;
    return (
      s.id = v_latest_id
      and j.status = 'submitted' and j.requester_action_at is null
      and s.edit_locked_at is null
      and a.id = s.submitted_by_membership_id and a.id = v_uploader
    ) or (
      s.edit_locked_at is not null
      and (a.id = j.created_by_membership_id or a.role = 'admin')
    );
  end if;
  if s.status <> 'draft' then return false; end if;
  v_current_owner := coalesce(j.assigned_to_membership_id = s.submitted_by_membership_id
    and j.status in ('claimed', 'revision_requested') and j.claim_expires_at > now(), false);
  return (a.id = v_uploader and a.id = s.submitted_by_membership_id and v_current_owner)
    or (not v_current_owner and (a.id = j.created_by_membership_id or a.role = 'admin'));
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
  s public.submissions;
  fid uuid := gen_random_uuid();
  v_safe text;
  v_path text;
  v_total bigint;
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  select * into j from public.jobs where public.jobs.id = p_job_id for update;
  if j.id is null then raise exception 'file not allowed'; end if;
  a := private.locked_actor(j.organization_id);
  if a.id is null or j.deletion_pending
    or not private.file_is_allowed(p_filename, p_mime_type)
    or p_size_bytes is null or p_size_bytes not between 1 and 26214400
    or length(coalesce(v_description, '')) > 1000
  then raise exception 'file not allowed'; end if;

  if a.id = j.assigned_to_membership_id
    and j.status in ('claimed', 'revision_requested')
    and j.claim_expires_at > now()
  then
    select * into s from public.submissions submitted
    where submitted.job_id = j.id
      and submitted.submitted_by_membership_id = a.id
      and submitted.status = 'draft'
    for update;
    if s.id is null then
      insert into public.submissions(job_id, organization_id, submitted_by_membership_id)
      values (j.id, j.organization_id, a.id) returning * into s;
    end if;
  elsif j.status = 'submitted' and j.requester_action_at is null then
    select * into s from public.submissions submitted
    where submitted.job_id = j.id and submitted.status = 'submitted'
    order by submitted.revision_number desc, submitted.submitted_at desc
    limit 1 for update;
    if s.id is null or s.submitted_by_membership_id <> a.id or s.edit_locked_at is not null
    then raise exception 'file not allowed'; end if;
  else
    raise exception 'file not allowed';
  end if;

  select coalesce((select sum(f.size_bytes) from public.job_files f where f.job_id = j.id), 0)
       + coalesce((select sum(f.size_bytes) from public.submission_files f where f.job_id = j.id), 0)
  into v_total;
  if v_total + p_size_bytes > 104857600 then raise exception 'job file limit exceeded'; end if;
  v_safe := private.safe_filename(p_filename);
  v_path := j.organization_id || '/' || j.id || '/submission/' || s.id || '/' || gen_random_uuid();
  insert into public.submission_files(
    id, submission_id, job_id, organization_id, uploaded_by_membership_id,
    storage_path, original_filename, safe_filename, description, mime_type, size_bytes
  ) values (
    fid, s.id, j.id, j.organization_id, a.id,
    v_path, p_filename, v_safe, v_description, p_mime_type, p_size_bytes
  );
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type, metadata
  ) values (
    j.organization_id, j.id, a.id, 'submission_file_reserved',
    jsonb_build_object('file_id', fid, 'submission_revision', s.revision_number)
  );
  return query select fid, v_path, s.id;
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
  v_latest_id uuid;
  v_allowed boolean;
begin
  select sf.job_id into v_job_id from public.submission_files sf where sf.id = p_file_id;
  if v_job_id is null then raise exception 'file not found'; end if;
  select * into j from public.jobs where id = v_job_id for update;
  select * into f from public.submission_files where id = p_file_id for update;
  select * into s from public.submissions where id = f.submission_id and job_id = j.id;
  a := private.locked_actor(j.organization_id);
  select submitted.id into v_latest_id
  from public.submissions submitted
  where submitted.job_id = j.id and submitted.status = 'submitted'
  order by submitted.revision_number desc, submitted.submitted_at desc limit 1;
  v_allowed := coalesce(
    (s.status = 'draft'
      and a.id = j.assigned_to_membership_id
      and j.status in ('claimed', 'revision_requested')
      and j.claim_expires_at > now())
    or (s.status = 'submitted' and s.id = v_latest_id
      and j.status = 'submitted' and j.requester_action_at is null
      and s.edit_locked_at is null), false);
  if a.id is null or a.id <> f.uploaded_by_membership_id
    or a.id <> s.submitted_by_membership_id or not v_allowed
    or j.deletion_pending or f.upload_status <> 'pending'
    or f.cleanup_started_at is not null
  then raise exception 'file not found'; end if;
  select * into o from storage.objects
  where bucket_id = 'job-files' and name = f.storage_path;
  if o.id is null
    or coalesce(o.metadata ->> 'size', '') !~ '^[0-9]+$'
    or (o.metadata ->> 'size')::bigint <> f.size_bytes
    or coalesce(o.metadata ->> 'mimetype', '') <> f.mime_type
  then raise exception 'uploaded object does not match reservation'; end if;
  update public.submission_files set upload_status = 'ready', ready_at = now() where id = f.id;
  insert into public.audit_events(
    organization_id, job_id, actor_membership_id, event_type, metadata
  ) values (j.organization_id, j.id, a.id, 'submission_file_finalized', jsonb_build_object('file_id', f.id));
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
  v_latest_id uuid;
  v_allowed boolean;
begin
  if p_kind = 'job' then
    select f.job_id into v_job_id from public.job_files f where f.id = p_file_id;
    if v_job_id is null then raise exception 'file not found'; end if;
    select * into j from public.jobs where id = v_job_id for update;
    select * into jf from public.job_files where id = p_file_id for update;
    a := private.locked_actor(j.organization_id);
    if a.id is null or a.id <> j.created_by_membership_id
      or a.id <> jf.uploaded_by_membership_id or j.status <> 'draft' or j.deletion_pending
    then raise exception 'file not found'; end if;
    update public.job_files set cleanup_started_at = coalesce(cleanup_started_at, now()) where id = jf.id;
    return query select jf.storage_path, jf.original_filename, jf.mime_type, jf.size_bytes;
    return;
  end if;
  if p_kind <> 'submission' then raise exception 'invalid file kind'; end if;
  select f.job_id into v_job_id from public.submission_files f where f.id = p_file_id;
  if v_job_id is null then raise exception 'file not found'; end if;
  select * into j from public.jobs where id = v_job_id for update;
  select * into sf from public.submission_files where id = p_file_id for update;
  select * into s from public.submissions where id = sf.submission_id and job_id = j.id;
  a := private.locked_actor(j.organization_id);
  select submitted.id into v_latest_id from public.submissions submitted
  where submitted.job_id = j.id and submitted.status = 'submitted'
  order by submitted.revision_number desc, submitted.submitted_at desc limit 1;
  v_allowed := coalesce(
    (s.status = 'draft' and a.id = s.submitted_by_membership_id
      and a.id = sf.uploaded_by_membership_id
      and a.id = j.assigned_to_membership_id
      and j.status in ('claimed', 'revision_requested') and j.claim_expires_at > now())
    or (s.status = 'draft'
      and not (j.assigned_to_membership_id = s.submitted_by_membership_id
        and j.status in ('claimed', 'revision_requested')
        and j.claim_expires_at > now())
      and (a.id = j.created_by_membership_id or a.role = 'admin'))
    or (s.status = 'submitted' and s.id = v_latest_id
      and a.id = s.submitted_by_membership_id and a.id = sf.uploaded_by_membership_id
      and j.status = 'submitted' and j.requester_action_at is null and s.edit_locked_at is null)
    or (s.status = 'submitted' and s.edit_locked_at is not null
      and (sf.upload_status = 'pending' or sf.cleanup_started_at is not null)
      and (a.id = j.created_by_membership_id or a.role = 'admin')),
    false);
  if a.id is null or s.id is null or j.deletion_pending or not v_allowed
  then raise exception 'file not found'; end if;
  update public.submission_files set cleanup_started_at = coalesce(cleanup_started_at, now()) where id = sf.id;
  return query select sf.storage_path, sf.original_filename, sf.mime_type, sf.size_bytes;
end
$$;

create or replace function public.delete_file_record(p_file_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info record;
  v_path text;
begin
  -- Re-run the same authorization and ensure cleanup is marked. The function is
  -- idempotent for rows that a retry already removed.
  if p_kind = 'job' and not exists (select 1 from public.job_files where id = p_file_id) then return; end if;
  if p_kind = 'submission' and not exists (select 1 from public.submission_files where id = p_file_id) then return; end if;
  select * into v_info from public.file_cleanup_info(p_file_id, p_kind);
  v_path := v_info.storage_path;
  if exists (
    select 1 from storage.objects o
    where o.bucket_id = 'job-files' and o.name = v_path
  ) then raise exception 'storage cleanup required'; end if;
  if p_kind = 'job' then
    delete from public.job_files where id = p_file_id and cleanup_started_at is not null;
  elsif p_kind = 'submission' then
    delete from public.submission_files where id = p_file_id and cleanup_started_at is not null;
  else
    raise exception 'invalid file kind';
  end if;
end
$$;

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
      when 'requests' then j.created_by_membership_id = a.id
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
  v_latest public.submissions;
  v_editable boolean := false;
  v_current_claimant boolean := false;
  result jsonb;
begin
  select * into j from public.jobs where id = p_job_id;
  if j.id is null then return null; end if;
  a := private.actor(j.organization_id);
  if a.id is null
    or (j.status = 'draft' and a.id <> j.created_by_membership_id and a.role <> 'admin')
    or (j.deletion_pending and a.id <> j.created_by_membership_id and a.role <> 'admin')
  then return null; end if;
  v_participant := private.can_payload(j);
  v_current_claimant := coalesce(
    a.id = j.assigned_to_membership_id
    and j.status in ('claimed', 'revision_requested')
    and j.claim_expires_at > now(), false);
  select * into v_latest from public.submissions s
  where s.job_id = j.id and s.status = 'submitted'
  order by s.revision_number desc, s.submitted_at desc limit 1;
  v_editable := coalesce(
    v_latest.id is not null
    and v_latest.submitted_by_membership_id = a.id
    and j.status = 'submitted'
    and j.requester_action_at is null
    and v_latest.edit_locked_at is null
    and not j.deletion_pending, false);

  select jsonb_build_object(
    'job', jsonb_build_object(
      'id', j.id, 'title', j.title, 'listing_summary', j.listing_summary,
      'status', j.status, 'visibility', j.visibility, 'sensitivity', j.sensitivity,
      'effort', j.effort, 'required_tools', j.required_tools,
      'preferred_model_text', j.preferred_model_text,
      'acceptable_models_text', j.acceptable_models_text,
      'deadline', j.deadline, 'deletion_pending', j.deletion_pending,
      'published_at', j.published_at, 'created_at', j.created_at
    ),
    'protected', case when v_participant then jsonb_build_object(
      'claim_expires_at', case when a.id = j.assigned_to_membership_id then j.claim_expires_at end
    ) end,
    'payload', case when v_participant then (
      select jsonb_build_object(
        'prompt', p.prompt,
        'task_summary', j.listing_summary,
        'legacy_current_task', nullif(p.current_task, '')
      )
      from public.job_payloads p where p.job_id = j.id
    ) end,
    'models', '[]'::jsonb,
    'contexts', case when v_participant then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'kind', c.kind, 'label', c.label,
        'text_content', c.text_content, 'url', c.url, 'sort_order', c.sort_order
      ) order by c.sort_order, c.created_at)
      from public.job_context_items c
      where c.job_id = j.id and c.kind in ('shared_chat', 'previous_job')
    ), '[]'::jsonb) else '[]'::jsonb end,
    'files', case when v_participant then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', f.id, 'original_filename', f.original_filename,
        'safe_filename', f.safe_filename, 'description', f.description,
        'mime_type', f.mime_type, 'size_bytes', f.size_bytes
      ) order by f.created_at)
      from public.job_files f
      where f.job_id = j.id and f.upload_status = 'ready'
        and f.cleanup_started_at is null
    ), '[]'::jsonb) else '[]'::jsonb end,
    'submissions', case when v_participant then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'model_used_text', s.model_used_text,
        'reasoning_effort', s.reasoning_effort,
        'reasoning_effort_other', s.reasoning_effort_other,
        'response_text', s.response_text, 'notes', s.notes,
        'revision_number', s.revision_number, 'submitted_at', s.submitted_at,
        'edited_at', s.edited_at,
        'files', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', sf.id, 'original_filename', sf.original_filename,
            'safe_filename', sf.safe_filename, 'description', sf.description,
            'mime_type', sf.mime_type, 'size_bytes', sf.size_bytes
          ) order by sf.created_at)
          from public.submission_files sf
          where sf.submission_id = s.id and sf.upload_status = 'ready'
            and sf.cleanup_started_at is null
        ), '[]'::jsonb)
      ) order by s.revision_number)
      from public.submissions s where s.job_id = j.id and s.status = 'submitted'
    ), '[]'::jsonb) else '[]'::jsonb end,
    'editable_submission', case when v_editable then jsonb_build_object(
      'id', v_latest.id, 'model_used_text', v_latest.model_used_text,
      'response_text', v_latest.response_text, 'notes', v_latest.notes,
      'reasoning_effort', v_latest.reasoning_effort,
      'reasoning_effort_other', v_latest.reasoning_effort_other,
      'revision_number', v_latest.revision_number,
      'files', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', sf.id, 'original_filename', sf.original_filename,
          'safe_filename', sf.safe_filename, 'description', sf.description,
          'mime_type', sf.mime_type, 'size_bytes', sf.size_bytes,
          'upload_status', sf.upload_status
        ) order by sf.created_at)
        from public.submission_files sf
        where sf.submission_id = v_latest.id
          and sf.upload_status = 'ready'
          and sf.cleanup_started_at is null
      ), '[]'::jsonb)
    ) end,
    'revision_requests', case when v_participant then coalesce((
      select jsonb_agg(jsonb_build_object(
        'instructions', r.instructions, 'created_at', r.created_at,
        'resolved_at', r.resolved_at
      ) order by r.created_at)
      from public.revision_requests r where r.job_id = j.id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'pending_files', coalesce((
      select jsonb_agg(x.item order by x.created_at)
      from (
        select jsonb_build_object(
          'kind', 'job', 'id', f.id, 'original_filename', f.original_filename,
          'description', f.description,
          'mime_type', f.mime_type, 'size_bytes', f.size_bytes,
          'upload_status', f.upload_status, 'cleanup_started_at', f.cleanup_started_at,
          'stale', false
        ) item, f.created_at
        from public.job_files f
        where f.job_id = j.id and a.id = j.created_by_membership_id
          and j.status = 'draft'
          and (f.upload_status = 'pending' or f.cleanup_started_at is not null)
        union all
        select jsonb_build_object(
          'kind', 'submission', 'id', sf.id, 'original_filename', sf.original_filename,
          'description', sf.description,
          'mime_type', sf.mime_type, 'size_bytes', sf.size_bytes,
          'upload_status', sf.upload_status, 'cleanup_started_at', sf.cleanup_started_at,
          'stale', not v_editable,
          'can_cleanup', coalesce(not j.deletion_pending and (
            (s.status = 'draft'
              and a.id = s.submitted_by_membership_id
              and a.id = sf.uploaded_by_membership_id
              and a.id = j.assigned_to_membership_id
              and j.status in ('claimed', 'revision_requested')
              and j.claim_expires_at > now())
            or (s.status = 'draft'
              and not (j.assigned_to_membership_id = s.submitted_by_membership_id
                and j.status in ('claimed', 'revision_requested')
                and j.claim_expires_at > now())
              and (a.id = j.created_by_membership_id or a.role = 'admin'))
            or (s.status = 'submitted'
              and s.id = v_latest.id
              and a.id = s.submitted_by_membership_id
              and a.id = sf.uploaded_by_membership_id
              and j.status = 'submitted'
              and j.requester_action_at is null
              and s.edit_locked_at is null)
            or (s.status = 'submitted'
              and s.edit_locked_at is not null
              and (sf.upload_status = 'pending' or sf.cleanup_started_at is not null)
              and (a.id = j.created_by_membership_id or a.role = 'admin'))
          ), false)
        ) item, sf.created_at
        from public.submission_files sf
        join public.submissions s on s.id = sf.submission_id
        where sf.job_id = j.id
          and (
            sf.upload_status = 'pending'
            or sf.cleanup_started_at is not null
            or (s.status = 'draft'
              and s.submitted_by_membership_id = a.id
              and j.assigned_to_membership_id = a.id
              and j.status in ('claimed', 'revision_requested')
              and j.claim_expires_at > now())
            or (s.status = 'draft'
              and (a.id = j.created_by_membership_id or a.role = 'admin')
              and not (j.assigned_to_membership_id = s.submitted_by_membership_id
                and j.status in ('claimed', 'revision_requested')
                and j.claim_expires_at > now()))
          )
          and (s.submitted_by_membership_id = a.id
            or a.id = j.created_by_membership_id or a.role = 'admin')
      ) x
    ), '[]'::jsonb),
    'permissions', jsonb_build_object(
      'update', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'draft',
      'publish', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'draft',
      'claim', not j.deletion_pending and a.id <> j.created_by_membership_id
        and j.status in ('open', 'claimed', 'revision_requested')
        and (j.assigned_to_membership_id is null or j.claim_expires_at <= now()),
      'extend', v_current_claimant, 'release', v_current_claimant,
      'submit', v_current_claimant,
      'copy_prompt', v_current_claimant or v_editable,
      'edit_submission', v_editable,
      'accept', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'submitted',
      'revise', not j.deletion_pending and a.id = j.created_by_membership_id and j.status = 'submitted',
      'cancel', not j.deletion_pending and (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status not in ('draft', 'accepted'),
      'reopen', not j.deletion_pending and (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status in ('submitted', 'revision_requested', 'cancelled')
        and (j.status <> 'cancelled' or j.published_at is not null),
      'follow_up', not j.deletion_pending and a.id = j.created_by_membership_id
        and j.status in ('submitted', 'revision_requested', 'accepted', 'cancelled')
        and v_latest.id is not null,
      'delete', (a.id = j.created_by_membership_id or a.role = 'admin')
        and j.status in ('draft', 'cancelled', 'accepted')
    )
  ) into result;
  return result;
end
$$;

-- Reapply narrow column grants after adding profile and listing fields.
revoke select on public.memberships from authenticated;
grant select(
  id, organization_id, display_name, bio, role, active, capabilities,
  notification_preferences, created_at, updated_at
) on public.memberships to authenticated;

revoke select on public.jobs from authenticated;
grant select(
  id, organization_id, title, listing_summary, status, visibility, sensitivity,
  effort, required_tools, preferred_model_text, acceptable_models_text,
  deadline, published_at, created_at, updated_at, deletion_pending
) on public.jobs to authenticated;

-- No new-job email RPC is exposed. Publish continues to create only the
-- metadata-minimal in-app notification rows established by the prior migration.
revoke all on function private.valid_reasoning_effort(text, text)
  from public, anon, authenticated;
revoke all on function private.merge_legacy_prompt(text, text)
  from public, anon, authenticated;
revoke all on function private.profile_photo_is_allowed(text, text)
  from public, anon, authenticated;
revoke all on function private.lock_result_edits(uuid)
  from public, anon, authenticated;
revoke all on function private.lock_result_edits_on_status_change()
  from public, anon, authenticated;
revoke all on function private.apply_draft_input(uuid, uuid, jsonb)
  from public, anon, authenticated;

revoke all on function private.can_read_profile_photo(uuid),
  private.can_profile_photo_storage_upload(text, jsonb),
  private.can_profile_photo_storage_download(text),
  private.can_profile_photo_storage_delete(text)
from public, anon, authenticated;
grant execute on function
  private.can_read_profile_photo(uuid),
  private.can_profile_photo_storage_upload(text, jsonb),
  private.can_profile_photo_storage_download(text),
  private.can_profile_photo_storage_delete(text)
to authenticated;

revoke all on function public.admin_delete_unclaimed_invitation(uuid, uuid),
  public.my_active_memberships(),
  public.update_profile(uuid, text, text, uuid[], jsonb),
  public.update_and_publish_job(uuid, jsonb),
  public.submit_result(uuid, text, text, text, text, text),
  public.edit_submitted_result(uuid, text, text, text, text, text),
  public.reserve_profile_photo(uuid, text, text, bigint),
  public.finalize_profile_photo(uuid),
  public.profile_photo_download_info(uuid),
  public.profile_photo_cleanup_info(uuid),
  public.delete_profile_photo_record(uuid)
from public, anon, authenticated;

grant execute on function
  public.admin_delete_unclaimed_invitation(uuid, uuid),
  public.my_active_memberships(),
  public.update_profile(uuid, text, text, uuid[], jsonb),
  public.update_and_publish_job(uuid, jsonb),
  public.submit_result(uuid, text, text, text, text, text),
  public.edit_submitted_result(uuid, text, text, text, text, text),
  public.reserve_profile_photo(uuid, text, text, bigint),
  public.finalize_profile_photo(uuid),
  public.profile_photo_download_info(uuid),
  public.profile_photo_cleanup_info(uuid),
  public.delete_profile_photo_record(uuid)
to authenticated;

-- Revoke stale overloads explicitly in case an interrupted deployment retained
-- them before the DROP above committed.
do $$
begin
  if to_regprocedure('public.update_profile(uuid,text,text[],uuid[],jsonb)') is not null then
    execute 'revoke all on function public.update_profile(uuid,text,text[],uuid[],jsonb) from public, anon, authenticated';
  end if;
  if to_regprocedure('public.submit_result(uuid,text,text,text,text[])') is not null then
    execute 'revoke all on function public.submit_result(uuid,text,text,text,text[]) from public, anon, authenticated';
  end if;
end
$$;

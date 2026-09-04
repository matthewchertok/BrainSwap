begin;

-- Updated after all assertions are written. Keeping an explicit plan makes CI
-- fail if a future edit silently drops an adversarial case.
select plan(266);

-- Fixed identities make failures reproducible. Everything is rolled back.
insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000001','authenticated','authenticated','admin-a@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000002','authenticated','authenticated','requester@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000003','authenticated','authenticated','helper@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000004','authenticated','authenticated','competitor@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000005','authenticated','authenticated','historical@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000006','authenticated','authenticated','inactive@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000007','authenticated','authenticated','outsider@princeton.edu','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000008','authenticated','authenticated','admin-b@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000009','authenticated','authenticated','exact@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000011','authenticated','authenticated','deactivate@example.test','',now(),'{}','{}',now(),now(),'','','','');

insert into public.organizations(id, name, slug) values
  ('aaaaaaaa-0000-0000-0000-000000000001','Organization A','organization-a'),
  ('bbbbbbbb-0000-0000-0000-000000000001','Organization B','organization-b');

insert into public.memberships(
  id, organization_id, invited_email, user_id, claimed_user_id, display_name,
  role, active, capabilities, notification_preferences, claimed_at
) values
  ('a0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','admin-a@example.test','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Admin A','admin',true,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','requester@example.test','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Requester','member',true,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','helper@example.test','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Helper','member',true,'{"Code execution"}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','competitor@example.test','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Competitor','member',true,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001','historical@example.test','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000005','Historical submitter','member',true,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000001','inactive@example.test','10000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000006','Inactive','member',false,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','deactivate@example.test','10000000-0000-0000-0000-000000000011','10000000-0000-0000-0000-000000000011','To deactivate','member',true,'{}','{"new_matching_jobs":true}',now()),
  ('a0000000-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000001','exact@example.test',null,null,null,'member',true,'{}','{"new_matching_jobs":true}',null),
  ('a0000000-0000-0000-0000-000000000010','aaaaaaaa-0000-0000-0000-000000000001','remove@example.test',null,null,null,'member',true,'{}','{"new_matching_jobs":true}',null),
  ('b0000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','admin-b@example.test','10000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000008','Admin B','admin',true,'{}','{"new_matching_jobs":true}',now());

insert into public.models(id, organization_id, provider, display_name, active, sort_order) values
  ('d0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','OpenAI','GPT-6 Astra',true,1),
  ('d0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','OpenAI','GPT-5.6 Sol',true,2),
  ('d0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','Test','A inactive',false,3),
  ('d0000000-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001','OpenAI','GPT-6 Astra',true,1);

insert into public.jobs(
  id, organization_id, created_by_membership_id, parent_job_id, status, title,
  listing_summary, visibility, sensitivity, sensitivity_notes, effort,
  required_tools, assigned_to_membership_id, claimed_at, claim_expires_at,
  data_handling_acknowledged_at, acknowledgement_version, published_at,
  preferred_model_text, acceptable_models_text
) values
  ('c0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Complete draft','Draft summary','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',null,'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'open','Published job','Safe listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'open','Sealed open job','Safe sealed listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Current sealed claim','Safe current listing','claimed_only','general',null,'medium','{}','a0000000-0000-0000-0000-000000000003',now(),now()+interval '4 hours',now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Expired sealed claim','Safe expired listing','claimed_only','general',null,'medium','{}','a0000000-0000-0000-0000-000000000003',now()-interval '8 hours',now()-interval '4 hours',now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'submitted','Historical job','Safe historical listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Deactivate claimant','Safe deactivate listing','claimed_only','general',null,'medium','{}','a0000000-0000-0000-0000-000000000007',now(),now()+interval '4 hours',now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000008','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'cancelled','Delete this job','Safe deletion listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'cancelled','Parent with child','Cannot delete first','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000010','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000009','draft','Child draft','Child listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',null,'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Upload draft','Upload listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',null,'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Pending upload draft','Pending listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',null,'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000013','bbbbbbbb-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001',null,'open','Organization B job','B safe listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Limit draft','Limit listing','claimed_only','general',null,'medium','{}',null,null,null,now(),'brainswap-default-public-sharing-v1',null,'Test model','Any frontier model'),
  ('c0000000-0000-0000-0000-000000000015','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'revision_requested','Expired revision claim','Safe revision listing','claimed_only','general',null,'medium','{}','a0000000-0000-0000-0000-000000000003',now()-interval '8 hours',now()-interval '4 hours',now(),'brainswap-default-public-sharing-v1',now(),'Test model','Any frontier model');

insert into public.job_payloads(job_id, current_task, success_criteria, output_format, prompt)
select j.id,
  case when j.id = 'c0000000-0000-0000-0000-000000000001'::uuid
    then repeat('Legacy task detail. ', 80)
    else 'protected task for ' || j.id::text
  end,
  'done when verified', 'plain text',
  'protected prompt for ' || j.id::text
from public.jobs j;

insert into public.job_models(organization_id, job_id, model_id, preference, sort_order)
select j.organization_id, j.id,
  case when j.organization_id = 'aaaaaaaa-0000-0000-0000-000000000001'
    then 'd0000000-0000-0000-0000-000000000001'::uuid
    else 'd0000000-0000-0000-0000-000000000004'::uuid end,
  'preferred', 0
from public.jobs j;

insert into public.job_context_items(
  id, organization_id, job_id, kind, label, text_content, url, sort_order
) values
  ('ca000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000003','inline_text','Sealed context','never leak this context',null,0),
  ('ca000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000004','shared_chat','Link to chat',null,'https://example.test/private-link',0);

insert into public.submissions(
  id, job_id, organization_id, submitted_by_membership_id, status,
  model_used_text, tools_used, response_text, notes, revision_number, submitted_at
) values
  ('e0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','draft','','{}','',null,null,null),
  ('e0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','draft','','{}','',null,null,null),
  ('e0000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000005','submitted','Test model','{}','historical finalized response',null,1,now()),
  ('e0000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000007','draft','','{}','',null,null,null),
  ('e0000000-0000-0000-0000-000000000005','c0000000-0000-0000-0000-000000000015','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','submitted','Test model','{}','prior revision response',null,1,now());

insert into public.revision_requests(
  id, organization_id, job_id, submission_id, requested_by_membership_id, instructions
) values (
  'ee000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000015','e0000000-0000-0000-0000-000000000005',
  'a0000000-0000-0000-0000-000000000002','Please revise this result.'
);

insert into public.job_files(
  id, job_id, organization_id, uploaded_by_membership_id, storage_path,
  original_filename, safe_filename, mime_type, size_bytes, upload_status, ready_at
) values
  ('f0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000003/job/11111111-1111-1111-1111-111111111111','sealed.txt','sealed.txt','text/plain',4,'ready',now()),
  ('f0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000012/job/22222222-2222-2222-2222-222222222222','pending.txt','pending.txt','text/plain',4,'pending',null),
  ('f0000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','upload.txt','upload.txt','text/plain',4,'pending',null),
  ('f0000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000008','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/job/44444444-4444-4444-4444-444444444444','delete.txt','delete.txt','text/plain',4,'ready',now()),
  ('f0000000-0000-0000-0000-000000000014','c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000014/job/14000000-0000-0000-0000-000000000001','one.pdf','one.pdf','application/pdf',26214400,'pending',null),
  ('f0000000-0000-0000-0000-000000000015','c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000014/job/14000000-0000-0000-0000-000000000002','two.pdf','two.pdf','application/pdf',26214400,'pending',null),
  ('f0000000-0000-0000-0000-000000000016','c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000014/job/14000000-0000-0000-0000-000000000003','three.pdf','three.pdf','application/pdf',26214400,'pending',null),
  ('f0000000-0000-0000-0000-000000000017','c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000014/job/14000000-0000-0000-0000-000000000004','four.pdf','four.pdf','application/pdf',26214400,'pending',null);

insert into public.submission_files(
  id, submission_id, job_id, organization_id, uploaded_by_membership_id,
  storage_path, original_filename, safe_filename, mime_type, size_bytes,
  upload_status, ready_at
) values
  ('fa000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000004/submission/e0000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','draft-result.txt','draft-result.txt','text/plain',4,'ready',now()),
  ('fa000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/submission/e0000000-0000-0000-0000-000000000002/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','expired-draft.txt','expired-draft.txt','text/plain',4,'ready',now()),
  ('fa000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000006/submission/e0000000-0000-0000-0000-000000000003/cccccccc-cccc-cccc-cccc-cccccccccccc','history.txt','history.txt','text/plain',4,'ready',now()),
  ('fa000000-0000-0000-0000-000000000004','e0000000-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000007/submission/e0000000-0000-0000-0000-000000000004/dddddddd-dddd-dddd-dddd-dddddddddddd','deactivated-draft.txt','deactivated-draft.txt','text/plain',4,'ready',now());

create function pg_temp.valid_draft_input()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'title','Valid draft', 'task_summary','Safe listing summary',
    'prompt','Perform the exact next task',
    'chat_url','https://example.test/shared-chat',
    'preferred_model_text','GPT-6 Astra',
    'acceptable_models_text','Any frontier model',
    'deadline',to_char(now() + interval '1 day','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'required_tools',jsonb_build_array('Code execution')
  )
$$;

-- Schema, privilege, and fail-closed structure.
select has_table('public','jobs','jobs exists');
select has_table('public','profile_photos','profile photo metadata exists');
select has_function('public','update_draft_job',array['uuid','jsonb'],'draft updates use an RPC');
select has_function('public','update_and_publish_job',array['uuid','jsonb'],'visible draft edits and publication can commit atomically');
select has_function('public','admin_delete_unclaimed_invitation',array['uuid','uuid'],'unclaimed invitations use a narrow deletion RPC');
select has_function('public','edit_submitted_result',array['uuid','text','text','text','text','text'],'submitted-result correction uses an author-scoped RPC');
select has_function('public','reserve_profile_photo',array['uuid','text','text','bigint'],'profile photo upload uses an exact reservation RPC');
select has_function('public','admin_update_membership',array['uuid','uuid','member_role','boolean'],'admin membership lifecycle uses an RPC');
select has_function('public','file_cleanup_info',array['uuid','text'],'file cleanup path is explicit');
select has_function('storage','allow_any_operation',array['text[]'],'Storage supports operation-aware RLS');
select ok((select count(*)=15 and bool_and(c.relrowsecurity)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname=any(array[
    'organizations','memberships','models','member_models','jobs','job_payloads',
    'job_models','job_context_items','job_files','submissions','submission_files',
    'revision_requests','notifications','audit_events','profile_photos'
  ])),'all exposed application tables use RLS');
select ok((select count(*)=9 and bool_and(convalidated) from pg_constraint where conname in (
  'memberships_claimed_user_consistent','memberships_invited_email_valid','jobs_claim_fields_consistent',
  'jobs_inactive_state_unassigned','jobs_cancelled_was_published','context_shape',
  'submissions_state_consistent','jobs_parent_same_org_fk','audit_job_same_org_fk'
)),'hardening constraints validate existing rows');
select ok(not has_table_privilege('anon','public.jobs','SELECT'),'anonymous lacks job grants');
select ok(not has_table_privilege('authenticated','public.jobs','UPDATE'),'direct workflow updates are denied');
select ok(not has_table_privilege('authenticated','public.jobs','INSERT'),'direct job inserts are denied');
select ok(not has_table_privilege('authenticated','public.jobs','DELETE'),'direct job deletes are denied');
select ok(not has_table_privilege('authenticated','public.memberships','UPDATE'),'direct membership updates are denied');
select ok(not has_column_privilege('authenticated','public.memberships','invited_email','SELECT'),'ordinary table reads cannot expose invitation emails');
select ok(not has_column_privilege('authenticated','public.memberships','user_id','SELECT'),'ordinary table reads cannot expose Auth bindings');
select ok(not has_column_privilege('authenticated','public.jobs','sensitivity_notes','SELECT'),'sealed sensitivity notes are not directly selectable');
select ok(not has_column_privilege('authenticated','public.jobs','assigned_to_membership_id','SELECT'),'claimant membership IDs are not directly selectable');
select ok(not has_column_privilege('authenticated','public.job_files','storage_path','SELECT'),'Storage paths are not directly selectable');
select ok(not has_function_privilege('anon','public.claim_job(uuid)','EXECUTE'),'anonymous cannot execute workflow RPCs');
select ok(not exists(
  select 1
  from pg_proc p
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) acl
  where p.oid='public.admin_update_membership(uuid,uuid,public.member_role,boolean)'::regprocedure
    and acl.grantee=0 and acl.privilege_type='EXECUTE'
),'PUBLIC cannot execute admin RPCs');
select ok(has_function_privilege('authenticated','public.claim_job(uuid)','EXECUTE'),'authenticated callers can execute the narrow claim RPC');
select is((select public from storage.buckets where id='job-files'),false,'job-files bucket is private');
select ok((select position('storage.object.delete_many' in qual)>0
  and position('storage.object.list' in qual)=0
  from pg_policies where schemaname='storage' and tablename='objects' and policyname='authorized_download'),
  'Storage SELECT permits exact get/delete operations but never listing');
select ok((select pg_get_functiondef('private.can_storage_upload(text,jsonb)'::regprocedure) ilike '%for key share%'),
  'upload authorization locks the job against concurrent deletion');
select ok((select pg_get_functiondef('public.claim_job(uuid)'::regprocedure) ilike '%locked_actor%'),
  'claim serializes actor activity with membership deactivation');
select ok((select pg_get_functiondef('public.request_revision(uuid,text)'::regprocedure) ilike '%for key share%'),
  'revision reassignment locks the prior submitter against concurrent deactivation');
select ok(not has_function_privilege('authenticated','private.locked_actor(uuid)','EXECUTE'),
  'locking actor helper is not directly exposed');
select is(
  private.merge_legacy_prompt(E'check every result\nwithout rewriting it', E'JSON object\nwith exact keys'),
  E'DEFINITION OF DONE\ncheck every result\nwithout rewriting it\n\nDESIRED OUTPUT FORMAT\nJSON object\nwith exact keys',
  'legacy success criteria and output format are both preserved in the labeled prompt backfill'
);
select ok(not exists(
  select 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  left join pg_roles grantee on grantee.oid = acl.grantee
  where n.nspname = 'public'
    and p.proname = any(array[
      'claim_available_memberships','my_active_memberships','create_draft_job',
      'update_draft_job','update_and_publish_job','publish_job','claim_job','release_job','extend_claim',
      'create_submission_draft','submit_result','request_revision','accept_job',
      'cancel_job','reopen_job','mark_notification_read','dashboard_jobs',
      'job_workspace','update_profile','admin_upsert_membership',
      'admin_update_membership','admin_delete_unclaimed_invitation',
      'admin_memberships','create_follow_up_draft','edit_submitted_result',
      'reserve_job_file','finalize_job_file','reserve_submission_file',
      'finalize_submission_file','file_download_info','file_cleanup_info',
      'delete_file_record','begin_job_deletion','delete_job_after_storage_cleanup',
      'reserve_profile_photo','finalize_profile_photo',
      'profile_photo_download_info','profile_photo_cleanup_info',
      'delete_profile_photo_record'
    ])
    and acl.privilege_type = 'EXECUTE'
    and (acl.grantee = 0 or grantee.rolname = 'anon')
), 'no application RPC overload is executable by PUBLIC or anon');
select ok(
  not exists(
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.submit_result(uuid,text,text,text,text[])')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  )
  and not exists(
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.update_profile(uuid,text,text[],uuid[],jsonb)')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ), 'authenticated cannot execute stale broad RPC overloads');
select ok(
  (select count(*)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'private'
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')) = 15
  and (select count(*)
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'private'
         and has_function_privilege('authenticated', p.oid, 'EXECUTE')
         and p.oid = any(array[
           to_regprocedure('private.actor(uuid)'),
           to_regprocedure('private.can_payload(public.jobs)'),
           to_regprocedure('private.can_payload_job(uuid)'),
           to_regprocedure('private.can_read_job_content(uuid)'),
           to_regprocedure('private.can_read_protected_job(uuid)'),
           to_regprocedure('private.can_read_job_file(uuid)'),
           to_regprocedure('private.can_read_submission(uuid)'),
           to_regprocedure('private.can_read_submission_file(uuid)'),
           to_regprocedure('private.can_storage_upload(text,jsonb)'),
           to_regprocedure('private.can_storage_download(text)'),
           to_regprocedure('private.can_storage_delete(text)'),
           to_regprocedure('private.can_read_profile_photo(uuid)'),
           to_regprocedure('private.can_profile_photo_storage_upload(text,jsonb)'),
           to_regprocedure('private.can_profile_photo_storage_download(text)'),
           to_regprocedure('private.can_profile_photo_storage_delete(text)')
         ])) = 15
  and not exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    left join pg_roles grantee on grantee.oid = acl.grantee
    where n.nspname = 'private'
      and acl.privilege_type = 'EXECUTE'
      and (acl.grantee = 0 or grantee.rolname = 'anon')
  ), 'private helper execution exactly matches the authenticated RLS allowlist');

-- Anonymous, uninvited, deactivated, exact-email, and cross-org callers.
set local role anon;
set local "request.jwt.claim.sub" = '';
select throws_ok(
  $$select public.claim_available_memberships()$$,
  '42501', null, 'anonymous callers cannot invoke membership claim'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000007';
select is((select count(id) from public.jobs),0::bigint,'institutional-domain outsider sees no jobs');
select is((select count(*) from public.my_active_memberships()),0::bigint,'uninvited Auth user has no membership');
select throws_ok(
  $$select public.admin_upsert_membership('aaaaaaaa-0000-0000-0000-000000000001','attacker@example.test','admin')$$,
  'administrator access required', 'uninvited caller cannot bootstrap itself as admin'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000006';
select is((select count(id) from public.jobs),0::bigint,'deactivated membership loses access immediately');
select is((select count(*) from public.my_active_memberships()),0::bigint,'deactivated session is not an active membership');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select is((select count(id) from public.jobs where organization_id='aaaaaaaa-0000-0000-0000-000000000001'),0::bigint,'organization B admin cannot read organization A listings');
select is((select count(id) from public.jobs where id='c0000000-0000-0000-0000-000000000013'),1::bigint,'organization B admin can read its own listing');
reset role;

-- job_workspace intentionally returns null rather than raising for an unknown org.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select ok(public.job_workspace('c0000000-0000-0000-0000-000000000003') is null,'cross-org workspace is indistinguishable from absent');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000009';
select is((select count(*) from public.claim_available_memberships()),1::bigint,'confirmed exact email claims its invitation');
select is((select count(*) from public.my_active_memberships()),1::bigint,'claimed exact-email membership becomes active');
reset role;

-- Simulate Auth deletion followed by a new account reusing the same email.
delete from auth.users where id='10000000-0000-0000-0000-000000000009';
insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000010',
  'authenticated','authenticated','exact@example.test','',now(),'{}','{}',now(),now(),'','','',''
);
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000010';
select is((select count(*) from public.claim_available_memberships()),0::bigint,'recreated Auth account cannot steal a previously bound invitation');
select is((select count(*) from public.my_active_memberships()),0::bigint,'invite thief remains uninvited');
reset role;
select is((select claimed_user_id from public.memberships where id='a0000000-0000-0000-0000-000000000009'),
  '10000000-0000-0000-0000-000000000009'::uuid,'durable invitation binding survives Auth deletion');

-- Draft, lab, sealed, historical-participant, and direct-table boundaries.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select is((select count(id) from public.organizations),1::bigint,'active member can read only its own organization without hidden membership grants');
select is((select count(id) from public.memberships),1::bigint,'ordinary member sees only its own membership row');
select is((select count(id) from public.jobs where id='c0000000-0000-0000-0000-000000000001'),0::bigint,'unrelated member cannot see a private draft listing');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000002'),0::bigint,'organization membership alone cannot read protected payload');
select is((select count(job_id) from public.job_models where job_id='c0000000-0000-0000-0000-000000000002'),0::bigint,'organization membership alone cannot read legacy protected model requirements');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000003'),0::bigint,'unrelated member cannot read sealed payload before claim');
select is((select count(id) from public.job_context_items where job_id='c0000000-0000-0000-0000-000000000003'),0::bigint,'unrelated member cannot read sealed context before claim');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000003')->'payload','null'::jsonb,'sealed workspace omits protected payload before claim');
select is((select count(id) from public.jobs where id='c0000000-0000-0000-0000-000000000011'),0::bigint,'unrelated member cannot see a sealed draft listing');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000011'),0::bigint,'sealed visibility never publishes a draft payload');
select is((select count(id) from public.job_files where job_id='c0000000-0000-0000-0000-000000000011'),0::bigint,'sealed visibility never exposes draft file metadata');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333'),'sealed draft object is not downloadable by unrelated member');
select throws_ok(
  $$update public.jobs set status='accepted' where id='c0000000-0000-0000-0000-000000000002'$$,
  '42501', null, 'direct workflow mutation is rejected'
);
select throws_ok(
  $$insert into public.submissions(job_id,organization_id,submitted_by_membership_id) values ('c0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003')$$,
  '42501', null, 'direct submission insertion is rejected'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000005';
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000006'),1::bigint,'historical finalized submitter retains sealed payload access');
select lives_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000003','submission')$$,
  'historical finalized submitter can resolve its submitted file'
);
reset role;

-- Server-authoritative draft validation and publication.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"required_tools":["Shell"]}'::jsonb)$$,
  'invalid required tools', 'direct RPC rejects tools outside the supported catalog'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() - 'prompt')$$,
  'invalid draft input', 'draft RPC requires the complete typed JSON shape even when field values are blank'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"deadline":"2099-01-01T12:00:00"}'::jsonb)$$,
  'deadline must be an ISO-8601 date-time with explicit timezone', 'direct RPC rejects timezone-less deadlines'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"deadline":"January 1 2099 12:00:00Z"}'::jsonb)$$,
  'deadline must be an ISO-8601 date-time with explicit timezone', 'direct RPC rejects non-ISO timestamp text'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"chat_url":"https://user:password@evil.test/file"}'::jsonb)$$,
  'invalid draft value', 'direct RPC rejects a credential-bearing shared-chat URL'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"chat_url":"https://:"}'::jsonb)$$,
  'invalid draft value', 'direct RPC rejects malformed shared-chat authority'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || jsonb_build_object('preferred_model_text',repeat('m',201)))$$,
  'invalid draft value', 'free-form preferred model text has a database length limit'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || jsonb_build_object('acceptable_models_text',repeat('m',1001)))$$,
  'invalid draft value', 'free-form acceptable-model text has a database length limit'
);
select throws_ok(
  $$select public.cancel_job('c0000000-0000-0000-0000-000000000001')$$,
  'not allowed', 'draft cannot be cancelled into a visible unpublished state'
);
select throws_ok(
  $$select public.publish_job('c0000000-0000-0000-0000-000000000012')$$,
  'job is incomplete', 'pending upload blocks publication'
);
select lives_ok(
  $$select set_config(
    'brainswap_test.partial_job',
    public.create_draft_job(
      'aaaaaaaa-0000-0000-0000-000000000001',
      '{"title":"","task_summary":"","prompt":"","chat_url":"","preferred_model_text":"","acceptable_models_text":"","deadline":null,"required_tools":[]}'::jsonb
    )::text,
    false
  )$$,
  'an entirely blank draft can be saved'
);
select ok((
  select status = 'draft'
    and title = '' and listing_summary = '' and preferred_model_text = ''
    and visibility = 'claimed_only' and sensitivity = 'general'
    and effort = 'medium' and required_tools = '{}'::text[]
  from public.jobs where id = current_setting('brainswap_test.partial_job')::uuid
), 'blank drafts retain fixed sealed/general classification without inventing content');
select is(
  (select count(*) from public.dashboard_jobs(
    'aaaaaaaa-0000-0000-0000-000000000001', 'drafts'
  ) where id = current_setting('brainswap_test.partial_job')::uuid),
  1::bigint,
  'requester can open a partial draft from the dedicated drafts dashboard'
);
select is(
  (select count(*) from public.dashboard_jobs(
    'aaaaaaaa-0000-0000-0000-000000000001', 'requests'
  ) where id = current_setting('brainswap_test.partial_job')::uuid),
  0::bigint,
  'partial drafts never appear in the requester published-job dashboard'
);
select throws_ok(
  $$select public.publish_job(current_setting('brainswap_test.partial_job')::uuid)$$,
  'job is incomplete', 'publish remains the authoritative completeness gate for partial drafts'
);
select lives_ok(
  $$select public.update_draft_job('c0000000-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{prompt}',to_jsonb(E'  Preserve prompt formatting\n'::text)))$$,
  'requester can update a complete draft through the authoritative RPC'
);
reset role;
select is((select prompt from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000001'),E'  Preserve prompt formatting\n','draft RPC preserves significant prompt whitespace');
select ok((select current_task=repeat('Legacy task detail. ',80)
  from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000001'),
  'draft updates preserve oversized legacy current-task detail without forcing it into the bounded summary');
select ok((select success_criteria='' and output_format=''
  from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000001'),
  'draft updates leave migrated legacy instruction columns cleared after their prompt backfill');
select is((select preferred_model_text from public.jobs where id='c0000000-0000-0000-0000-000000000001'),'GPT-6 Astra','free-form preferred model text is stored without a model identifier dependency');
select is((select count(*) from public.job_models where job_id='c0000000-0000-0000-0000-000000000001'),0::bigint,'new draft writes retire normalized job-model rows');
select is((select count(*) from public.job_context_items where job_id='c0000000-0000-0000-0000-000000000001' and kind='shared_chat'),1::bigint,'new draft writes allow only one protected shared-chat link');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select throws_ok(
  $$select public.publish_job('c0000000-0000-0000-0000-000000000001')$$,
  'not authorized', 'nonrequester cannot publish a draft'
);
select throws_ok(
  $$select public.update_and_publish_job('c0000000-0000-0000-0000-000000000001',pg_temp.valid_draft_input())$$,
  'not authorized', 'nonrequester cannot atomically edit and publish a draft'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select public.update_and_publish_job(
    'c0000000-0000-0000-0000-000000000001',
    jsonb_set(
      jsonb_set(pg_temp.valid_draft_input(),'{title}',to_jsonb('Must roll back'::text)),
      '{prompt}',to_jsonb(''::text)
    )
  )$$,
  'job is incomplete', 'atomic publication rejects incomplete visible editor data'
);
select is(
  (select title from public.jobs where id='c0000000-0000-0000-0000-000000000001'),
  'Valid draft', 'failed atomic publication rolls its draft edits back'
);
select lives_ok(
  $$select public.update_and_publish_job(
    'c0000000-0000-0000-0000-000000000001',
    jsonb_set(pg_temp.valid_draft_input(),'{title}',to_jsonb('Published editor title'::text))
  )$$,
  'requester can save the visible editor data and publish it atomically'
);
select is(
  (select title from public.jobs where id='c0000000-0000-0000-0000-000000000001'),
  'Published editor title', 'atomic publication persists the visible editor values'
);
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000001'),'open'::public.job_status,'publication performs draft to open transition');
select is((select required_tools from public.jobs where id='c0000000-0000-0000-0000-000000000001'),array['Code execution']::text[],'publication preserves validated required tools');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000001')->'payload'->>'task_summary',
  'Safe listing summary', 'new jobs fall back to the listing task summary without duplicating prompt text');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000001')->'payload'->>'legacy_current_task',
  repeat('Legacy task detail. ',80), 'published legacy drafts retain their exact oversized task detail separately from the editable summary');
reset role;
select is((select count(*) from public.notifications where job_id='c0000000-0000-0000-0000-000000000001' and recipient_membership_id='a0000000-0000-0000-0000-000000000002'),0::bigint,'publication excludes requester from matching notices');
select ok(not exists(
  select 1 from public.notifications
  where job_id='c0000000-0000-0000-0000-000000000001'
    and message <> 'A new BrainSwap job is available.'
),'matching notices contain safe static metadata only');

-- Atomic claims, expired claims, self-claim, and sealed/draft-result visibility.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok($$select public.claim_job('c0000000-0000-0000-0000-000000000003')$$,'not eligible','requester cannot claim its own job');
select is((select count(id) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004'),0::bigint,'requester cannot see claimant draft submission row');
select is((select count(id) from public.submission_files where job_id='c0000000-0000-0000-0000-000000000004'),0::bigint,'requester cannot see claimant draft attachment metadata');
select throws_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'file not found', 'requester cannot download claimant draft attachment'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select lives_ok($$select public.extend_claim('c0000000-0000-0000-0000-000000000004')$$,'current claimant can extend an unexpired claim');
select lives_ok($$select public.release_job('c0000000-0000-0000-0000-000000000004')$$,'current claimant can release an unexpired claim');
reset role;
select ok((select status='open' and assigned_to_membership_id is null and claimed_at is null and claim_expires_at is null from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'claim release atomically clears every assignment field');
update public.jobs
set status='claimed', assigned_to_membership_id='a0000000-0000-0000-0000-000000000003',
  claimed_at=now(), claim_expires_at=now()+interval '4 hours'
where id='c0000000-0000-0000-0000-000000000004';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select lives_ok($$select public.claim_job('c0000000-0000-0000-0000-000000000004')$$,'same active claimant retry is idempotent');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'current unexpired claimant sees sealed payload');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000004')->'payload',jsonb_build_object(
  'prompt','protected prompt for c0000000-0000-0000-0000-000000000004',
  'task_summary','Safe current listing',
  'legacy_current_task','protected task for c0000000-0000-0000-0000-000000000004'
), 'legacy current task is preserved separately from the bounded protected task summary');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000004')->'contexts'->0->>'url',
  'https://example.test/private-link',
  'participant workspace exposes the preserved shared-chat URL as protected context');
select is((select count(id) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'claimant sees only its own current draft submission');
select lives_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'current claimant can resolve its own ready draft attachment'
);
select is(public.job_workspace('c0000000-0000-0000-0000-000000000004')->'pending_files'->0->>'id',
  'fa000000-0000-0000-0000-000000000001',
  'current claimant workspace surfaces its ready draft-result attachment for removal');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000004')->'pending_files'->0->>'can_cleanup',
  'true', 'current claimant workspace marks its own draft-result attachment removable');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000005'),0::bigint,'expired claimant loses sealed payload access');
select throws_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000005','Model','late result','','low',null)$$,
  'result incomplete', 'expired claimant cannot submit'
);
select throws_ok($$select public.extend_claim('c0000000-0000-0000-0000-000000000005')$$,'claim expired','expired claimant cannot extend');
select throws_ok($$select public.release_job('c0000000-0000-0000-0000-000000000005')$$,'not current claimant','expired claimant cannot release');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.cancel_job('c0000000-0000-0000-0000-000000000004')$$,'requester can cancel an actively claimed job');
reset role;
select ok((select status='cancelled' and assigned_to_membership_id is null and claimed_at is null and claim_expires_at is null from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'active cancellation atomically clears every assignment field');
update public.jobs
set status='claimed', assigned_to_membership_id='a0000000-0000-0000-0000-000000000003',
  claimed_at=now(), claim_expires_at=now()+interval '4 hours'
where id='c0000000-0000-0000-0000-000000000004';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000004';
select is((select count(id) from public.revision_requests where job_id='c0000000-0000-0000-0000-000000000015'),0::bigint,'unrelated member cannot read protected revision instructions');
select throws_ok($$select public.claim_job('c0000000-0000-0000-0000-000000000004')$$,'already claimed','competing claimant loses atomic claim race');
select throws_ok($$select public.extend_claim('c0000000-0000-0000-0000-000000000004')$$,'claim expired','nonclaimant cannot extend another member claim');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000004')->'payload','null'::jsonb,'failed competing claimant learns no sealed payload');
select lives_ok($$select public.claim_job('c0000000-0000-0000-0000-000000000005')$$,'new helper can replace an expired claimed-state assignment');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000005'),1::bigint,'successful replacement claimant gains sealed payload');
select lives_ok($$select public.claim_job('c0000000-0000-0000-0000-000000000015')$$,'new helper can replace an expired revision-request assignment');
reset role;
select is((select assigned_to_membership_id from public.jobs where id='c0000000-0000-0000-0000-000000000015'),'a0000000-0000-0000-0000-000000000004'::uuid,'expired revision claim is reassigned atomically');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000005'),0::bigint,'replaced claimant remains unable to read sealed payload');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/submission/e0000000-0000-0000-0000-000000000002/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'replaced claimant cannot download its stale draft attachment');
select ok(not private.can_storage_delete('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/submission/e0000000-0000-0000-0000-000000000002/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'replaced claimant cannot delete an exact path before authorized cleanup starts');
reset role;

-- Requester can remove, but never download, a replaced claimant's stale draft file.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select is(public.job_workspace('c0000000-0000-0000-0000-000000000005')->'pending_files'->0->>'stale','true','workspace marks replaced claimant draft file stale');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000005')->'pending_files'->0->>'can_cleanup','true','requester workspace marks a stale claimant attachment removable');
select throws_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000002','submission')$$,
  'file not found', 'stale cleanup authority does not grant draft download'
);
select lives_ok(
  $$select * from public.file_cleanup_info('fa000000-0000-0000-0000-000000000002','submission')$$,
  'requester can begin stale draft cleanup'
);
select ok(private.can_storage_delete('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/submission/e0000000-0000-0000-0000-000000000002/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'delete operation is authorized for exact stale path');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/submission/e0000000-0000-0000-0000-000000000002/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'stale path remains non-downloadable');
select lives_ok($$select public.delete_file_record('fa000000-0000-0000-0000-000000000002','submission')$$,'stale draft metadata deletion is retryable after Storage removal');
reset role;
select is((select count(*) from public.submission_files where id='fa000000-0000-0000-0000-000000000002'),0::bigint,'stale draft file row is removed');

-- Submission, revision, immutable history, acceptance, cancellation, and follow-up.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select throws_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model','first finalized response','','unsupported',null)$$,
  'result incomplete', 'submission tools are validated at the database boundary'
);
select lives_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model',E'  first finalized response\n','notes','high',null)$$,
  'current claimant can submit a complete result'
);
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'submitted'::public.job_status,'submission advances job state');
select is((select count(*) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004' and status='submitted'),1::bigint,'first finalized submission is retained');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select is((select count(*) from public.dashboard_jobs('aaaaaaaa-0000-0000-0000-000000000001','claimed') where id='c0000000-0000-0000-0000-000000000004'),1::bigint,'an unlocked submitted result remains in the submitter claimed dashboard');
select throws_ok(
  $$select public.edit_submitted_result('c0000000-0000-0000-0000-000000000004','Test model','edited response','','other',null)$$,
  'result is not editable', 'Other reasoning effort requires a bounded explanation'
);
select lives_ok(
  $$select public.edit_submitted_result('c0000000-0000-0000-0000-000000000004','Edited model',E'  corrected finalized response\n','corrected notes','other','Custom budget')$$,
  'latest submitter can correct a result before requester action'
);
select lives_ok(
  $$select * from public.file_cleanup_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'latest submitter can mark an attached submitted-result file for cleanup before review'
);
select throws_ok($$select public.request_revision('c0000000-0000-0000-0000-000000000004','Unauthorized revision request.')$$,'not allowed','nonrequester cannot request a revision');
reset role;
select ok((select count(*)=1 and min(revision_number)=1 and max(revision_number)=1
  from public.submissions where job_id='c0000000-0000-0000-0000-000000000004' and status='submitted'),
  'result correction updates in place without fabricating a new revision');
select is((select response_text from public.submissions where id='e0000000-0000-0000-0000-000000000001'),E'  corrected finalized response\n','result correction preserves significant response whitespace');
select ok((select reasoning_effort='other' and reasoning_effort_other='Custom budget' and edited_at is not null
  from public.submissions where id='e0000000-0000-0000-0000-000000000001'),
  'result correction stores validated reasoning effort and an edit timestamp');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000004';
select throws_ok(
  $$select public.edit_submitted_result('c0000000-0000-0000-0000-000000000004','Attack','overwrite','','low',null)$$,
  'result is not editable', 'unrelated member cannot edit another member submitted result'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select public.edit_submitted_result('c0000000-0000-0000-0000-000000000004','Requester','overwrite','','low',null)$$,
  'result is not editable', 'requester review authority does not confer result edit authority'
);
select lives_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000004')$$,'requester may reopen a submitted job');
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'open'::public.job_status,'submitted reopen returns job to an unassigned open state');
select ok((select j.requester_action_at is not null and s.edit_locked_at is not null
  from public.jobs j join public.submissions s on s.job_id=j.id and s.status='submitted'
  where j.id='c0000000-0000-0000-0000-000000000004'),
  'first requester action atomically closes the submitted-result edit window');
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok(
  $$select public.delete_file_record('fa000000-0000-0000-0000-000000000001','submission')$$,
  'requester can finish deletion of an already cleanup-marked result attachment after locking edits'
);
reset role;
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select throws_ok(
  $$select public.edit_submitted_result('c0000000-0000-0000-0000-000000000004','Too late','overwrite','','low',null)$$,
  'result is not editable', 'submitter cannot edit after requester action'
);
select is((select count(*) from public.dashboard_jobs('aaaaaaaa-0000-0000-0000-000000000001','claimed') where id='c0000000-0000-0000-0000-000000000004'),0::bigint,'requester action removes the locked result from the submitter claimed dashboard');
reset role;
update public.jobs set status='submitted' where id='c0000000-0000-0000-0000-000000000004';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select is((select count(id) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'requester sees submitted result after finalization');
select throws_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'file not found', 'removed submitted-result attachment cannot be resolved after cleanup'
);
select lives_ok(
  $$select public.request_revision('c0000000-0000-0000-0000-000000000004','Please verify one more case.')$$,
  'requester can request revision of submitted result'
);
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'revision_requested'::public.job_status,'revision request advances state');
select is((select assigned_to_membership_id from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'a0000000-0000-0000-0000-000000000003'::uuid,'active bound prior submitter receives revision claim');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000004')$$,'requester may reopen a revision-requested job');
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'open'::public.job_status,'revision-requested reopen clears its assignment and returns open');
update public.jobs
set status='revision_requested', assigned_to_membership_id='a0000000-0000-0000-0000-000000000003',
  claimed_at=now(), claim_expires_at=now()+interval '4 hours'
where id='c0000000-0000-0000-0000-000000000004';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000004';
select throws_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Model','unauthorized','','low',null)$$,
  'result incomplete', 'unassigned member cannot submit a revision'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select lives_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model','second finalized response','','ultra',null)$$,
  'revision claimant can submit a new immutable revision'
);
select throws_ok($$select public.accept_job('c0000000-0000-0000-0000-000000000004')$$,'not allowed','helper cannot accept its own result');
reset role;
select is((select count(*) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004' and status='submitted'),2::bigint,'submission history keeps both revisions');
select is((select response_text from public.submissions where id='e0000000-0000-0000-0000-000000000001'),E'  corrected finalized response\n','locked prior submission preserves the submitter correction and remains immutable');
select is((select count(*) from public.revision_requests where job_id='c0000000-0000-0000-0000-000000000004' and resolved_at is not null),1::bigint,'new submission resolves the open revision request');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.accept_job('c0000000-0000-0000-0000-000000000004')$$,'requester can accept latest submitted revision');
select throws_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000004')$$,'not allowed','accepted job is terminal');
select lives_ok(
  $$select set_config(
    'brainswap_test.follow_up_job',
    public.create_follow_up_draft('c0000000-0000-0000-0000-000000000004')::text,
    false
  )$$,
  'requester can create follow-up from finalized result'
);
select is(
  public.job_workspace(current_setting('brainswap_test.follow_up_job')::uuid)->'contexts'->0->>'text_content',
  'second finalized response', 'follow-up requester workspace returns the intentional prior-result snapshot'
);
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'accepted'::public.job_status,'acceptance records terminal state');
select is((select count(*) from public.jobs where parent_job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'follow-up records parent provenance');
select is((select count(*) from public.job_context_items c join public.jobs j on j.id=c.job_id where j.parent_job_id='c0000000-0000-0000-0000-000000000004' and c.kind='previous_job' and c.text_content='second finalized response'),1::bigint,'follow-up stores intentional finalized-output snapshot');
select ok((select sensitivity_notes is null from public.jobs where parent_job_id='c0000000-0000-0000-0000-000000000004'),'follow-up does not copy sealed parent sensitivity notes');
select is((select count(*) from public.job_files f join public.jobs j on j.id=f.job_id where j.parent_job_id='c0000000-0000-0000-0000-000000000004'),0::bigint,'follow-up does not silently copy files');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select is((select count(*) from public.dashboard_jobs('aaaaaaaa-0000-0000-0000-000000000001','drafts') where title like 'Follow-up:%'),0::bigint,'nonrequester cannot see follow-up draft through provenance');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.cancel_job('c0000000-0000-0000-0000-000000000002')$$,'requester can cancel a published active job');
select lives_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000002')$$,'requester can reopen a previously published cancelled job');
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000002'),'open'::public.job_status,'safe reopen returns published job to open');
reset role;

-- Deleted-Auth historical submitter must never receive an unusable revision claim.
delete from auth.users where id='10000000-0000-0000-0000-000000000005';
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.request_revision('c0000000-0000-0000-0000-000000000006','A new revision is needed.')$$,'requester may request revision after submitter Auth deletion');
reset role;
select ok((select assigned_to_membership_id is null and claim_expires_at is null from public.jobs where id='c0000000-0000-0000-0000-000000000006'),'deleted-Auth submitter is not auto-assigned');
select is((select count(*) from public.notifications where job_id='c0000000-0000-0000-0000-000000000006' and recipient_membership_id='a0000000-0000-0000-0000-000000000005' and type='revision_requested'),0::bigint,'deleted-Auth submitter receives no revision notification');

-- Admin scope, last usable admin, profile scope, and deactivation effects.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select public.admin_delete_unclaimed_invitation('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000010')$$,
  'administrator access required', 'ordinary members cannot remove invitations'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select lives_ok(
  $$select public.admin_upsert_membership('bbbbbbbb-0000-0000-0000-000000000001','unclaimed-admin@example.test','admin')$$,
  'admin may create an unclaimed admin invitation'
);
select throws_ok(
  $$select public.admin_update_membership('bbbbbbbb-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','member',true)$$,
  'cannot remove the last active administrator', 'unclaimed admin invitation does not satisfy last-admin guard'
);
select throws_ok(
  $$select public.admin_delete_unclaimed_invitation('bbbbbbbb-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000010')$$,
  'only an unclaimed invitation can be removed', 'cross-organization admin cannot remove or probe another organization invitation'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select throws_ok(
  $$select public.admin_update_membership('bbbbbbbb-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','member',true)$$,
  'administrator access required', 'organization A admin cannot administer organization B'
);
select lives_ok(
  $$select public.admin_update_membership('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000007','member',false)$$,
  'organization admin can deactivate an in-scope member'
);
select throws_ok(
  $$select public.admin_delete_unclaimed_invitation('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000006')$$,
  'only an unclaimed invitation can be removed', 'inactive but previously claimed membership cannot be deleted as an invitation'
);
select throws_ok(
  $$select public.admin_delete_unclaimed_invitation('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002')$$,
  'only an unclaimed invitation can be removed', 'active claimed membership cannot be deleted as an invitation'
);
select lives_ok(
  $$select public.admin_delete_unclaimed_invitation('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000010')$$,
  'organization admin can remove an unclaimed invitation'
);
select is((select count(*) from public.memberships where id='a0000000-0000-0000-0000-000000000010'),0::bigint,'removed invitation no longer authorizes its email');
select ok(not exists(
  select 1 from public.audit_events
  where event_type='membership_invitation_deleted'
    and metadata ?| array['email','invited_email']
), 'invitation deletion audit metadata never records the invited email');
select throws_ok(
  $$select public.update_profile('aaaaaaaa-0000-0000-0000-000000000001','Admin A',repeat('x',2001),array[]::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile', 'profile bio length is validated at the database boundary'
);
select throws_ok(
  $$select public.update_profile('aaaaaaaa-0000-0000-0000-000000000001','Admin A','Bio',array['d0000000-0000-0000-0000-000000000004']::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile models', 'profile cannot select another organization model'
);
select throws_ok(
  $$select public.update_profile('bbbbbbbb-0000-0000-0000-000000000001','Forged org','Bio',array['d0000000-0000-0000-0000-000000000004']::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile', 'organization parameter cannot forge selected membership'
);
select lives_ok(
  $$select public.update_profile(
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Admin A updated',
    'Short profile bio',
    array[(select id from public.models where organization_id='aaaaaaaa-0000-0000-0000-000000000001' and display_name='GPT-6 Astra')],
    '{"new_matching_jobs":false}'
  )$$,
  'valid profile update is selected-organization scoped'
);
reset role;
select ok((select status='open' and assigned_to_membership_id is null and claim_expires_at is null from public.jobs where id='c0000000-0000-0000-0000-000000000007'),'deactivation immediately releases active claim');
select is((select display_name from public.memberships where id='a0000000-0000-0000-0000-000000000001'),'Admin A updated','profile update changes only selected membership');
select is((select bio from public.memberships where id='a0000000-0000-0000-0000-000000000001'),'Short profile bio','profile bio is stored only on the selected membership');

-- Profile photos use an exact private reservation and an owner-controlled
-- cleanup lifecycle, while ready photos are readable inside the organization.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select throws_ok(
  $$select * from public.reserve_profile_photo('aaaaaaaa-0000-0000-0000-000000000001','attack.svg','image/svg+xml',4)$$,
  'profile photo not allowed', 'profile photos reject active-content SVG uploads'
);
select throws_ok(
  $$select * from public.reserve_profile_photo('aaaaaaaa-0000-0000-0000-000000000001','large.png','image/png',5242881)$$,
  'profile photo not allowed', 'profile photos enforce the five MiB limit'
);
select lives_ok(
  $$select
    set_config('brainswap_test.photo_id',r.id::text,false),
    set_config('brainswap_test.photo_path',r.storage_path,false)
  from public.reserve_profile_photo(
    'aaaaaaaa-0000-0000-0000-000000000001','portrait name.png','image/png',4
  ) r$$,
  'profile owner can reserve one valid photo'
);
select ok(
  position('portrait name.png' in current_setting('brainswap_test.photo_path'))=0
  and private.can_profile_photo_storage_upload(
    current_setting('brainswap_test.photo_path'),'{"mimetype":"image/png"}'::jsonb
  )
  and private.can_profile_photo_storage_upload(
    current_setting('brainswap_test.photo_path'),'{"contentLength":333,"mimetype":"image/png"}'::jsonb
  )
  and not private.can_profile_photo_storage_upload(
    current_setting('brainswap_test.photo_path'),'{"contentLength":333,"mimetype":"image/jpeg"}'::jsonb
  ), 'profile photo path is randomized and accepts only the owner and reserved MIME during Storage preflight'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select ok(
  not private.can_profile_photo_storage_upload(
    current_setting('brainswap_test.photo_path'),'{"contentLength":4,"mimetype":"image/png"}'::jsonb
  )
  and not private.can_profile_photo_storage_delete(current_setting('brainswap_test.photo_path')),
  'another organization member cannot use or delete the owner reservation'
);
reset role;

insert into storage.objects(bucket_id, name, metadata) values (
  'profile-photos', current_setting('brainswap_test.photo_path'),
  '{"size":4,"mimetype":"image/png"}'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select lives_ok(
  $$select public.finalize_profile_photo(current_setting('brainswap_test.photo_id')::uuid)$$,
  'profile owner can finalize the matching exact Storage object'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select lives_ok(
  $$select * from public.profile_photo_download_info('a0000000-0000-0000-0000-000000000001')$$,
  'active same-organization member can resolve a ready profile photo'
);
select is(
  (select original_filename from public.profile_photo_download_info('a0000000-0000-0000-0000-000000000001')),
  'portrait-name.png', 'profile photo download metadata returns only the sanitized filename'
);
select throws_ok(
  $$select * from public.profile_photo_cleanup_info(current_setting('brainswap_test.photo_id')::uuid)$$,
  'profile photo not found', 'nonowner cannot begin profile photo cleanup'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select throws_ok(
  $$select * from public.profile_photo_download_info('a0000000-0000-0000-0000-000000000001')$$,
  'profile photo not found', 'cross-organization member cannot resolve profile photo metadata'
);
select ok(not private.can_profile_photo_storage_download(current_setting('brainswap_test.photo_path')),
  'cross-organization member cannot download the exact profile photo path');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select lives_ok(
  $$select * from public.profile_photo_cleanup_info(current_setting('brainswap_test.photo_id')::uuid)$$,
  'profile owner can begin cleanup'
);
select ok(
  private.can_profile_photo_storage_delete(current_setting('brainswap_test.photo_path'))
  and not private.can_profile_photo_storage_download(current_setting('brainswap_test.photo_path')),
  'cleanup authorizes only owner deletion and immediately disables download'
);
reset role;

set local "storage.allow_delete_query" = 'true';
delete from storage.objects
where bucket_id='profile-photos' and name=current_setting('brainswap_test.photo_path');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select lives_ok(
  $$select public.delete_profile_photo_record(current_setting('brainswap_test.photo_id')::uuid)$$,
  'profile owner can remove metadata after exact Storage cleanup'
);
reset role;
select is((select count(*) from public.profile_photos),0::bigint,'completed profile photo cleanup leaves no metadata row');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000011';
select is((select count(id) from public.jobs),0::bigint,'deactivated claimant cannot use still-active Auth session');
select throws_ok(
  $$select public.admin_update_membership('aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000003','admin',true)$$,
  'administrator access required', 'ordinary or deactivated member cannot invoke admin lifecycle RPC'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select is(public.job_workspace('c0000000-0000-0000-0000-000000000007')->'pending_files'->0->>'stale','true','requester sees deactivated claimant draft attachment as stale');
select lives_ok(
  $$select * from public.file_cleanup_info('fa000000-0000-0000-0000-000000000004','submission')$$,
  'requester can begin deactivated claimant draft cleanup'
);
select lives_ok(
  $$select public.delete_file_record('fa000000-0000-0000-0000-000000000004','submission')$$,
  'requester can finish deactivated claimant draft metadata cleanup'
);
reset role;
select is((select count(*) from public.submission_files where id='fa000000-0000-0000-0000-000000000004'),0::bigint,'deactivated claimant stale file no longer consumes quota');

-- Storage rows below are test doubles for objects already written by the
-- Storage service. Application SQL never inserts or deletes storage.objects.
insert into storage.objects(bucket_id, name, metadata) values
  ('job-files','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','{"size":4,"mimetype":"text/plain"}'),
  ('job-files','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/job/44444444-4444-4444-4444-444444444444','{"size":4,"mimetype":"text/plain"}'),
  ('job-files','aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/legacy/untracked-object','{"size":4,"mimetype":"text/plain"}');

-- Reservation, exact-path upload, positive allowlists, quota, and no upsert.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select ok(private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','{"size":4,"mimetype":"text/plain"}'::jsonb),'only exact pending reserved path with matching metadata is uploadable by requester');
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','{"size":5,"mimetype":"text/plain"}'::jsonb),'upload authorization rejects object metadata that exceeds its exact reservation');
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/guessed','{"size":4,"mimetype":"text/plain"}'::jsonb),'guessed Storage path is rejected');
select throws_ok(
  $$select * from public.file_download_info('f0000000-0000-0000-0000-000000000003','job')$$,
  'file not found', 'pending upload cannot be resolved for download'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','attack.svg','image/svg+xml',4,null)$$,
  'file not allowed', 'SVG upload is rejected'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','../escape.txt','text/plain',4,null)$$,
  'file not allowed', 'directory traversal filename is rejected'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','mismatch.pdf','text/plain',4,null)$$,
  'file not allowed', 'extension and MIME mismatch is rejected'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','large.pdf','application/pdf',26214401,null)$$,
  'file not allowed', 'per-file 25 MiB limit is enforced'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000014','extra.txt','text/plain',1,null)$$,
  'job file limit exceeded', '100 MiB job limit counts pending reservations'
);
select ok((select position('report.txt' in r.storage_path)=0
  from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','report.txt','text/plain',4,null) r),
  'reserved path is randomized and contains no raw filename');
select lives_ok($$select public.finalize_job_file('f0000000-0000-0000-0000-000000000003')$$,'matching Storage object finalizes exact reservation');
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','{"size":4,"mimetype":"text/plain"}'::jsonb),'ready object cannot be overwritten through upload policy');
select lives_ok(
  $$select * from public.file_download_info('f0000000-0000-0000-0000-000000000003','job')$$,
  'draft requester can resolve its own ready job file'
);
select is((select count(id) from storage.objects where bucket_id='job-files'),0::bigint,'direct SQL/list operation cannot enumerate private bucket objects');
reset role;

select ok(not exists(
  select 1 from pg_policies
  where schemaname='storage' and tablename='objects' and cmd='UPDATE'
),'no Storage UPDATE policy exists, so upsert overwrite is impossible');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333','{"size":4,"mimetype":"text/plain"}'::jsonb),'different same-organization member cannot use requester reservation');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333'),'unrelated member cannot download ready lab-visible draft object');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000012/job/22222222-2222-2222-2222-222222222222','{"size":4,"mimetype":"text/plain"}'::jsonb),'organization B admin cannot upload to organization A reservation');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333'),'organization B admin cannot download organization A draft object');
select ok(not private.can_storage_delete('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333'),'organization B admin cannot delete organization A exact path');
select throws_ok(
  $$select * from public.file_download_info('f0000000-0000-0000-0000-000000000003','job')$$,
  'file not found', 'cross-organization file metadata lookup fails closed'
);
select throws_ok(
  $$select * from public.reserve_job_file('c0000000-0000-0000-0000-000000000011','cross-org.txt','text/plain',4,null)$$,
  'file not allowed', 'organization B admin cannot reserve against organization A job'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000004';
select set_config('brainswap_test.submission_path',r.storage_path,false)
from public.reserve_submission_file('c0000000-0000-0000-0000-000000000005','competitor.txt','text/plain',4,null) r;
select ok(position('competitor.txt' in current_setting('brainswap_test.submission_path'))=0
    and private.can_storage_upload(current_setting('brainswap_test.submission_path'),'{"size":4,"mimetype":"text/plain"}'::jsonb)
    and not private.can_storage_upload(current_setting('brainswap_test.submission_path'),'{"size":5,"mimetype":"text/plain"}'::jsonb),
  'current replacement claimant gets randomized exact-path upload authorization with matching metadata only');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select ok(not private.can_storage_upload(current_setting('brainswap_test.submission_path'),'{"size":4,"mimetype":"text/plain"}'::jsonb),'requester cannot upload to current claimant submission reservation');
reset role;

-- Job deletion is manifest-first, retryable, child-safe, and Storage-first.
set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select * from public.begin_job_deletion('c0000000-0000-0000-0000-000000000009')$$,
  'job has follow-up children', 'parent deletion is rejected before damaging files when child exists'
);
select ok((select not deletion_pending from public.jobs where id='c0000000-0000-0000-0000-000000000009'),'failed child-protected deletion leaves parent unlocked');
select is((select count(*) from public.begin_job_deletion('c0000000-0000-0000-0000-000000000008')),2::bigint,'first deletion call returns tracked and orphaned exact-prefix Storage manifest');
select is((select count(*) from public.begin_job_deletion('c0000000-0000-0000-0000-000000000008')),2::bigint,'deletion manifest is repeatable after refresh');
select is((select count(*) from public.begin_job_deletion('c0000000-0000-0000-0000-000000000008') where kind='orphan' and file_id is null),1::bigint,'deletion manifest identifies untracked exact-prefix object for retry cleanup');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000008')->'job'->>'deletion_pending','true','authorized deleter can reopen deletion-pending workspace');
select ok(not private.can_storage_upload('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/job/44444444-4444-4444-4444-444444444444','{"size":4,"mimetype":"text/plain"}'::jsonb),'deletion gate blocks any future upload authorization');
select ok(private.can_storage_delete('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/job/44444444-4444-4444-4444-444444444444'),'deletion operation may remove exact manifest object');
select ok(private.can_storage_delete('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/legacy/untracked-object'),'deletion operation may remove exact-prefix orphan object');
select throws_ok(
  $$select public.delete_job_after_storage_cleanup('c0000000-0000-0000-0000-000000000008')$$,
  'storage cleanup required', 'database deletion refuses while Storage object remains'
);
reset role;

-- Simulate the external Storage API completing removal. This test-only cleanup
-- setting is required by recent Storage schema versions and is never used by app SQL.
set local "storage.allow_delete_query" = 'true';
delete from storage.objects
where bucket_id='job-files'
  and name='aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/job/44444444-4444-4444-4444-444444444444';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select throws_ok(
  $$select public.delete_job_after_storage_cleanup('c0000000-0000-0000-0000-000000000008')$$,
  'storage cleanup required', 'untracked legacy object under exact job prefix blocks metadata deletion'
);
reset role;

delete from storage.objects
where bucket_id='job-files'
  and name='aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000008/legacy/untracked-object';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok(
  $$select public.delete_job_after_storage_cleanup('c0000000-0000-0000-0000-000000000008')$$,
  'database job deletion succeeds only after external Storage cleanup'
);
reset role;
select is((select count(*) from public.jobs where id='c0000000-0000-0000-0000-000000000008'),0::bigint,'deleted job metadata is removed');
select ok((select count(*)>=2 from public.audit_events where event_type in ('job_deletion_started','job_deleted')),'audit history survives job deletion');
select ok(not exists(
  select 1 from public.audit_events
  where metadata ?| array['current_task','response_text','revision_instructions','file_contents','storage_path']
),'audit metadata contains no sensitive payload fields');

select * from finish();
rollback;

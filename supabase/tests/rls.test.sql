begin;

-- Updated after all assertions are written. Keeping an explicit plan makes CI
-- fail if a future edit silently drops an adversarial case.
select plan(207);

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
  ('b0000000-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','admin-b@example.test','10000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000008','Admin B','admin',true,'{}','{"new_matching_jobs":true}',now());

insert into public.models(id, organization_id, provider, display_name, active, sort_order) values
  ('d0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','Test','A preferred',true,1),
  ('d0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','Test','A acceptable',true,2),
  ('d0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','Test','A inactive',false,3),
  ('d0000000-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001','Test','B preferred',true,1);

insert into public.jobs(
  id, organization_id, created_by_membership_id, parent_job_id, status, title,
  listing_summary, visibility, sensitivity, sensitivity_notes, effort,
  required_tools, assigned_to_membership_id, claimed_at, claim_expires_at,
  data_handling_acknowledged_at, acknowledgement_version, published_at
) values
  ('c0000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Complete draft','Draft summary','claimed_only','unpublished','draft sensitivity','quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',null),
  ('c0000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'open','Lab-visible job','Safe lab summary','lab','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'open','Sealed open job','Safe sealed listing','claimed_only','unpublished','sealed notes','medium','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Current sealed claim','Safe current listing','claimed_only','unpublished','parent secret note','medium','{"Code execution"}','a0000000-0000-0000-0000-000000000003',now(),now()+interval '4 hours',now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Expired sealed claim','Safe expired listing','claimed_only','unpublished','expired secret','medium','{}','a0000000-0000-0000-0000-000000000003',now()-interval '8 hours',now()-interval '4 hours',now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000006','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'submitted','Historical job','Safe historical listing','claimed_only','unpublished','historical secret','heavy','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000007','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'claimed','Deactivate claimant','Safe deactivate listing','claimed_only','unpublished','deactivation secret','medium','{}','a0000000-0000-0000-0000-000000000007',now(),now()+interval '4 hours',now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000008','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'cancelled','Delete this job','Safe deletion listing','claimed_only','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000009','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'cancelled','Parent with child','Cannot delete first','claimed_only','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000010','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000009','draft','Child draft','Child listing','claimed_only','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',null),
  ('c0000000-0000-0000-0000-000000000011','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Upload draft','Upload listing','lab','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',null),
  ('c0000000-0000-0000-0000-000000000012','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Pending upload draft','Pending listing','claimed_only','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',null),
  ('c0000000-0000-0000-0000-000000000013','bbbbbbbb-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001',null,'open','Organization B job','B safe listing','claimed_only','unpublished','B secret','medium','{}',null,null,null,now(),'brainswap-data-boundary-v1',now()),
  ('c0000000-0000-0000-0000-000000000014','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'draft','Limit draft','Limit listing','claimed_only','general',null,'quick','{}',null,null,null,now(),'brainswap-data-boundary-v1',null),
  ('c0000000-0000-0000-0000-000000000015','aaaaaaaa-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002',null,'revision_requested','Expired revision claim','Safe revision listing','claimed_only','unpublished','revision secret','medium','{}','a0000000-0000-0000-0000-000000000003',now()-interval '8 hours',now()-interval '4 hours',now(),'brainswap-data-boundary-v1',now());

insert into public.job_payloads(job_id, current_task, success_criteria, output_format)
select j.id, 'protected task for ' || j.id::text, 'done when verified', 'plain text'
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
  ('ca000000-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000004','external_link','Protected link',null,'https://example.test/private-link',0);

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
    'title','Valid draft', 'listing_summary','Safe listing summary',
    'current_task','Perform the exact next task',
    'success_criteria','Return a verified result', 'output_format','Plain text',
    'visibility','claimed_only', 'sensitivity','general',
    'sensitivity_notes','', 'effort','quick',
    'deadline',to_char(now() + interval '1 day','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'required_tools',jsonb_build_array('Code execution'), 'acknowledged',true,
    'preferred_model_id','d0000000-0000-0000-0000-000000000001',
    'acceptable_model_ids',jsonb_build_array('d0000000-0000-0000-0000-000000000002'),
    'contexts',jsonb_build_array(
      jsonb_build_object('kind','inline_text','label','Context','text_content','Trusted only as text'),
      jsonb_build_object('kind','external_link','label','Link','url','https://example.test/resource')
    )
  )
$$;

-- Schema, privilege, and fail-closed structure.
select has_table('public','jobs','jobs exists');
select has_function('public','update_draft_job',array['uuid','jsonb'],'draft updates use an RPC');
select has_function('public','admin_update_membership',array['uuid','uuid','member_role','boolean'],'admin membership lifecycle uses an RPC');
select has_function('public','file_cleanup_info',array['uuid','text'],'file cleanup path is explicit');
select has_function('storage','allow_any_operation',array['text[]'],'Storage supports operation-aware RLS');
select ok((select count(*)=14 and bool_and(c.relrowsecurity)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname=any(array[
    'organizations','memberships','models','member_models','jobs','job_payloads',
    'job_models','job_context_items','job_files','submissions','submission_files',
    'revision_requests','notifications','audit_events'
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
select ok(not exists(
  select 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  left join pg_roles grantee on grantee.oid = acl.grantee
  where n.nspname = 'public'
    and p.proname = any(array[
      'claim_available_memberships','my_active_memberships','create_draft_job',
      'update_draft_job','publish_job','claim_job','release_job','extend_claim',
      'create_submission_draft','submit_result','request_revision','accept_job',
      'cancel_job','reopen_job','mark_notification_read','dashboard_jobs',
      'job_workspace','update_profile','admin_upsert_membership',
      'admin_update_membership','admin_memberships','create_follow_up_draft',
      'reserve_job_file','finalize_job_file','reserve_submission_file',
      'finalize_submission_file','file_download_info','file_cleanup_info',
      'delete_file_record','begin_job_deletion','delete_job_after_storage_cleanup'
    ])
    and acl.privilege_type = 'EXECUTE'
    and (acl.grantee = 0 or grantee.rolname = 'anon')
), 'no application RPC overload is executable by PUBLIC or anon');
select ok(
  not exists(
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.submit_result(uuid,text,text,text)')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  )
  and not exists(
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.update_profile(text,text[],uuid[],jsonb)')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ), 'authenticated cannot execute stale broad RPC overloads');
select ok(
  (select count(*)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'private'
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')) = 11
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
           to_regprocedure('private.can_storage_delete(text)')
         ])) = 11
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
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000002'),1::bigint,'active member can read published lab-visible payload');
select is((select count(job_id) from public.job_models where job_id='c0000000-0000-0000-0000-000000000002'),1::bigint,'active member can read published lab-visible model requirements');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000003'),0::bigint,'unrelated member cannot read sealed payload before claim');
select is((select count(id) from public.job_context_items where job_id='c0000000-0000-0000-0000-000000000003'),0::bigint,'unrelated member cannot read sealed context before claim');
select is(public.job_workspace('c0000000-0000-0000-0000-000000000003')->'payload','null'::jsonb,'sealed workspace omits protected payload before claim');
select is((select count(id) from public.jobs where id='c0000000-0000-0000-0000-000000000011'),0::bigint,'unrelated member cannot see a lab-visible draft listing');
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000011'),0::bigint,'lab visibility never publishes a draft payload');
select is((select count(id) from public.job_files where job_id='c0000000-0000-0000-0000-000000000011'),0::bigint,'lab visibility never exposes draft file metadata');
select ok(not private.can_storage_download('aaaaaaaa-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000011/job/33333333-3333-3333-3333-333333333333'),'lab-visible draft object is not downloadable by unrelated member');
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
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"acknowledged":1}'::jsonb)$$,
  'invalid acknowledgement or preferred model', 'direct RPC requires a JSON boolean acknowledgement'
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
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://user:password@evil.test/file"}]'))$$,
  'invalid external context', 'direct RPC rejects credential-bearing URLs'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://:"}]'))$$,
  'invalid external context', 'direct RPC rejects malformed HTTPS authority'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://[::::]/"}]'))$$,
  'invalid external context', 'direct RPC rejects malformed bracketed authorities'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://bad_host.example/path"}]'))$$,
  'invalid external context', 'direct RPC rejects unsupported hostname characters'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://999.1.1.1/path"}]'))$$,
  'invalid external context', 'direct RPC rejects invalid dotted-numeric host octets'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"external_link","label":"bad","url":"https://example.test:999999999999999999999/path"}]'))$$,
  'invalid external context', 'direct RPC rejects oversized ports without integer overflow'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{contexts}','[{"kind":"inline_text","label":"one","text_content":"a"},{"kind":"inline_text","label":"two","text_content":"b"}]'))$$,
  'invalid contexts', 'direct RPC enforces one aggregate inline context'
);
select throws_ok(
  $$select public.create_draft_job(
    'aaaaaaaa-0000-0000-0000-000000000001',
    jsonb_set(pg_temp.valid_draft_input(),'{contexts}',(
      select jsonb_agg(jsonb_build_object('kind','external_link','label','link '||n,'url','https://example.test/'||n))
      from generate_series(1,11) n
    ))
  )$$,
  'invalid contexts', 'direct RPC caps external/shared links at ten'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"current_task":"   "}'::jsonb)$$,
  'invalid draft text', 'direct RPC rejects whitespace-only task text'
);
select throws_ok(
  $$select public.create_draft_job('aaaaaaaa-0000-0000-0000-000000000001',pg_temp.valid_draft_input() || '{"preferred_model_id":"d0000000-0000-0000-0000-000000000004","acceptable_model_ids":[]}'::jsonb)$$,
  'models must be active organization models', 'direct RPC rejects a model from another organization'
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
  $$select public.update_draft_job('c0000000-0000-0000-0000-000000000001',jsonb_set(pg_temp.valid_draft_input(),'{current_task}',to_jsonb(E'  Preserve prompt formatting\n'::text)))$$,
  'requester can update a complete draft through the authoritative RPC'
);
reset role;
select is((select current_task from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000001'),E'  Preserve prompt formatting\n','draft RPC preserves significant prompt whitespace');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select throws_ok(
  $$select public.publish_job('c0000000-0000-0000-0000-000000000001')$$,
  'not authorized', 'nonrequester cannot publish a draft'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.publish_job('c0000000-0000-0000-0000-000000000001')$$,'requester can publish a complete draft');
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000001'),'open'::public.job_status,'publication performs draft to open transition');
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
select is((select count(id) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'claimant sees only its own current draft submission');
select lives_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'current claimant can resolve its own ready draft attachment'
);
select is((select count(job_id) from public.job_payloads where job_id='c0000000-0000-0000-0000-000000000005'),0::bigint,'expired claimant loses sealed payload access');
select throws_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000005','Model','late result','',array[]::text[])$$,
  'claim expired', 'expired claimant cannot submit'
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
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model','first finalized response','',array['Shell'])$$,
  'result incomplete', 'submission tools are validated at the database boundary'
);
select lives_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model',E'  first finalized response\n','notes',array['Code execution'])$$,
  'current claimant can submit a complete result'
);
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'submitted'::public.job_status,'submission advances job state');
select is((select count(*) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004' and status='submitted'),1::bigint,'first finalized submission is retained');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select throws_ok($$select public.request_revision('c0000000-0000-0000-0000-000000000004','Unauthorized revision request.')$$,'not allowed','nonrequester cannot request a revision');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000004')$$,'requester may reopen a submitted job');
reset role;
select is((select status from public.jobs where id='c0000000-0000-0000-0000-000000000004'),'open'::public.job_status,'submitted reopen returns job to an unassigned open state');
update public.jobs set status='submitted' where id='c0000000-0000-0000-0000-000000000004';

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select is((select count(id) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004'),1::bigint,'requester sees submitted result after finalization');
select lives_ok(
  $$select * from public.file_download_info('fa000000-0000-0000-0000-000000000001','submission')$$,
  'requester can resolve attachment only after parent submission is finalized'
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
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Model','unauthorized','',array[]::text[])$$,
  'claim expired', 'unassigned member cannot submit a revision'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select lives_ok(
  $$select public.submit_result('c0000000-0000-0000-0000-000000000004','Test model','second finalized response','',array[]::text[])$$,
  'revision claimant can submit a new immutable revision'
);
select throws_ok($$select public.accept_job('c0000000-0000-0000-0000-000000000004')$$,'not allowed','helper cannot accept its own result');
reset role;
select is((select count(*) from public.submissions where job_id='c0000000-0000-0000-0000-000000000004' and status='submitted'),2::bigint,'submission history keeps both revisions');
select is((select response_text from public.submissions where id='e0000000-0000-0000-0000-000000000001'),E'  first finalized response\n','submitted model response preserves significant whitespace and remains immutable');
select is((select count(*) from public.revision_requests where job_id='c0000000-0000-0000-0000-000000000004' and resolved_at is not null),1::bigint,'new submission resolves the open revision request');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.accept_job('c0000000-0000-0000-0000-000000000004')$$,'requester can accept latest submitted revision');
select throws_ok($$select public.reopen_job('c0000000-0000-0000-0000-000000000004')$$,'not allowed','accepted job is terminal');
select lives_ok($$select public.create_follow_up_draft('c0000000-0000-0000-0000-000000000004')$$,'requester can create follow-up from finalized result');
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
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000008';
select lives_ok(
  $$select public.admin_upsert_membership('bbbbbbbb-0000-0000-0000-000000000001','unclaimed-admin@example.test','admin')$$,
  'admin may create an unclaimed admin invitation'
);
select throws_ok(
  $$select public.admin_update_membership('bbbbbbbb-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','member',true)$$,
  'cannot remove the last active administrator', 'unclaimed admin invitation does not satisfy last-admin guard'
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
  $$select public.update_profile('aaaaaaaa-0000-0000-0000-000000000001','Admin A',array['Shell'],array[]::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile', 'profile capabilities use the fixed server-side catalog'
);
select throws_ok(
  $$select public.update_profile('aaaaaaaa-0000-0000-0000-000000000001','Admin A',array[]::text[],array['d0000000-0000-0000-0000-000000000004']::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile models', 'profile cannot select another organization model'
);
select throws_ok(
  $$select public.update_profile('bbbbbbbb-0000-0000-0000-000000000001','Forged org',array[]::text[],array['d0000000-0000-0000-0000-000000000004']::uuid[],'{"new_matching_jobs":true}')$$,
  'invalid profile', 'organization parameter cannot forge selected membership'
);
select lives_ok(
  $$select public.update_profile('aaaaaaaa-0000-0000-0000-000000000001','Admin A updated',array['Code execution'],array['d0000000-0000-0000-0000-000000000001']::uuid[],'{"new_matching_jobs":false}')$$,
  'valid profile update is selected-organization scoped'
);
reset role;
select ok((select status='open' and assigned_to_membership_id is null and claim_expires_at is null from public.jobs where id='c0000000-0000-0000-0000-000000000007'),'deactivation immediately releases active claim');
select is((select display_name from public.memberships where id='a0000000-0000-0000-0000-000000000001'),'Admin A updated','profile update changes only selected membership');

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

begin;

select plan(27);

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values
  ('00000000-0000-0000-0000-000000000000','71000000-0000-0000-0000-000000000001','authenticated','authenticated','deletion-admin@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','71000000-0000-0000-0000-000000000002','authenticated','authenticated','delete-me@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','71000000-0000-0000-0000-000000000003','authenticated','authenticated','solo-admin@example.test','',now(),'{}','{}',now(),now(),'','','',''),
  ('00000000-0000-0000-0000-000000000000','71000000-0000-0000-0000-000000000004','authenticated','authenticated','outsider@example.test','',now(),'{}','{}',now(),now(),'','','','');

insert into public.organizations(id, name, slug) values
  ('7a000000-0000-0000-0000-000000000001','Deletion organization','deletion-organization'),
  ('7b000000-0000-0000-0000-000000000001','Second deletion organization','second-deletion-organization'),
  ('7c000000-0000-0000-0000-000000000001','Solo administrator organization','solo-administrator-organization');

insert into public.memberships(
  id, organization_id, invited_email, user_id, claimed_user_id, display_name,
  role, active, capabilities, notification_preferences, claimed_at
) values
  ('7d000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001','deletion-admin@example.test','71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','Deletion admin','admin',true,'{}','{"new_matching_jobs":true}',now()),
  ('7d000000-0000-0000-0000-000000000002','7a000000-0000-0000-0000-000000000001','delete-me@example.test','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','Delete me','member',true,'{}','{"new_matching_jobs":true}',now()),
  ('7d000000-0000-0000-0000-000000000003','7b000000-0000-0000-0000-000000000001','deletion-admin@example.test','71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','Deletion admin','admin',true,'{}','{"new_matching_jobs":true}',now()),
  ('7d000000-0000-0000-0000-000000000004','7b000000-0000-0000-0000-000000000001','delete-me@example.test',null,null,null,'member',true,'{}','{"new_matching_jobs":true}',null),
  ('7d000000-0000-0000-0000-000000000005','7c000000-0000-0000-0000-000000000001','solo-admin@example.test','71000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000003','Solo admin','admin',true,'{}','{"new_matching_jobs":true}',now());

insert into public.jobs(
  id, organization_id, created_by_membership_id, status, title, listing_summary,
  visibility, sensitivity, effort, required_tools, assigned_to_membership_id,
  claimed_at, claim_expires_at, published_at, preferred_model_text,
  acceptable_models_text, data_handling_acknowledged_at, acknowledgement_version
) values
  ('7e000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001','7d000000-0000-0000-0000-000000000002','draft','Private draft','Private draft summary','claimed_only','general','medium','{}',null,null,null,null,'GPT-6 Astra','Any frontier model',now(),'brainswap-default-public-sharing-v1'),
  ('7e000000-0000-0000-0000-000000000002','7a000000-0000-0000-0000-000000000001','7d000000-0000-0000-0000-000000000002','open','Published request','Published summary','claimed_only','general','medium','{}',null,null,null,now(),'GPT-6 Astra','Any frontier model',now(),'brainswap-default-public-sharing-v1'),
  ('7e000000-0000-0000-0000-000000000003','7a000000-0000-0000-0000-000000000001','7d000000-0000-0000-0000-000000000001','claimed','Claimed work','Claimed summary','claimed_only','general','medium','{}','7d000000-0000-0000-0000-000000000002',now(),now()+interval '4 hours',now(),'GPT-6 Astra','Any frontier model',now(),'brainswap-default-public-sharing-v1');

insert into public.job_payloads(job_id, current_task, success_criteria, output_format, prompt)
select id, 'legacy task', 'done', 'text', 'complete this task'
from public.jobs where id::text like '7e000000-%';

insert into public.job_files(
  id, job_id, organization_id, uploaded_by_membership_id, storage_path,
  original_filename, safe_filename, mime_type, size_bytes, upload_status, ready_at
) values (
  '7f000000-0000-0000-0000-000000000001','7e000000-0000-0000-0000-000000000001',
  '7a000000-0000-0000-0000-000000000001','7d000000-0000-0000-0000-000000000002',
  '7a000000-0000-0000-0000-000000000001/7e000000-0000-0000-0000-000000000001/job/71000000-0000-0000-0000-000000000001',
  'materials.zip','materials.zip','application/zip',4,'ready',now()
);

insert into public.profile_photos(
  id, organization_id, membership_id, storage_path, original_filename,
  safe_filename, mime_type, size_bytes, upload_status, ready_at
) values (
  '72000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001',
  '7d000000-0000-0000-0000-000000000002',
  '7a000000-0000-0000-0000-000000000001/7d000000-0000-0000-0000-000000000002/71000000-0000-0000-0000-000000000002',
  'portrait.png','portrait.png','image/png',4,'ready',now()
);

insert into storage.objects(bucket_id, name, owner_id, metadata) values
  ('job-files','7a000000-0000-0000-0000-000000000001/7e000000-0000-0000-0000-000000000001/job/71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','{"size":4,"mimetype":"application/zip"}'),
  ('profile-photos','7a000000-0000-0000-0000-000000000001/7d000000-0000-0000-0000-000000000002/71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','{"size":4,"mimetype":"image/png"}');

select has_function('public','begin_account_deletion',array[]::text[],'account deletion has a Storage-first manifest RPC');
select has_function('public','delete_own_account',array[]::text[],'account deletion has a caller-bound finalization RPC');

set local role anon;
select throws_ok(
  $$select * from public.begin_account_deletion()$$,
  '42501', null, 'anonymous callers cannot start account deletion'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000003';
select throws_ok(
  $$select * from public.begin_account_deletion()$$,
  'transfer administrator role before deleting account',
  'the last usable administrator cannot delete their account'
);
reset role;
select ok(
  (select account_deletion_started_at is null from public.memberships where id='7d000000-0000-0000-0000-000000000005'),
  'a blocked last-administrator deletion leaves the account unchanged'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000002';
select is(
  (select count(*) from public.begin_account_deletion()),
  2::bigint,
  'deletion manifest returns every exact stored object once'
);
select ok(private.account_deletion_started(),'the caller-bound deletion marker is active');
select throws_ok(
  $$select public.update_profile(
    '7a000000-0000-0000-0000-000000000001','Delete me','',array[]::uuid[],
    '{"new_matching_jobs":false}'::jsonb
  )$$,
  'invalid profile',
  'ordinary profile mutations freeze after the deletion manifest starts'
);
select ok(
  private.can_delete_account_storage_object(
    'job-files',
    '7a000000-0000-0000-0000-000000000001/7e000000-0000-0000-0000-000000000001/job/71000000-0000-0000-0000-000000000001'
  ),
  'deletion authorizes the caller exact job-file path'
);
select ok(
  private.can_delete_account_storage_object(
    'profile-photos',
    '7a000000-0000-0000-0000-000000000001/7d000000-0000-0000-0000-000000000002/71000000-0000-0000-0000-000000000002'
  ),
  'deletion authorizes the caller exact profile-photo path'
);
select throws_ok(
  $$select public.delete_own_account()$$,
  'storage cleanup required',
  'Auth deletion refuses to orphan Storage objects'
);
reset role;

select is(
  (select count(*) from auth.users where id='71000000-0000-0000-0000-000000000002'),
  1::bigint,
  'failed Storage cleanup leaves the Auth identity intact for a safe retry'
);

set local "storage.allow_delete_query" = 'true';
delete from storage.objects where owner_id='71000000-0000-0000-0000-000000000002';

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000002';
select lives_ok(
  $$select public.delete_own_account()$$,
  'account finalization succeeds only after exact Storage cleanup'
);
reset role;

select is((select count(*) from auth.users where id='71000000-0000-0000-0000-000000000002'),0::bigint,'Auth identity is deleted');
select ok(
  (select deleted_at is not null and not active and user_id is null and claimed_user_id is null
   from public.memberships where id='7d000000-0000-0000-0000-000000000002'),
  'retained shared-history membership is inactive and detached from Auth'
);
select is(
  (select display_name from public.memberships where id='7d000000-0000-0000-0000-000000000002'),
  'Deleted user',
  'retained shared history uses the anonymous display name'
);
select is(
  (select count(*) from public.memberships where deleted_at is not null and invited_email like 'deleted+%@deleted.invalid'),
  2::bigint,
  'claimed membership and same-email unclaimed invitation are both tombstoned'
);
select is((select count(*) from public.profile_photos where membership_id='7d000000-0000-0000-0000-000000000002'),0::bigint,'profile-photo metadata is removed');
select is((select count(*) from public.job_files where uploaded_by_membership_id='7d000000-0000-0000-0000-000000000002'),0::bigint,'uploaded-file metadata is removed');
select is((select count(*) from public.jobs where id='7e000000-0000-0000-0000-000000000001'),0::bigint,'private draft is deleted');
select is((select status from public.jobs where id='7e000000-0000-0000-0000-000000000002'),'cancelled'::public.job_status,'published requester work is cancelled');
select ok(
  (select status='open' and assigned_to_membership_id is null and claim_expires_at is null
   from public.jobs where id='7e000000-0000-0000-0000-000000000003'),
  'claimed work is released for another helper'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000001';
select is(
  (select count(*) from public.admin_memberships('7a000000-0000-0000-0000-000000000001') where id='7d000000-0000-0000-0000-000000000002'),
  0::bigint,
  'deleted memberships no longer clutter the administration dashboard'
);
reset role;

select ok(
  not exists (
    select 1 from public.audit_events
    where event_type in ('account_deletion_started','account_deleted')
      and metadata ?| array['email','invited_email','storage_path']
  ),
  'account-deletion audit rows contain no email or file path'
);

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000','71000000-0000-0000-0000-000000000005',
  'authenticated','authenticated','delete-me@example.test','',now(),'{}','{}',now(),now(),'','','',''
);

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000005';
select is(
  (select count(*) from public.claim_available_memberships()),
  0::bigint,
  'a new Auth identity reusing the deleted email cannot reclaim old invitations'
);
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '71000000-0000-0000-0000-000000000004';
select throws_ok(
  $$select * from public.begin_account_deletion()$$,
  'active membership required',
  'an uninvited caller cannot start an account-deletion manifest'
);
select throws_ok(
  $$select public.delete_own_account()$$,
  'account deletion has not started',
  'an unrelated caller cannot skip the manifest phase'
);
reset role;

select * from finish();
rollback;

begin; select plan(8);
select has_table('public','jobs','jobs exists'); select has_function('public','claim_job',array['uuid'],'claim is atomic RPC');
select ok((select relrowsecurity from pg_class where oid='public.jobs'::regclass),'jobs RLS enabled');
select ok((select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array['organizations','memberships','models','member_models','jobs','job_payloads','job_models','job_context_items','job_files','submissions','submission_files','revision_requests','notifications','audit_events'])),'all exposed application tables use RLS');
select throws_ok($$select public.claim_available_memberships()$$,'authentication required','anonymous cannot claim');
select ok(not has_table_privilege('anon','public.jobs','SELECT'),'anonymous lacks job grant');
select ok(not has_table_privilege('authenticated','public.jobs','UPDATE'),'direct workflow updates denied');
select ok(not has_table_privilege('authenticated','public.memberships','UPDATE'),'membership edits denied');
select * from finish(); rollback;

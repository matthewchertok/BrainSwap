-- Run after replacing all three obvious placeholders. Safe to run repeatedly.
do $$declare org uuid;begin
 insert into public.organizations(name,slug) values('REPLACE_WITH_ORGANIZATION_NAME','replace-with-organization-slug') on conflict(slug) do update set name=excluded.name returning id into org;
 insert into public.memberships(organization_id,invited_email,display_name,role) values(org,'replace-with-admin@example.invalid','REPLACE_WITH_ADMIN_DISPLAY_NAME','admin') on conflict(organization_id,invited_email) do update set role='admin',active=true;
 insert into public.models(organization_id,provider,display_name,sort_order) values
 (org,'OpenAI','ChatGPT, best available reasoning model',10),(org,'Anthropic','Claude Opus',20),(org,'Anthropic','Claude Sonnet',30),(org,'Google','Gemini Pro',40),(org,'Any','Any capable frontier model',50),(org,'Local','Local or open model',60),(org,'Other','Other',70)
 on conflict(organization_id,(lower(trim(display_name)))) do nothing;
end$$;

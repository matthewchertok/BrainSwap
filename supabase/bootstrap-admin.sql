-- Run after replacing all four obvious placeholders. Safe to run repeatedly.
do $$declare org uuid;begin
 if 'REPLACE_WITH_ORGANIZATION_NAME' like 'REPLACE_WITH_%'
    or 'replace-with-organization-slug' like 'replace-with-%'
    or 'replace-with-admin@example.invalid' like '%@example.invalid'
    or 'REPLACE_WITH_ADMIN_DISPLAY_NAME' like 'REPLACE_WITH_%' then
   raise exception 'replace every bootstrap placeholder before running this script';
 end if;
 insert into public.organizations(name,slug) values('REPLACE_WITH_ORGANIZATION_NAME','replace-with-organization-slug') on conflict(slug) do update set name=excluded.name returning id into org;
 insert into public.memberships(organization_id,invited_email,display_name,role) values(org,'replace-with-admin@example.invalid','REPLACE_WITH_ADMIN_DISPLAY_NAME','admin') on conflict(organization_id,invited_email) do update set role='admin',active=true;
 insert into public.models(organization_id,provider,display_name,sort_order) values
 (org,'OpenAI','GPT-6 Astra',10),
 (org,'OpenAI','GPT-5.6 Sol',20),
 (org,'OpenAI','GPT-5.6 Terra',30),
 (org,'OpenAI','GPT-5.6 Luna',40),
 (org,'Anthropic','Claude Fable 5.1',50),
 (org,'Anthropic','Claude Opus 5',60),
 (org,'Google','Gemini Pro',70),
 (org,'xAI','SuperGrok',80)
 on conflict(organization_id,(lower(trim(display_name)))) do update
 set provider=excluded.provider,active=true,sort_order=excluded.sort_order,updated_at=now();
end$$;

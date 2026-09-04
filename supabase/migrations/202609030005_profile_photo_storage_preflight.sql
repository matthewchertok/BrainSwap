-- Supabase Storage authorizes an upload before writing the final object row.
-- The preflight `contentLength` is the entire multipart request, including its
-- form boundaries, rather than the file size. It therefore must not be compared
-- with the reservation. Authorize only the exact owner/path/state and MIME here,
-- rely on the private bucket's 5 MiB file limit during upload, then let
-- finalize_profile_photo verify the completed object's actual `size` and
-- `mimetype` before the object becomes readable.
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
    and coalesce(p_metadata ->> 'mimetype', '') = p.mime_type;
end
$$;

revoke all on function private.can_profile_photo_storage_upload(text, jsonb)
  from public, anon, authenticated;
grant execute on function private.can_profile_photo_storage_upload(text, jsonb)
  to authenticated;

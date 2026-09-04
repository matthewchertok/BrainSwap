<script lang="ts">
  import { invalidateAll } from '$app/navigation';
  import { onMount } from 'svelte';
  import { downloadProfilePhotoUrl } from '$lib/storage';
  import { getBrowserSupabase } from '$lib/supabase-browser';

  let { data, form } = $props();
  let photoUrl = $state('');
  let photoMessage = $state('');
  let photoBusy = $state(false);
  let accountConfirmation = $state('');
  let accountDeletionReady = $derived(accountConfirmation.trim().toLowerCase() === data.accountEmail);

  onMount(() => {
    void loadPhoto();
    return () => {
      if (photoUrl) URL.revokeObjectURL(photoUrl);
    };
  });

  async function loadPhoto() {
    if (!data.photo || data.photo.upload_status !== 'ready' || data.photo.cleanup_started_at) return;
    try {
      const client = getBrowserSupabase();
      const { data: rows, error } = await client.rpc('profile_photo_download_info', {
        p_membership_id: data.membershipId
      });
      const info = Array.isArray(rows) ? rows[0] : rows;
      if (error || !info?.storage_path) throw new Error('The profile photo is not available.');
      const nextUrl = await downloadProfilePhotoUrl(client, info.storage_path);
      if (photoUrl) URL.revokeObjectURL(photoUrl);
      photoUrl = nextUrl;
    } catch (photoError) {
      photoMessage = photoError instanceof Error ? photoError.message : 'The profile photo could not be loaded.';
    }
  }

  async function cleanupPhoto(photoId: string, confirmFirst = true) {
    if (confirmFirst && !window.confirm('Remove this profile photo?')) return false;
    const client = getBrowserSupabase();
    const { data: rows, error: infoError } = await client.rpc('profile_photo_cleanup_info', {
      p_photo_id: photoId
    });
    const info = Array.isArray(rows) ? rows[0] : rows;
    if (infoError || !info?.storage_path) throw new Error('Profile photo cleanup could not start.');
    const { error: storageError } = await client.storage.from('profile-photos').remove([info.storage_path]);
    if (storageError) throw new Error('The stored profile photo could not be removed.');
    const { error: recordError } = await client.rpc('delete_profile_photo_record', { p_photo_id: photoId });
    if (recordError) throw new Error('Profile photo cleanup is incomplete; it is safe to retry.');
    if (photoUrl) URL.revokeObjectURL(photoUrl);
    photoUrl = '';
    return true;
  }

  async function removePhoto() {
    if (!data.photo) return;
    photoBusy = true;
    photoMessage = '';
    try {
      if (!(await cleanupPhoto(data.photo.id))) return;
      photoMessage = 'Profile photo removed.';
      await invalidateAll();
    } catch (photoError) {
      photoMessage = photoError instanceof Error ? photoError.message : 'The profile photo could not be removed.';
    } finally {
      photoBusy = false;
    }
  }

  function uploadPhoto(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    photoMessage = `Uploading ${file.name}…`;
    input.form?.requestSubmit();
  }
</script>

<h1>Profile</h1>
{#if form?.message}<p class="notice">{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
{#if photoMessage}<p class="notice" role="status">{photoMessage}</p>{/if}

<section class="panel profile-photo-panel">
  <div class="profile-photo-preview">
    {#if photoUrl}<img src={photoUrl} alt="Your profile" />{:else}<span aria-hidden="true"
        >{(data.profile.display_name ?? '?').slice(0, 1).toUpperCase()}</span
      >{/if}
  </div>
  <div>
    <h2>Profile photo</h2>
    <p>JPEG, PNG, or WebP. Maximum 5 MiB.</p>
    <div class="profile-photo-actions">
      {#if data.photo}<button type="button" class="secondary" disabled={photoBusy} onclick={removePhoto}
          >Remove photo</button
        >{:else}<form method="POST" action="?/upload_photo" enctype="multipart/form-data">
          <label class="button file-button">
            Upload photo
            <input type="file" name="photo" accept="image/jpeg,image/png,image/webp" required onchange={uploadPhoto} />
          </label>
        </form>{/if}
    </div>
  </div>
</section>

<form method="POST" action="?/save" class="panel profile-form">
  <label
    >Display name<input name="display_name" value={data.profile.display_name ?? ''} maxlength="120" required /></label
  >
  <label>Bio<textarea name="bio" rows="5" maxlength="2000">{data.profile.bio ?? ''}</textarea></label>
  <label
    >Organization<select disabled aria-describedby="organization-help"><option>{data.organizationName}</option></select
    ></label
  >
  <p id="organization-help" class="field-help">Your organization comes from your active BrainSwap membership.</p>
  <fieldset>
    <legend>Models I can access</legend>{#each data.models as model}<label
        ><input
          type="checkbox"
          name="model_ids"
          value={model.id}
          checked={data.selected.includes(model.id)}
        />{model.display_name}</label
      >{/each}
  </fieldset>
  <label
    ><input
      type="checkbox"
      name="notify"
      value="yes"
      checked={data.profile.notification_preferences?.new_matching_jobs ?? true}
    />Notify me in BrainSwap about new jobs in this organization</label
  >
  <button>Save profile</button>
</form>

<section class="panel account-danger-zone">
  <h2>Delete account</h2>
  <p>
    This permanently deletes your sign-in, profile, memberships, invitations, and uploaded files. Shared job and result
    history may remain under “Deleted user.” Open jobs you posted will be cancelled, and work you claimed will be
    released.
  </p>
  <p>You cannot delete your account while you are an organization’s last active administrator.</p>
  <form method="POST" action="?/delete_account">
    <label>
      Type <strong>{data.accountEmail}</strong> to confirm
      <input
        name="confirmation"
        autocomplete="off"
        autocapitalize="none"
        spellcheck="false"
        bind:value={accountConfirmation}
        required
      />
    </label>
    {#if form?.deleteError}<p class="error" role="alert">{form.deleteError}</p>{/if}
    <button class="danger-button" disabled={!accountDeletionReady}>Delete my account</button>
  </form>
</section>

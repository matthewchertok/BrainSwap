<script lang="ts">
  import { approvalEmailHref } from '$lib/ui';

  let { data, form } = $props();
</script>

<h1>Administration</h1>
<p class="notice">
  Invitations must match the person's Google account email. Adding one grants eligibility but does not send an email
  automatically. The last active administrator cannot be demoted or deactivated.
</p>
{#if form?.message}<p>{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
<form method="POST" action="?/invite" class="panel">
  <h2>Add invitation</h2>
  <label>Email<input type="email" name="email" required /></label><label
    >Role<select name="role"><option value="member">Member</option><option value="admin">Administrator</option></select
    ></label
  ><button>Add invitation</button>
</form>
<section>
  <h2>Members</h2>
  <div class="cards">
    {#each data.members as m}<article class="card">
        <strong>{m.display_name ?? 'Unclaimed invitation'}</strong>
        <p>{m.invited_email} · {m.claimed ? 'Claimed' : 'Unclaimed'}</p>
        <form method="POST" action="?/membership">
          <input type="hidden" name="membership_id" value={m.id} />
          <label
            >Role<select name="role">
              <option value="member" selected={m.role === 'member'}>Member</option>
              <option value="admin" selected={m.role === 'admin'}>Administrator</option>
            </select></label
          >
          <label><input type="checkbox" name="active" value="yes" checked={m.active} /> Active</label>
          <button>Save membership</button>
        </form>
        {#if !m.claimed}
          <div class="admin-invitation-actions">
            {#if m.active}<a
                class="button secondary"
                href={approvalEmailHref(m.invited_email)}
                aria-label={`Email access approval to ${m.invited_email}`}>Email approval</a
              >{/if}
            <form method="POST" action="?/delete_invitation">
              <input type="hidden" name="membership_id" value={m.id} />
              <button class="danger-button">Remove invitation</button>
            </form>
          </div>
        {/if}
      </article>{/each}
  </div>
</section>

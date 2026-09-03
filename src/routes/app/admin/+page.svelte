<script lang="ts">
  let { data, form } = $props();
</script>

<h1>Administration</h1>
<p class="notice">
  Invitations match an exact Google account email. Adding one grants eligibility but does not send an email. The last
  active administrator cannot be demoted or deactivated.
</p>
{#if form?.message}<p>{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
<form method="POST" action="?/invite" class="panel">
  <h2>Add invitation</h2>
  <label>Exact email<input type="email" name="email" required /></label><label
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
      </article>{/each}
  </div>
</section>
<section>
  <h2>Models</h2>
  <ul>
    {#each data.models as m}<li>{m.display_name} ({m.provider}) — {m.active ? 'active' : 'inactive'}</li>{/each}
  </ul>
</section>

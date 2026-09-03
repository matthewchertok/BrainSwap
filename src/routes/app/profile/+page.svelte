<script lang="ts">
  let { data, form } = $props();
  const caps = [
    'Web access',
    'Deep research',
    'Code execution',
    'Image understanding',
    'PDF understanding',
    'File generation'
  ];
</script>

<h1>Profile</h1>
{#if form?.message}<p class="notice">{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
<form method="POST" class="panel">
  <label
    >Display name<input name="display_name" value={data.profile.display_name ?? ''} maxlength="120" required /></label
  >
  <fieldset>
    <legend>Models I can access</legend>{#each data.models as m}<label
        ><input
          type="checkbox"
          name="model_ids"
          value={m.id}
          checked={data.selected.includes(m.id)}
        />{m.display_name}</label
      >{/each}
  </fieldset>
  <fieldset>
    <legend>Capabilities</legend>{#each caps as c}<label
        ><input
          type="checkbox"
          name="capabilities"
          value={c}
          checked={data.profile.capabilities.includes(c)}
        />{c}</label
      >{/each}
  </fieldset>
  <label
    ><input
      type="checkbox"
      name="notify"
      value="yes"
      checked={data.profile.notification_preferences?.new_matching_jobs ?? true}
    />Notify me about new jobs in this organization</label
  ><button>Save profile</button>
</form>

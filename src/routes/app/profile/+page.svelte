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
<form method="POST" class="panel">
  <label>Display name<input name="display_name" value={data.membership.display_name ?? ''} required /></label>
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
        ><input type="checkbox" name="capabilities" value={c} />{c}</label
      >{/each}
  </fieldset>
  <label><input type="checkbox" name="notify" value="yes" checked />Notify me about matching jobs</label><button
    >Save profile</button
  >
</form>

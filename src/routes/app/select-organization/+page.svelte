<script lang="ts">
  let { data, form } = $props();
</script>

<section class="panel">
  <h1>Select organization</h1>
  {#if form?.message}<p class="error">{form.message}</p>{/if}
  <form method="POST">
    <label
      >Organization<select name="organization_id"
        >{#each data.memberships as m}<option value={m.organization_id}>{m.organization_name}</option>{/each}</select
      ></label
    ><button>Continue</button>
  </form>
</section>

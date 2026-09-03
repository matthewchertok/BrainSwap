<script lang="ts">
  import { brand } from '$lib/config';
  let { form } = $props();
</script>

<main class="center">
  <section class="panel login">
    <p class="eyebrow">PRIVATE LAB WORKSPACE</p>
    <h1>{brand.name}</h1>
    <p class="tagline">{brand.tagline}</p>
    <ol>
      <li>Post the exact next task.</li>
      <li>An invited lab member runs it manually.</li>
      <li>Review the returned result.</li>
    </ol>
    <form method="POST"><button>Sign in with Google</button></form>
    {#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
    <p class="notice">
      <strong>Data boundary:</strong> Do not submit credentials, PHI, restricted human-subject data, or other Restricted /
      Highly Restricted information. Access requires an exact-email invitation.
    </p>
  </section>
</main>

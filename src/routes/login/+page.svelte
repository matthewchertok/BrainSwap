<script lang="ts">
  import { brand } from '$lib/config';
  let { data, form } = $props();
</script>

<main class="center">
  <section class="panel login">
    <p class="eyebrow">{brand.version}</p>
    <h1>{brand.name}</h1>
    <p class="tagline">{brand.tagline}</p>
    <ol>
      <li>Post the exact next task.</li>
      <li>An invited lab member runs it manually.</li>
      <li>Review the returned result.</li>
    </ol>
    <div class="login-actions">
      <form method="POST" action="?/signIn">
        <input type="hidden" name="next" value={data.next} />
        <button>Sign in with Google</button>
      </form>
      {#if data.accessRequestsEnabled}
        <form method="POST" action="?/requestAccess">
          <input type="hidden" name="next" value={data.next} />
          <button class="secondary">Request access</button>
        </form>
      {/if}
    </div>
    {#if data.accessRequestsEnabled}
      <p class="login-help">Access requests use Google to verify the exact email address you want invited.</p>
    {/if}
    {#if data.message}<p class="error" role="alert">{data.message}</p>{/if}
    {#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
    <p class="notice">
      <strong>Data boundary:</strong> Do not submit anything sensitive or anything you would not want someone else to see.
    </p>
  </section>
</main>

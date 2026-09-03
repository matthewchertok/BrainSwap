<script lang="ts">
  import { brand } from '$lib/config';
  let { data } = $props();
</script>

<main class="center">
  <section class="panel">
    {#if data.request === 'sent'}
      <h1>Request sent</h1>
      <p>
        The lab administrator will review your request. You will still need an exact-email invitation before you can
        sign in.
      </p>
    {:else if data.request === 'failed'}
      <h1>Request not sent</h1>
      <p>We could not send your access request. Please try again later or contact the lab administrator.</p>
    {:else}
      <h1>Access not authorized</h1>
      <p>
        Your Google account is not on the {brand.name} exact-email allowlist. An institutional domain alone does not qualify.
      </p>
      <p>Return to sign in if you want to request access with the exact Google account you plan to use.</p>
    {/if}
    <form method="POST" action="/auth/signout"><button class="secondary">Clear sign-in session</button></form>
    <a href="/login">Return to sign in</a>
  </section>
</main>

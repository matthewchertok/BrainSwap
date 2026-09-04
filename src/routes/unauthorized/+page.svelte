<script lang="ts">
  let { data, form } = $props();
</script>

<main class="center">
  <section class="panel">
    {#if data.request === 'sent'}
      <h1>Request sent</h1>
      <p class="notice" role="status">
        Access requested. An administrator will review your request and let you know if it is approved.
      </p>
    {:else if data.request === 'failed'}
      <h1>Request not sent</h1>
      <p class="error" role="alert">
        We could not send your access request. Please try again later or contact the administrator.
      </p>
    {:else}
      <h1>Access not authorized</h1>
      {#if data.canRequestAccess}
        <p>Your Google account is not yet on the approved users list. Click below to request access.</p>
      {:else}
        <p>Your Google account is not yet on the approved users list. Please contact an administrator.</p>
      {/if}
      {#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
    {/if}
    <div class="login-actions">
      {#if data.request === null && data.canRequestAccess}
        <form method="POST" action="?/requestAccess"><button>Request access</button></form>
      {/if}
      <form method="POST" action="/auth/signout"><button class="secondary">Return to sign in</button></form>
    </div>
  </section>
</main>

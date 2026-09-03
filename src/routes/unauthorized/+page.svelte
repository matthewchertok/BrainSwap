<script lang="ts">
  import { brand } from '$lib/config';
</script>

<main class="center">
  <section class="panel">
    <h1>Access not authorized</h1>
    <p>
      Your Google account is not on the {brand.name} exact-email allowlist. An institutional domain alone does not qualify.
    </p>
    <p>Contact your lab administrator and ask them to invite the exact address used for sign-in.</p>
    <form method="POST" action="/auth/signout"><button>Clear session</button></form>
    <a href="/login">Return to sign in</a>
  </section>
</main>

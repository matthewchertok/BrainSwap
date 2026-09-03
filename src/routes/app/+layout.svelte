<script lang="ts">
  import { brand } from '$lib/config';
  let { data, children } = $props();
</script>

<div class="warning">
  Not approved for Restricted or Highly Restricted information. Model output requires human verification.
</div>
<header>
  <a class="brand" href="/app">{brand.name}</a>
  <nav>
    <a href="/app">Jobs</a><a href="/app/notifications">Notifications</a><a href="/app/profile">Profile</a
    >{#if data.membership.role === 'admin'}<a href="/app/admin">Admin</a>{/if}
    <form method="POST" action="/auth/signout"><button class="link">Sign out</button></form>
  </nav>
</header>
<main class="shell">{@render children()}</main>

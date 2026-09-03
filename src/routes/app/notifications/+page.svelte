<script lang="ts">
  let { data } = $props();
</script>

<h1>Notifications</h1>
{#if !data.notifications.length}<section class="empty"><p>You have no notifications.</p></section>{:else}<ul
    class="notifications"
  >
    {#each data.notifications as n}<li class:unread={!n.read_at}>
        <span class="pill">{n.type.replaceAll('_', ' ')}</span>{#if n.job_id}<a href={'/app/jobs/' + n.job_id}
            >{n.message}</a
          >{:else}{n.message}{/if}<time>{new Date(n.created_at).toLocaleString()}</time>
      </li>{/each}
  </ul>{/if}

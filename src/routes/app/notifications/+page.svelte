<script lang="ts">
  import JobStatus from '$lib/components/JobStatus.svelte';
  import { notificationLabel, notificationStatus } from '$lib/ui';

  let { data, form } = $props();
</script>

<h1>Notifications</h1>
{#if form?.message}<p class="error">{form.message}</p>{/if}
{#if !data.notifications.length}<section class="empty"><p>You have no notifications.</p></section>{:else}<ul
    class="notifications"
  >
    {#each data.notifications as n}<li class:unread={!n.read_at}>
        <JobStatus status={notificationStatus(n.type)} label={notificationLabel(n.type)} />{#if n.job_id}<a
            href={'/app/jobs/' + n.job_id}>{n.message}</a
          >{:else}{n.message}{/if}<time>{new Date(n.created_at).toLocaleString()}</time>
        {#if !n.read_at}<form method="POST" action="?/read">
            <input type="hidden" name="notification_id" value={n.id} /><button class="link">Mark read</button>
          </form>{/if}
      </li>{/each}
  </ul>{/if}

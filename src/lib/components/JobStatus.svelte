<script lang="ts">
  import { statusLabel } from '$lib/ui';

  let { status }: { status: string } = $props();
</script>

<span
  class="job-status"
  class:is-open={status === 'open'}
  class:is-success={status === 'submitted' || status === 'accepted'}
  class:is-cancelled={status === 'cancelled'}
>
  <span class="job-status-dot" aria-hidden="true"></span>
  {statusLabel(status)}
</span>

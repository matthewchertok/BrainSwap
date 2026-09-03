<script lang="ts">
  import { statusLabel } from '$lib/ui';

  let { status, label }: { status: string; label?: string } = $props();
</script>

<span
  class="job-status"
  class:is-open={status === 'open'}
  class:is-draft={status === 'draft'}
  class:is-claimed={status === 'claimed'}
  class:is-revision={status === 'revision_requested'}
  class:is-success={status === 'submitted' || status === 'accepted'}
  class:is-cancelled={status === 'cancelled'}
>
  <span class="job-status-dot" aria-hidden="true"></span>
  {label ?? statusLabel(status)}
</span>

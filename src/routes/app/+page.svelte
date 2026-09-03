<script lang="ts">
  import { statusLabel } from '$lib/ui';
  let { data } = $props();
  const tabs = [
    ['open', 'Open jobs'],
    ['drafts', 'Drafts'],
    ['requests', 'My requests'],
    ['claimed', 'Claimed by me'],
    ['review', 'Awaiting my review'],
    ['completed', 'Completed']
  ];
</script>

<div class="title-row">
  <div>
    <h1>Jobs</h1>
    <p>Coordinate manual AI handoffs inside your lab.</p>
  </div>
  <a class="button" href="/app/jobs/new">Post a job</a>
</div>
<nav class="tabs" aria-label="Job lists">
  {#each tabs as t}<a class:active={data.tab === t[0]} href={'/app?tab=' + t[0]}>{t[1]}</a>{/each}
</nav>
{#if data.loadFailed}<p class="error">Could not load jobs.</p>{:else if !data.jobs.length}<section class="empty">
    <h2>Nothing here yet</h2>
    <p>Post a task you cannot continue, or check another tab.</p>
  </section>{:else}<div class="cards">
    {#each data.jobs as job}<article class="card">
        <div class="card-top">
          <span class="pill">{statusLabel(job.status)}</span><span
            >{job.visibility === 'claimed_only' ? 'Sealed' : 'Lab-visible'}</span
          >
        </div>
        <h2><a href={'/app/jobs/' + job.id}>{job.title}</a></h2>
        <p>{job.listing_summary}</p>
        <dl>
          <div>
            <dt>Requester</dt>
            <dd>{job.requester_name ?? 'Lab member'}</dd>
          </div>
          <div>
            <dt>Model</dt>
            <dd>{job.preferred_model ?? '—'}</dd>
          </div>
          <div>
            <dt>Effort</dt>
            <dd>{job.effort}</dd>
          </div>
          <div>
            <dt>Sensitivity</dt>
            <dd>{job.sensitivity}</dd>
          </div>
        </dl>
      </article>{/each}
  </div>{/if}

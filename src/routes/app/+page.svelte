<script lang="ts">
  import { navigating } from '$app/state';
  import JobStatus from '$lib/components/JobStatus.svelte';
  let { data } = $props();
  const tabs = [
    ['open', 'Open jobs'],
    ['drafts', 'Drafts'],
    ['requests', 'My requests'],
    ['claimed', 'Claimed by me'],
    ['review', 'Awaiting my review'],
    ['completed', 'Completed']
  ];
  const pendingTab = $derived(
    navigating.to?.url.pathname === '/app' ? (navigating.to.url.searchParams.get('tab') ?? 'open') : null
  );
  const visibleTab = $derived(pendingTab ?? data.tab);
  const pendingTabLabel = $derived(tabs.find(([id]) => id === pendingTab)?.[1] ?? 'jobs');
</script>

<div class="title-row">
  <div>
    <h1>Jobs</h1>
    <p>Donate your compute to help others in need.</p>
  </div>
  <a class="button" href="/app/jobs/new">Post a job</a>
</div>
<nav class="tabs" aria-label="Job lists" aria-busy={pendingTab !== null}>
  {#each tabs as t}<a
      class:active={visibleTab === t[0]}
      class:pending={pendingTab === t[0]}
      aria-current={visibleTab === t[0] ? 'page' : undefined}
      href={'/app?tab=' + t[0]}>{t[1]}</a
    >{/each}
</nav>
{#if pendingTab}<p class="tab-loading" role="status" aria-live="polite">
    <span class="spinner" aria-hidden="true"></span>Loading {pendingTabLabel.toLowerCase()}…
  </p>{/if}
<div class="dashboard-results" class:pending={pendingTab !== null} aria-busy={pendingTab !== null}>
  {#if data.loadFailed}<p class="error">Could not load jobs.</p>{:else if !data.jobs.length}<section class="empty">
      <h2>Nothing here yet</h2>
      <p>Post a task you cannot continue, or check another tab.</p>
    </section>{:else}<div class="cards">
      {#each data.jobs as job}<a
          class="card job-card-link"
          href={'/app/jobs/' + job.id}
          aria-label={`Open ${job.title?.trim() || 'untitled draft'}`}
        >
          <div class="card-top">
            <JobStatus status={job.status} />
          </div>
          <h2>{job.title?.trim() || 'Untitled draft'}</h2>
          <p>{job.listing_summary?.trim() || 'No summary yet.'}</p>
          <dl>
            <div>
              <dt>Requester</dt>
              <dd>{job.requester_name ?? 'Lab member'}</dd>
            </div>
            <div>
              <dt>Model</dt>
              <dd>{job.preferred_model ?? '—'}</dd>
            </div>
          </dl>
        </a>{/each}
    </div>{/if}
</div>

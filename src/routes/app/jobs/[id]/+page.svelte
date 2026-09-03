<script lang="ts">
  import { runnablePrompt } from '$lib/prompt';
  import { statusLabel } from '$lib/ui';
  let { data, form } = $props();
  let w = $derived(data.workspace);
  let copied = $state(false);
  let prompt = $derived(w.payload ? runnablePrompt(w.payload, w.contexts ?? [], w.files ?? []) : '');
  async function copy() {
    await navigator.clipboard.writeText(prompt);
    copied = true;
  }
</script>

{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
<article>
  <div class="card-top">
    <span class="pill">{statusLabel(w.job.status)}</span><span
      >{w.job.visibility === 'claimed_only' ? 'Sealed until claimed' : 'Lab-visible'}</span
    >
  </div>
  <h1>{w.job.title}</h1>
  <p class="lead">{w.job.listing_summary}</p>
  <dl class="metadata">
    <div>
      <dt>Effort</dt>
      <dd>{w.job.effort}</dd>
    </div>
    <div>
      <dt>Sensitivity</dt>
      <dd>{w.job.sensitivity}</dd>
    </div>
    <div>
      <dt>Required tools</dt>
      <dd>{w.job.required_tools?.join(', ') || 'None'}</dd>
    </div>
  </dl>
  {#if !w.payload}<section class="sealed">
      <h2>Sealed task</h2>
      <p>
        The instructions become available only to the successful claimant. Administrators and the requester retain
        access.
      </p>
      {#if w.permissions.claim}<form method="POST" action="?/claim"><button>Claim for four hours</button></form>{/if}
    </section>{:else}<section class="workspace">
      <h2>Current task</h2>
      <pre>{w.payload.current_task}</pre>
      <h2>Definition of done</h2>
      <pre>{w.payload.success_criteria}</pre>
      <h2>Output format</h2>
      <pre>{w.payload.output_format}</pre>
      <h2>Context</h2>
      {#each w.contexts ?? [] as c}<div class="context">
          <strong>{c.label}</strong>{#if c.url}<a href={c.url} target="_blank" rel="noopener noreferrer"
              >Open external link</a
            >{/if}
          <pre>{c.text_content ?? ''}</pre>
        </div>{/each}
      <div class="actions">
        <button type="button" onclick={copy}>{copied ? 'Copied' : 'Copy runnable prompt'}</button
        >{#if w.permissions.extend}<form method="POST" action="?/extend"><button>Extend claim</button></form>
          <form method="POST" action="?/release"><button class="secondary">Release</button></form>{/if}
      </div>
      {#if w.permissions.submit}<form method="POST" action="?/submit" class="panel">
          <h2>Return result</h2>
          <label>Exact model used<input name="model_used_text" required /></label><label
            >Full output<textarea name="response_text" rows="12" required></textarea></label
          ><label>Notes / limitations<textarea name="notes"></textarea></label><button>Submit immutable result</button>
        </form>{/if}
    </section>{/if}{#if w.submissions?.length}<section>
      <h2>Submission history</h2>
      {#each w.submissions as s}<article class="submission">
          <h3>Revision {s.revision_number} · {s.model_used_text}</h3>
          <pre>{s.response_text}</pre>
          {#if s.notes}<p>{s.notes}</p>{/if}
        </article>{/each}
    </section>{/if}
  <div class="actions">
    {#if w.permissions.accept}<form method="POST" action="?/accept"><button>Accept result</button></form>
      <form method="POST" action="?/revise">
        <label>Revision instructions<textarea name="instructions" required></textarea></label><button
          >Request revision</button
        >
      </form>{/if}{#if w.permissions.cancel}<form method="POST" action="?/cancel">
        <button class="danger-button">Cancel job</button>
      </form>{/if}
  </div>
</article>

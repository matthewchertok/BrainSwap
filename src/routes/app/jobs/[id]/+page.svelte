<script lang="ts">
  import { goto, invalidateAll } from '$app/navigation';
  import { runnablePrompt } from '$lib/prompt';
  import { downloadPrivateFile, uploadReservedFile } from '$lib/storage';
  import { getBrowserSupabase } from '$lib/supabase-browser';
  import { statusLabel } from '$lib/ui';
  import { JOB_TOOLS, validFile } from '$lib/validation';

  let { data, form } = $props();
  let w = $derived(data.workspace);
  let copied = $state(false);
  let busy = $state(false);
  let fileMessage = $state('');
  let jobFileDescription = $state('');
  let resultFileDescription = $state('');
  let prompt = $derived(w.payload ? runnablePrompt(w.payload, w.contexts ?? [], w.files ?? []) : '');

  async function copy() {
    try {
      await navigator.clipboard.writeText(prompt);
      copied = true;
    } catch {
      fileMessage = 'Clipboard access was not available.';
    }
  }

  async function upload(event: Event, kind: 'job' | 'submission') {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    if (!validFile(file.name, file.type, file.size)) {
      fileMessage = 'Choose an allowlisted file no larger than 25 MiB.';
      return;
    }
    busy = true;
    fileMessage = '';
    const client = getBrowserSupabase();
    const reserveName = kind === 'job' ? 'reserve_job_file' : 'reserve_submission_file';
    const finalizeName = kind === 'job' ? 'finalize_job_file' : 'finalize_submission_file';
    const description = kind === 'job' ? jobFileDescription : resultFileDescription;
    let reservation: { id: string; storage_path: string } | null = null;
    try {
      const { data: reserved, error: reserveError } = await client.rpc(reserveName, {
        p_job_id: w.job.id,
        p_filename: file.name,
        p_mime_type: file.type,
        p_size_bytes: file.size,
        p_description: description.trim() || null
      });
      if (reserveError) throw new Error('The file reservation was rejected.');
      reservation = Array.isArray(reserved) ? reserved[0] : reserved;
      if (!reservation?.id || !reservation.storage_path) throw new Error('The file reservation was incomplete.');
      await uploadReservedFile(client, reservation.storage_path, file);
      const { error: finalizeError } = await client.rpc(finalizeName, { p_file_id: reservation.id });
      if (finalizeError) throw new Error('The uploaded file could not be finalized.');
      if (kind === 'job') jobFileDescription = '';
      else resultFileDescription = '';
      fileMessage = 'File uploaded.';
      await invalidateAll();
    } catch (uploadError) {
      const cleaned = reservation?.id ? await cleanup(reservation.id, kind, false) : true;
      fileMessage = `${uploadError instanceof Error ? uploadError.message : 'The file could not be uploaded.'}${
        cleaned ? '' : ' The pending reservation remains visible and can be retried or removed.'
      }`;
      if (!cleaned) await invalidateAll();
    } finally {
      busy = false;
    }
  }

  async function download(file: { id: string; kind?: string }) {
    busy = true;
    fileMessage = '';
    try {
      const client = getBrowserSupabase();
      const kind = file.kind === 'submission' ? 'submission' : 'job';
      const { data: rows, error } = await client.rpc('file_download_info', {
        p_file_id: file.id,
        p_kind: kind
      });
      const info = Array.isArray(rows) ? rows[0] : rows;
      if (error || !info?.storage_path) throw new Error('The file is not available to download.');
      await downloadPrivateFile(client, info.storage_path, info.original_filename);
    } catch (downloadError) {
      fileMessage = downloadError instanceof Error ? downloadError.message : 'The file could not be downloaded.';
    } finally {
      busy = false;
    }
  }

  async function cleanup(fileId: string, kind: 'job' | 'submission', refresh = true) {
    const client = getBrowserSupabase();
    try {
      const { data: rows, error: infoError } = await client.rpc('file_cleanup_info', {
        p_file_id: fileId,
        p_kind: kind
      });
      const info = Array.isArray(rows) ? rows[0] : rows;
      if (infoError || !info?.storage_path) throw new Error('File cleanup could not start.');
      const { error: storageError } = await client.storage.from('job-files').remove([info.storage_path]);
      if (storageError) throw new Error('Storage cleanup failed; it is safe to retry.');
      const { error: recordError } = await client.rpc('delete_file_record', {
        p_file_id: fileId,
        p_kind: kind
      });
      if (recordError) throw new Error('Metadata cleanup failed; it is safe to retry.');
      if (refresh) {
        fileMessage = 'File removed.';
        await invalidateAll();
      }
      return true;
    } catch (cleanupError) {
      if (refresh)
        fileMessage = cleanupError instanceof Error ? cleanupError.message : 'The file could not be removed.';
      return false;
    }
  }

  async function retryFinalize(file: { id: string; kind?: string }) {
    busy = true;
    fileMessage = '';
    const client = getBrowserSupabase();
    const rpcName = file.kind === 'submission' ? 'finalize_submission_file' : 'finalize_job_file';
    const { error } = await client.rpc(rpcName, { p_file_id: file.id });
    fileMessage = error
      ? 'Finalization still failed. Remove the reservation if the upload did not finish.'
      : 'File finalized.';
    await invalidateAll();
    busy = false;
  }

  async function removeFile(file: { id: string; kind?: string }) {
    if (!window.confirm('Remove this file?')) return;
    busy = true;
    fileMessage = '';
    await cleanup(file.id, file.kind === 'submission' ? 'submission' : 'job');
    busy = false;
  }

  async function deleteJob() {
    if (!window.confirm('Delete this job and its stored files? This cannot be undone.')) return;
    busy = true;
    fileMessage = '';
    try {
      const client = getBrowserSupabase();
      const { data: manifest, error: beginError } = await client.rpc('begin_job_deletion', {
        p_job_id: w.job.id
      });
      if (beginError) throw new Error('Job deletion could not start.');
      const paths = (manifest ?? []).map((item: { storage_path: string }) => item.storage_path);
      let cleanupFailed = false;
      for (const path of paths) {
        const { error: storageError } = await client.storage.from('job-files').remove([path]);
        if (storageError) cleanupFailed = true;
      }
      if (cleanupFailed) throw new Error('Some Storage cleanup failed; it is safe to retry deletion.');
      const { error: deleteError } = await client.rpc('delete_job_after_storage_cleanup', {
        p_job_id: w.job.id
      });
      if (deleteError) throw new Error('Job cleanup is incomplete; it is safe to retry deletion.');
      await goto('/app');
    } catch (deletionError) {
      fileMessage = deletionError instanceof Error ? deletionError.message : 'The job could not be deleted.';
    } finally {
      busy = false;
    }
  }

  function priorContext() {
    return (w.contexts ?? [])
      .filter((context: { kind: string }) => context.kind === 'inline_text')
      .map((context: { text_content?: string }) => context.text_content ?? '')
      .filter(Boolean)
      .join('\n\n');
  }

  function externalUrls() {
    return (w.contexts ?? [])
      .filter((context: { kind: string }) => ['external_link', 'shared_chat'].includes(context.kind))
      .map((context: { url?: string }) => context.url ?? '')
      .filter(Boolean)
      .join('\n');
  }

  function modelPreference(id: string) {
    return (w.models ?? []).find((model: { id: string }) => model.id === id)?.preference;
  }

  function resultFilesIncomplete() {
    return (w.pending_files ?? []).some(
      (file: { kind: string; upload_status: string; cleanup_started_at?: string | null }) =>
        file.kind === 'submission' && (file.upload_status !== 'ready' || file.cleanup_started_at)
    );
  }
</script>

{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
{#if data.publishError}<p class="error">The draft was saved, but it was not published. Review it and try again.</p>{/if}
{#if w.job.deletion_pending}<p class="error">
    Job deletion is incomplete. Individual file controls are disabled; use Retry deletion below.
  </p>{/if}
{#if fileMessage}<p
    class:notice={!fileMessage.includes('failed')}
    class:error={fileMessage.includes('failed')}
    role="status"
  >
    {fileMessage}
  </p>{/if}

<article>
  <div class="card-top">
    <span class="pill">{statusLabel(w.job.status)}</span><span
      >{w.job.visibility === 'claimed_only' ? 'Sealed task' : 'Lab-visible task'}</span
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
      <dt>Deadline</dt>
      <dd>{w.job.deadline ? new Date(w.job.deadline).toLocaleString() : 'None'}</dd>
    </div>
    <div>
      <dt>Required tools</dt>
      <dd>{w.job.required_tools?.join(', ') || 'None'}</dd>
    </div>
    <div>
      <dt>Models</dt>
      <dd>
        {(w.models ?? [])
          .map((model: { display_name: string; preference: string }) => `${model.display_name} (${model.preference})`)
          .join(', ') || 'None'}
      </dd>
    </div>
    {#if w.protected?.claim_expires_at}<div>
        <dt>Claim expires</dt>
        <dd>{new Date(w.protected.claim_expires_at).toLocaleString()}</dd>
      </div>{/if}
  </dl>

  {#if w.protected?.sensitivity_notes}<section class="danger">
      <h2>Handling notes</h2>
      <pre>{w.protected.sensitivity_notes}</pre>
    </section>{/if}

  {#if w.permissions.update}
    <form method="POST" action="?/update" class="job-form panel">
      <h2>Edit draft</h2>
      <label>Title<input name="title" value={w.job.title} maxlength="120" required /></label>
      <label
        >Lab-visible listing summary<textarea name="listing_summary" maxlength="1000" required
          >{w.job.listing_summary}</textarea
        ></label
      >
      <label
        >Exact current task<textarea name="current_task" rows="8" maxlength="100000" required
          >{w.payload.current_task}</textarea
        ></label
      >
      <label
        >Definition of done<textarea name="success_criteria" maxlength="25000" required
          >{w.payload.success_criteria}</textarea
        ></label
      >
      <label
        >Desired output format<textarea name="output_format" maxlength="10000" required
          >{w.payload.output_format}</textarea
        ></label
      >
      <label>Prior context<textarea name="prior_context" rows="8" maxlength="250000">{priorContext()}</textarea></label>
      <label
        >Institutional or shared links<textarea name="external_urls" rows="3" maxlength="20480"
          >{externalUrls()}</textarea
        ></label
      >
      <label
        >Preferred model<select name="preferred_model_id" required>
          {#each data.availableModels as model}<option
              value={model.id}
              selected={modelPreference(model.id) === 'preferred'}>{model.display_name}</option
            >{/each}
        </select></label
      >
      <fieldset>
        <legend>Other acceptable models</legend>
        {#each data.availableModels as model}<label
            ><input
              type="checkbox"
              name="acceptable_model_ids"
              value={model.id}
              checked={modelPreference(model.id) === 'acceptable'}
            />{model.display_name}</label
          >{/each}
      </fieldset>
      <fieldset>
        <legend>Required tools</legend>
        {#each JOB_TOOLS as tool}<label
            ><input
              type="checkbox"
              name="required_tools"
              value={tool}
              checked={w.job.required_tools?.includes(tool)}
            />{tool}</label
          >{/each}
      </fieldset>
      <label
        >Effort<select name="effort">
          {#each ['quick', 'medium', 'heavy'] as effort}<option value={effort} selected={w.job.effort === effort}
              >{effort}</option
            >{/each}
        </select></label
      >
      <label
        >Deadline (ISO timestamp with offset)<input
          name="deadline"
          value={w.job.deadline ?? ''}
          placeholder="2026-09-30T17:00:00-04:00"
        /></label
      >
      <label
        >Visibility<select name="visibility">
          <option value="claimed_only" selected={w.job.visibility === 'claimed_only'}>Sealed until claimed</option>
          <option value="lab" selected={w.job.visibility === 'lab'}>Lab-visible</option>
        </select></label
      >
      <label
        >Sensitivity<select name="sensitivity">
          {#each ['general', 'unpublished', 'collaborator', 'other'] as sensitivity}<option
              value={sensitivity}
              selected={w.job.sensitivity === sensitivity}>{sensitivity}</option
            >{/each}
        </select></label
      >
      <label
        >Sensitivity notes<textarea name="sensitivity_notes" maxlength="10000"
          >{w.protected?.sensitivity_notes ?? ''}</textarea
        ></label
      >
      <label class="ack"
        ><input type="checkbox" name="acknowledged" value="yes" checked required />I am authorized to share this content
        with eligible helpers and the selected provider.</label
      >
      <button>Save draft</button>
    </form>

    <section class="panel">
      <h2>Attach job file</h2>
      <p>Allowlisted formats only, 25 MiB per file and 100 MiB total. Files are not malware-scanned.</p>
      <label>Description<input bind:value={jobFileDescription} maxlength="1000" /></label>
      <label>File<input type="file" disabled={busy} onchange={(event) => upload(event, 'job')} /></label>
    </section>
  {/if}

  {#if w.files?.length}<section>
      <h2>Job files</h2>
      <ul>
        {#each w.files as file}<li>
            <button type="button" class="link" disabled={busy} onclick={() => download({ ...file, kind: 'job' })}
              >Download {file.original_filename}</button
            >
            ({Math.ceil(file.size_bytes / 1024)} KiB)
            {#if w.permissions.update}<button
                type="button"
                class="link danger-text"
                disabled={busy}
                onclick={() => removeFile({ ...file, kind: 'job' })}>Remove</button
              >{/if}
          </li>{/each}
      </ul>
    </section>{/if}

  {#if w.pending_files?.length && !w.job.deletion_pending}<section class="panel">
      <h2>Current draft attachments</h2>
      <ul>
        {#each w.pending_files as file}<li>
            {file.original_filename} · {file.stale
              ? 'stale draft attachment'
              : file.cleanup_started_at
                ? 'cleanup pending'
                : file.upload_status}
            {#if !file.stale && file.upload_status === 'ready' && !file.cleanup_started_at}<button
                type="button"
                class="link"
                onclick={() => download(file)}>Download</button
              >{:else if !file.stale && !file.cleanup_started_at}<button
                type="button"
                class="link"
                disabled={busy}
                onclick={() => retryFinalize(file)}>Retry finalization</button
              >{/if}
            <button type="button" class="link danger-text" disabled={busy} onclick={() => removeFile(file)}
              >Remove</button
            >
          </li>{/each}
      </ul>
    </section>{/if}

  {#if w.permissions.publish}<form method="POST" action="?/publish" class="actions">
      <button>Publish job</button>
    </form>{/if}

  {#if !w.payload}<section class="sealed">
      <h2>Sealed task</h2>
      <p>The protected instructions become available only to an authorized participant.</p>
      {#if w.permissions.claim}<form method="POST" action="?/claim"><button>Claim for four hours</button></form>{/if}
    </section>{:else if !w.permissions.update}<section class="workspace">
      <h2>Current task</h2>
      <pre>{w.payload.current_task}</pre>
      <h2>Definition of done</h2>
      <pre>{w.payload.success_criteria}</pre>
      <h2>Output format</h2>
      <pre>{w.payload.output_format}</pre>
      <h2>Context</h2>
      {#if !(w.contexts ?? []).length}<p>None supplied.</p>{/if}
      {#each w.contexts ?? [] as context}<div class="context">
          <strong>{context.label}</strong>{#if context.url}<a
              href={context.url}
              target="_blank"
              rel="noopener noreferrer">Open external link</a
            >{/if}
          <pre>{context.text_content ?? ''}</pre>
        </div>{/each}
      <div class="actions">
        <button type="button" onclick={copy}>{copied ? 'Copied' : 'Copy runnable prompt'}</button>
        {#if w.permissions.claim}<form method="POST" action="?/claim"><button>Claim for four hours</button></form>{/if}
        {#if w.permissions.extend}<form method="POST" action="?/extend"><button>Extend claim</button></form>{/if}
        {#if w.permissions.release}<form method="POST" action="?/release">
            <button class="secondary">Release</button>
          </form>{/if}
      </div>
      {#if w.permissions.submit}<section class="panel">
          <h2>Attach result file</h2>
          <label>Description<input bind:value={resultFileDescription} maxlength="1000" /></label>
          <label>File<input type="file" disabled={busy} onchange={(event) => upload(event, 'submission')} /></label>
        </section>
        <form method="POST" action="?/submit" class="panel">
          <h2>Return result</h2>
          <label>Exact model used<input name="model_used_text" maxlength="200" required /></label>
          <fieldset>
            <legend>Tools used</legend>
            {#each JOB_TOOLS as tool}<label><input type="checkbox" name="tools_used" value={tool} />{tool}</label
              >{/each}
          </fieldset>
          <label>Full output<textarea name="response_text" rows="12" maxlength="500000" required></textarea></label>
          <label>Notes / limitations<textarea name="notes" maxlength="25000"></textarea></label>
          <button disabled={busy || resultFilesIncomplete()}>Submit immutable result</button>
        </form>{/if}
    </section>{/if}

  {#if w.revision_requests?.length}<section>
      <h2>Revision requests</h2>
      {#each w.revision_requests as revision}<article class="context">
          <strong>{new Date(revision.created_at).toLocaleString()}</strong>
          <pre>{revision.instructions}</pre>
          <p>{revision.resolved_at ? 'Resolved' : 'Open'}</p>
        </article>{/each}
    </section>{/if}

  {#if w.submissions?.length}<section>
      <h2>Submission history</h2>
      {#each w.submissions as submission}<article class="submission">
          <h3>Revision {submission.revision_number} · {submission.model_used_text}</h3>
          <pre>{submission.response_text}</pre>
          {#if submission.notes}<p>{submission.notes}</p>{/if}
          {#if submission.tools_used?.length}<p>Tools: {submission.tools_used.join(', ')}</p>{/if}
          {#if submission.files?.length}<ul>
              {#each submission.files as file}<li>
                  <button
                    type="button"
                    class="link"
                    disabled={busy}
                    onclick={() => download({ ...file, kind: 'submission' })}>Download {file.original_filename}</button
                  >
                </li>{/each}
            </ul>{/if}
        </article>{/each}
    </section>{/if}

  <div class="actions workflow-controls">
    {#if w.permissions.accept}<form method="POST" action="?/accept"><button>Accept result</button></form>{/if}
    {#if w.permissions.revise}<form method="POST" action="?/revise" class="panel">
        <label>Revision instructions<textarea name="instructions" maxlength="25000" required></textarea></label><button
          >Request revision</button
        >
      </form>{/if}
    {#if w.permissions.cancel}<form method="POST" action="?/cancel">
        <button class="danger-button">Cancel job</button>
      </form>{/if}
    {#if w.permissions.reopen}<form method="POST" action="?/reopen"><button>Reopen job</button></form>{/if}
    {#if w.permissions.follow_up}<form method="POST" action="?/follow_up">
        <button class="secondary">Create follow-up draft</button>
      </form>{/if}
    {#if w.permissions.delete}<button type="button" class="danger-button" disabled={busy} onclick={deleteJob}
        >{w.job.deletion_pending ? 'Retry deletion' : 'Delete job'}</button
      >{/if}
  </div>
</article>

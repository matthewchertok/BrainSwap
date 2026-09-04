<script lang="ts">
  import { goto, invalidateAll } from '$app/navigation';
  import JobStatus from '$lib/components/JobStatus.svelte';
  import { runnablePrompt } from '$lib/prompt';
  import { downloadPrivateFile, uploadReservedFile } from '$lib/storage';
  import { getBrowserSupabase } from '$lib/supabase-browser';
  import { dateTimeLocalToIso, isoToDateTimeLocal } from '$lib/ui';
  import { REASONING_EFFORTS, validFile, validJobAttachmentZip } from '$lib/validation';

  let { data, form } = $props();
  let w = $derived(data.workspace);
  let copied = $state(false);
  let busy = $state(false);
  let fileMessage = $state('');
  let jobFileDescription = $state('');
  let resultFileDescription = $state('');
  let editorJobId = $state('');
  let deadlineLocal = $state('');
  let reasoningEffort = $state('medium');
  let reasoningEffortOther = $state('');
  let draftTitle = $state('');
  let draftTaskSummary = $state('');
  let draftPrompt = $state('');
  let draftHelperInstructions = $state('');
  let draftChatUrl = $state('');
  let draftPreferredModel = $state('');
  let draftAcceptableModels = $state('');
  let resultModel = $state('');
  let resultResponse = $state('');
  let resultNotes = $state('');
  let uploadingFile = $state<{
    kind: 'job' | 'submission';
    original_filename: string;
    description: string;
  } | null>(null);
  initializeEditor();
  let deadlineIso = $derived(dateTimeLocalToIso(deadlineLocal));
  let prompt = $derived(w.payload ? runnablePrompt(w.payload, w.contexts ?? [], w.files ?? []) : '');

  $effect(() => {
    const nextJobId = w.job.id;
    if (nextJobId === editorJobId) return;
    initializeEditor();
  });

  function initializeEditor() {
    editorJobId = w.job.id;
    deadlineLocal = isoToDateTimeLocal(w.job.deadline);
    draftTitle = w.job.title ?? '';
    draftTaskSummary = w.payload?.task_summary ?? w.job.listing_summary ?? '';
    draftPrompt = w.payload?.prompt ?? w.payload?.success_criteria ?? '';
    draftHelperInstructions = w.payload?.helper_instructions ?? '';
    draftChatUrl = chatUrl();
    draftPreferredModel = w.job.preferred_model_text ?? '';
    draftAcceptableModels = w.job.acceptable_models_text ?? '';
    reasoningEffort = w.editable_submission?.reasoning_effort ?? 'medium';
    reasoningEffortOther = w.editable_submission?.reasoning_effort_other ?? '';
    resultModel = w.editable_submission?.model_used_text ?? '';
    resultResponse = w.editable_submission?.response_text ?? '';
    resultNotes = w.editable_submission?.notes ?? '';
  }

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
    const valid =
      kind === 'job'
        ? validJobAttachmentZip(file.name, file.type, file.size)
        : validFile(file.name, file.type, file.size);
    if (!valid) {
      fileMessage =
        kind === 'job'
          ? 'Choose one ZIP file no larger than 25 MiB.'
          : 'Choose an allowlisted file no larger than 25 MiB.';
      return;
    }
    busy = true;
    fileMessage = '';
    const client = getBrowserSupabase();
    const reserveName = kind === 'job' ? 'reserve_job_file' : 'reserve_submission_file';
    const finalizeName = kind === 'job' ? 'finalize_job_file' : 'finalize_submission_file';
    const description = kind === 'job' ? jobFileDescription : resultFileDescription;
    uploadingFile = { kind, original_filename: file.name, description: description.trim() };
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
      await uploadReservedFile(client, reservation.storage_path, file, kind);
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
      uploadingFile = null;
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

  function chatUrl() {
    return (
      (w.contexts ?? []).find((context: { kind: string; url?: string }) => context.kind === 'shared_chat')?.url ?? ''
    );
  }

  function previousResults() {
    return (w.contexts ?? []).filter(
      (context: { kind: string; text_content?: string | null }) =>
        context.kind === 'previous_job' && context.text_content
    );
  }

  function resultFilesIncomplete() {
    return (w.pending_files ?? []).some(
      (file: { kind: string; upload_status: string; cleanup_started_at?: string | null }) =>
        file.kind === 'submission' && (file.upload_status !== 'ready' || file.cleanup_started_at)
    );
  }

  function jobAttachmentExists() {
    return Boolean(
      w.files?.length ||
      (w.pending_files ?? []).some((file: { kind: string }) => file.kind === 'job') ||
      uploadingFile?.kind === 'job'
    );
  }

  function recoverySubmissionFiles() {
    if (w.permissions.submit || w.permissions.edit_submission) return [];
    return (w.pending_files ?? []).filter(
      (file: { kind: string; can_cleanup?: boolean }) => file.kind === 'submission' && file.can_cleanup
    );
  }

  function effortLabel(value: string) {
    return value === 'extra_high' ? 'Extra High' : value.charAt(0).toUpperCase() + value.slice(1);
  }
</script>

{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
{#if data.notice}<p class="notice">{data.notice}</p>{/if}
{#if data.publishError}<p class="error">The draft was saved, but it was not published. Review it and try again.</p>{/if}
{#if data.attachmentError}<p class="error">
    The draft was saved, but the ZIP attachment could not be uploaded. Add it below and try again.
  </p>{/if}
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

<article class="job-detail">
  <div class="card-top">
    <JobStatus status={w.job.status} />
  </div>
  <h1>{w.job.title || 'Untitled draft'}</h1>
  <p class="lead">{w.payload?.task_summary ?? w.job.task_summary ?? w.job.listing_summary}</p>
  <dl class="metadata">
    <div>
      <dt>Deadline</dt>
      <dd>{w.job.deadline ? new Date(w.job.deadline).toLocaleString() : 'None'}</dd>
    </div>
    <div>
      <dt>Preferred model</dt>
      <dd>{w.job.preferred_model_text || 'None specified'}</dd>
    </div>
    {#if w.job.acceptable_models_text}<div>
        <dt>Other acceptable models</dt>
        <dd>{w.job.acceptable_models_text}</dd>
      </div>{/if}
    {#if w.protected?.claim_expires_at}<div>
        <dt>Claim expires</dt>
        <dd>{new Date(w.protected.claim_expires_at).toLocaleString()}</dd>
      </div>{/if}
  </dl>

  {#if w.payload?.legacy_current_task}<section class="workspace-section">
      <h2>Legacy task details</h2>
      <pre>{w.payload.legacy_current_task}</pre>
    </section>{/if}

  {#if previousResults().length}<section class="workspace-section">
      <h2>Prior finalized result</h2>
      {#each previousResults() as context}<pre>{context.text_content}</pre>{/each}
    </section>{/if}

  {#if w.permissions.update}
    <form id="draft-editor" method="POST" action="?/update" class="job-form panel draft-editor">
      <h2>Edit draft</h2>
      <label
        >Title<input name="title" bind:value={draftTitle} maxlength="120" placeholder="The name of this task" /></label
      >
      <label
        >Task summary<textarea
          name="task_summary"
          rows="4"
          maxlength="1000"
          bind:value={draftTaskSummary}
          placeholder="A brief description of what this task is about"></textarea></label
      >
      <label
        >Prompt<textarea
          name="prompt"
          rows="10"
          maxlength="100000"
          bind:value={draftPrompt}
          placeholder="The complete instruction set for the helper to give their model"></textarea></label
      >
      <label
        >Link to chat<input
          type="url"
          name="chat_url"
          bind:value={draftChatUrl}
          maxlength="2048"
          placeholder="https://chatgpt.com/share/…"
          required
        /></label
      >
      <label
        >Instructions to user (optional)<textarea
          name="helper_instructions"
          rows="5"
          maxlength="25000"
          bind:value={draftHelperInstructions}
          placeholder="How to unzip attachments, other notes, or anything else the helper should know"
        ></textarea></label
      >
      <label
        >Preferred model<input
          name="preferred_model_text"
          bind:value={draftPreferredModel}
          maxlength="200"
          placeholder="GPT-6 Astra"
        /></label
      >
      <label
        >Other acceptable models (optional)<input
          name="acceptable_models_text"
          bind:value={draftAcceptableModels}
          maxlength="1000"
          placeholder="Any frontier model"
        /></label
      >
      <label
        >Deadline (optional)<input
          type="datetime-local"
          name="deadline_local"
          bind:value={deadlineLocal}
          step="60"
          aria-describedby="edit-deadline-help"
        /></label
      >
      <input type="hidden" name="deadline" value={deadlineIso} />
      <p id="edit-deadline-help" class="field-help">Choose the date and time in your device’s local timezone.</p>
    </form>

    <section class="panel attachment-panel">
      <h2>Required attachments</h2>
      <p>Put all attachments in one ZIP file. Maximum size: 25 MiB.</p>
      <label>Description (optional)<input bind:value={jobFileDescription} maxlength="1000" /></label>
      <label
        >ZIP file<input
          type="file"
          accept=".zip,application/zip,application/x-zip-compressed"
          disabled={busy || jobAttachmentExists()}
          onchange={(event) => upload(event, 'job')}
        /></label
      >
      {#if jobAttachmentExists()}<p class="field-help">Remove the current ZIP before uploading a replacement.</p>{/if}

      {#if w.files?.length || (w.pending_files ?? []).some((file: { kind: string }) => file.kind === 'job') || uploadingFile?.kind === 'job'}
        <div class="table-wrap">
          <table class="file-table">
            <thead><tr><th>ZIP file</th><th>Description</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {#each w.files ?? [] as file}<tr>
                  <td>{file.original_filename}</td><td>{file.description || '—'}</td><td>Uploaded</td><td>
                    <button
                      type="button"
                      class="link"
                      disabled={busy}
                      onclick={() => download({ ...file, kind: 'job' })}>Download</button
                    >
                    <button
                      type="button"
                      class="link danger-text"
                      disabled={busy}
                      onclick={() => removeFile({ ...file, kind: 'job' })}>Remove</button
                    >
                  </td>
                </tr>{/each}
              {#each (w.pending_files ?? []).filter((file: { kind: string }) => file.kind === 'job') as file}<tr>
                  <td>{file.original_filename}</td><td>{file.description || '—'}</td><td
                    >{file.cleanup_started_at
                      ? 'Removing'
                      : file.upload_status === 'ready'
                        ? 'Uploaded'
                        : 'Pending'}</td
                  ><td>
                    {#if file.upload_status !== 'ready' && !file.cleanup_started_at}<button
                        type="button"
                        class="link"
                        disabled={busy}
                        onclick={() => retryFinalize(file)}>Retry</button
                      >{/if}
                    <button type="button" class="link danger-text" disabled={busy} onclick={() => removeFile(file)}
                      >Remove</button
                    >
                  </td>
                </tr>{/each}
              {#if uploadingFile?.kind === 'job'}<tr>
                  <td>{uploadingFile.original_filename}</td><td>{uploadingFile.description || '—'}</td><td>Uploading</td
                  ><td>—</td>
                </tr>{/if}
            </tbody>
          </table>
        </div>
      {/if}
    </section>

    <div class="actions standalone-action">
      <button type="submit" form="draft-editor" name="intent" value="draft" class="status-button" formnovalidate>
        <span class="status-dot is-draft" aria-hidden="true"></span>
        Save draft
      </button>
      {#if w.permissions.publish}<button type="submit" form="draft-editor" name="intent" value="publish"
          >Publish job</button
        >{/if}
    </div>
  {/if}

  {#if !w.payload}<section class="panel private-job">
      <h2>Ready to help?</h2>
      <p>Claim this job to view its prompt, chat link, and relevant files.</p>
      {#if w.permissions.claim}<form method="POST" action="?/claim"><button>Claim for four hours</button></form>{/if}
    </section>{:else if !w.permissions.update}<section class="workspace">
      <section class="workspace-section">
        <h2>Prompt</h2>
        <pre>{w.payload.prompt ?? w.payload.success_criteria}</pre>
      </section>

      {#if chatUrl() && w.job.status !== 'open'}<section class="workspace-section">
          <h2>Link to chat</h2>
          <a href={chatUrl()} target="_blank" rel="noopener noreferrer">Open shared chat</a>
        </section>{/if}

      {#if w.payload.helper_instructions}<section class="workspace-section">
          <h2>Instructions to user</h2>
          <pre>{w.payload.helper_instructions}</pre>
        </section>{/if}

      {#if w.files?.length}<section class="workspace-section">
          <h2>Required attachments</h2>
          <div class="table-wrap">
            <table class="file-table">
              <thead><tr><th>File</th><th>Description</th><th>Action</th></tr></thead>
              <tbody
                >{#each w.files as file}<tr>
                    <td>{file.original_filename}</td><td>{file.description || '—'}</td><td
                      ><button
                        type="button"
                        class="link"
                        disabled={busy}
                        onclick={() => download({ ...file, kind: 'job' })}>Download</button
                      ></td
                    >
                  </tr>{/each}</tbody
              >
            </table>
          </div>
        </section>{/if}

      <div class="actions prompt-actions">
        {#if w.permissions.copy_prompt}<button type="button" onclick={copy}
            >{copied ? 'Copied' : 'Copy runnable prompt'}</button
          >{/if}
        {#if w.permissions.extend}<form method="POST" action="?/extend"><button>Extend claim</button></form>{/if}
        {#if w.permissions.release}<form method="POST" action="?/release">
            <button class="secondary">Release</button>
          </form>{/if}
      </div>

      {#if w.permissions.submit || w.permissions.edit_submission}<section
          class="panel attachment-panel result-attachment-panel"
        >
          <h2>Attach result files</h2>
          <p>Maximum 25 MiB per file and 100 MiB total.</p>
          <label>Description<input bind:value={resultFileDescription} maxlength="1000" /></label>
          <label>File<input type="file" disabled={busy} onchange={(event) => upload(event, 'submission')} /></label>

          {#if w.editable_submission?.files?.length || (w.pending_files ?? []).some((file: { kind: string }) => file.kind === 'submission') || uploadingFile?.kind === 'submission'}
            <div class="table-wrap">
              <table class="file-table">
                <thead><tr><th>File</th><th>Description</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody>
                  {#each w.editable_submission?.files ?? [] as file}<tr>
                      <td>{file.original_filename}</td><td>{file.description || '—'}</td><td>Uploaded</td><td>
                        <button
                          type="button"
                          class="link"
                          disabled={busy}
                          onclick={() => download({ ...file, kind: 'submission' })}>Download</button
                        >
                        <button
                          type="button"
                          class="link danger-text"
                          disabled={busy}
                          onclick={() => removeFile({ ...file, kind: 'submission' })}>Remove</button
                        >
                      </td>
                    </tr>{/each}
                  {#each (w.pending_files ?? []).filter((file: { kind: string }) => file.kind === 'submission') as file}<tr
                    >
                      <td>{file.original_filename}</td><td>{file.description || '—'}</td><td
                        >{file.cleanup_started_at
                          ? 'Removing'
                          : file.upload_status === 'ready'
                            ? 'Uploaded'
                            : 'Pending'}</td
                      ><td>
                        {#if file.upload_status !== 'ready' && !file.cleanup_started_at}<button
                            type="button"
                            class="link"
                            disabled={busy}
                            onclick={() => retryFinalize(file)}>Retry</button
                          >{/if}
                        {#if file.can_cleanup}<button
                            type="button"
                            class="link danger-text"
                            disabled={busy}
                            onclick={() => removeFile(file)}>Remove</button
                          >{:else}<span class="field-help"
                            >Cleanup is available to the requester or an administrator.</span
                          >{/if}
                      </td>
                    </tr>{/each}
                  {#if uploadingFile?.kind === 'submission'}<tr>
                      <td>{uploadingFile.original_filename}</td><td>{uploadingFile.description || '—'}</td><td
                        >Uploading</td
                      ><td>—</td>
                    </tr>{/if}
                </tbody>
              </table>
            </div>
          {/if}
        </section>

        <form
          method="POST"
          action={w.permissions.edit_submission ? '?/edit_submission' : '?/submit'}
          class="panel result-form"
        >
          <h2>{w.permissions.edit_submission ? 'Edit result' : 'Return result'}</h2>
          <label
            >Exact model used<input name="model_used_text" bind:value={resultModel} maxlength="200" required /></label
          >
          <fieldset>
            <legend>Reasoning effort</legend>
            {#each REASONING_EFFORTS as effort}<label
                ><input
                  type="radio"
                  name="reasoning_effort"
                  value={effort}
                  bind:group={reasoningEffort}
                  required
                />{effortLabel(effort)}</label
              >{/each}
            {#if reasoningEffort === 'other'}<label
                >Please specify<input
                  name="reasoning_effort_other"
                  bind:value={reasoningEffortOther}
                  maxlength="200"
                  required
                /></label
              >{:else}<input type="hidden" name="reasoning_effort_other" value="" />{/if}
          </fieldset>
          <label
            >Full output<textarea name="response_text" rows="12" maxlength="500000" required bind:value={resultResponse}
            ></textarea></label
          >
          <label
            >Other notes (optional)<textarea name="notes" maxlength="25000" bind:value={resultNotes}></textarea></label
          >
          <button disabled={busy || resultFilesIncomplete()}
            >{w.permissions.edit_submission ? 'Save changes' : 'Submit'}</button
          >
        </form>{/if}
    </section>{/if}

  {#if recoverySubmissionFiles().length}<section class="panel attachment-panel recovery-attachment-panel">
      <h2>Attachment cleanup</h2>
      <p>These unfinished or stale result attachments can be removed safely.</p>
      <div class="table-wrap">
        <table class="file-table">
          <thead><tr><th>File</th><th>Description</th><th>Status</th><th>Action</th></tr></thead>
          <tbody>
            {#each recoverySubmissionFiles() as file}<tr>
                <td>{file.original_filename}</td>
                <td>{file.description || '—'}</td>
                <td>{file.cleanup_started_at ? 'Removal pending' : file.stale ? 'Stale draft' : 'Pending'}</td>
                <td
                  ><button type="button" class="link danger-text" disabled={busy} onclick={() => removeFile(file)}
                    >Remove</button
                  ></td
                >
              </tr>{/each}
          </tbody>
        </table>
      </div>
    </section>{/if}

  {#if w.revision_requests?.length}<section class="section-stack">
      <h2>Revision requests</h2>
      {#each w.revision_requests as revision}<article class="context">
          <strong>{new Date(revision.created_at).toLocaleString()}</strong>
          <pre>{revision.instructions}</pre>
          <p>{revision.resolved_at ? 'Resolved' : 'Open'}</p>
        </article>{/each}
    </section>{/if}

  {#if w.submissions?.length}<section class="section-stack">
      <h2>Submission history</h2>
      {#each w.submissions as submission}<article class="submission">
          <h3>Revision {submission.revision_number} · {submission.model_used_text}</h3>
          <pre>{submission.response_text}</pre>
          {#if submission.reasoning_effort}<p>
              Reasoning effort: {effortLabel(submission.reasoning_effort)}{submission.reasoning_effort_other
                ? ` — ${submission.reasoning_effort_other}`
                : ''}
            </p>{/if}
          {#if submission.notes}<p>{submission.notes}</p>{/if}
          {#if submission.files?.length}<div class="table-wrap">
              <table class="file-table">
                <thead><tr><th>File</th><th>Description</th><th>Action</th></tr></thead>
                <tbody
                  >{#each submission.files as file}<tr>
                      <td>{file.original_filename}</td><td>{file.description || '—'}</td><td
                        ><button
                          type="button"
                          class="link"
                          disabled={busy}
                          onclick={() => download({ ...file, kind: 'submission' })}>Download</button
                        ></td
                      >
                    </tr>{/each}</tbody
                >
              </table>
            </div>{/if}
        </article>{/each}
    </section>{/if}

  <div class="workflow-controls">
    {#if w.permissions.accept}<form method="POST" action="?/accept"><button>Accept result</button></form>{/if}
    {#if w.permissions.revise}<form method="POST" action="?/revise" class="panel revision-card">
        <label>Revision instructions<textarea name="instructions" rows="6" maxlength="25000" required></textarea></label
        >
        <button>Request revision</button>
      </form>{/if}
    <div class="actions workflow-buttons">
      {#if w.permissions.cancel && w.job.status !== 'cancelled'}<form method="POST" action="?/cancel">
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
  </div>
</article>

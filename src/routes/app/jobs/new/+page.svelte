<script lang="ts">
  import { dateTimeLocalToIso } from '$lib/ui';

  let { form } = $props();
  let deadlineLocal = $state('');
  let selectedAttachment = $state('');
  let deadlineIso = $derived(dateTimeLocalToIso(deadlineLocal));

  function selectAttachment(event: Event) {
    selectedAttachment = (event.currentTarget as HTMLInputElement).files?.[0]?.name ?? '';
  }
</script>

<div class="title-row">
  <div>
    <h1>Post a job</h1>
    <p>Start with whatever you know. You can finish a draft later.</p>
  </div>
</div>

{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}

<form method="POST" enctype="multipart/form-data" class="job-form">
  <fieldset>
    <legend>Task</legend>
    <label>Title<input name="title" maxlength="120" placeholder="The name of this task" /></label>
    <label
      >Task summary<textarea
        name="task_summary"
        rows="4"
        maxlength="1000"
        placeholder="A brief description of what this task is about"></textarea></label
    >
    <label
      >Prompt<textarea
        name="prompt"
        rows="10"
        maxlength="100000"
        placeholder="The complete instruction set for the helper to give their model"></textarea></label
    >
    <label
      >Link to chat<input
        type="url"
        name="chat_url"
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
        placeholder="How to unzip attachments, other notes, or anything else the helper should know"></textarea></label
    >
  </fieldset>

  <fieldset>
    <legend>Preferences</legend>
    <label>Preferred model<input name="preferred_model_text" maxlength="200" placeholder="GPT-6 Astra" /></label>
    <label
      >Other acceptable models (optional)<input
        name="acceptable_models_text"
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
        aria-describedby="deadline-help"
      /></label
    >
    <input type="hidden" name="deadline" value={deadlineIso} />
    <p id="deadline-help" class="field-help">Choose the date and time in your device’s local timezone.</p>
  </fieldset>

  <fieldset>
    <legend>Required attachments (optional)</legend>
    <p class="field-help">Put all attachments in one ZIP file. Maximum size: 25 MiB.</p>
    <label
      >ZIP file<input
        type="file"
        name="job_attachment"
        accept=".zip,application/zip,application/x-zip-compressed"
        onchange={selectAttachment}
      /></label
    >
    {#if selectedAttachment}<div class="table-wrap">
        <table class="file-table">
          <thead><tr><th>File</th><th>Status</th></tr></thead>
          <tbody><tr><td>{selectedAttachment}</td><td>Selected</td></tr></tbody>
        </table>
      </div>{/if}
  </fieldset>

  <section class="actions form-actions">
    <button name="intent" value="draft" class="secondary status-button" formnovalidate>
      <span class="status-dot is-draft" aria-hidden="true"></span>
      Save draft
    </button>
    <button name="intent" value="publish">Publish job</button>
  </section>
</form>

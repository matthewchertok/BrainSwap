<script lang="ts">
  import { dateTimeLocalToIso } from '$lib/ui';
  import { JOB_TOOLS } from '$lib/validation';

  let { form } = $props();
  let deadlineLocal = $state('');
  let deadlineIso = $derived(dateTimeLocalToIso(deadlineLocal));
</script>

<div class="title-row">
  <div>
    <h1>Post a job</h1>
    <p>Start with whatever you know. You can finish a draft later.</p>
  </div>
</div>

{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}

<form method="POST" class="job-form">
  <fieldset>
    <legend>Task</legend>
    <label>Title<input name="title" maxlength="120" /></label>
    <label>Task summary<textarea name="task_summary" rows="4" maxlength="1000"></textarea></label>
    <label>Prompt<textarea name="prompt" rows="10" maxlength="100000"></textarea></label>
    <label
      >Link to chat (optional)<input
        type="url"
        name="chat_url"
        maxlength="2048"
        placeholder="https://chatgpt.com/share/…"
      /></label
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
    <fieldset class="nested">
      <legend>Required tools (optional)</legend>
      {#each JOB_TOOLS as tool}<label><input type="checkbox" name="required_tools" value={tool} />{tool}</label>{/each}
    </fieldset>
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

  <section class="actions form-actions">
    <button name="intent" value="draft" class="secondary status-button" formnovalidate>
      <span class="status-dot is-draft" aria-hidden="true"></span>
      Save draft
    </button>
    <button name="intent" value="publish">Publish job</button>
  </section>
</form>

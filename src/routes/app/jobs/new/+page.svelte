<script lang="ts">
  import { dateTimeLocalToIso } from '$lib/ui';

  let { data, form } = $props();
  let deadlineLocal = $state('');
  let deadlineIso = $derived(dateTimeLocalToIso(deadlineLocal));
  const tools = [
    'Web access',
    'Deep research',
    'Code execution',
    'Image understanding',
    'PDF understanding',
    'File generation',
    'Other'
  ];
</script>

<div class="title-row">
  <div>
    <h1>Post a job</h1>
    <p>Creates a private draft before publishing.</p>
  </div>
</div>
{#if form?.message}<p class="error" role="alert">{form.message}</p>{/if}
<form method="POST" class="job-form">
  <fieldset>
    <legend>Task</legend>
    <p class="notice">
      <strong>Visible lab-wide:</strong> title and listing summary are visible to every active member, even for sealed jobs.
    </p>
    <label>Title<input name="title" required maxlength="120" /></label><label
      >Lab-visible listing summary<textarea name="listing_summary" required maxlength="1000"></textarea></label
    ><label>Exact current task<textarea name="current_task" required rows="8" maxlength="100000"></textarea></label
    ><label>Definition of done<textarea name="success_criteria" required maxlength="25000"></textarea></label><label
      >Desired output format<textarea name="output_format" required maxlength="10000"></textarea></label
    ><label
      >Prior context<textarea
        name="prior_context"
        rows="8"
        maxlength="250000"
        placeholder="Relevant prior work or model output"></textarea></label
    ><label
      >Institutional or shared links<textarea
        name="external_urls"
        rows="3"
        maxlength="20480"
        placeholder="One HTTPS URL per line"></textarea></label
    >
  </fieldset>
  <fieldset>
    <legend>Execution</legend><label
      >Preferred model<select name="preferred_model_id" required
        ><option value="">Choose…</option>{#each data.models as m}<option value={m.id}>{m.display_name}</option
          >{/each}</select
      ></label
    >
    <fieldset class="nested">
      <legend>Other acceptable models</legend>
      {#each data.models as m}<label
          ><input type="checkbox" name="acceptable_model_ids" value={m.id} />{m.display_name}</label
        >{/each}
    </fieldset>
    <div class="checks">
      <span>Required tools</span>{#each tools as tool}<label
          ><input type="checkbox" name="required_tools" value={tool} />{tool}</label
        >{/each}
    </div>
    <label
      >Effort<select name="effort"
        ><option value="quick">Quick, under 5 minutes</option><option value="medium">Medium, 5–20 minutes</option
        ><option value="heavy">Heavy, over 20 minutes</option></select
      ></label
    ><label
      >Deadline (optional)<input
        type="datetime-local"
        name="deadline_local"
        bind:value={deadlineLocal}
        step="60"
        aria-describedby="deadline-help"
      /></label
    >
    <input type="hidden" name="deadline" value={deadlineIso} />
    <p id="deadline-help">Choose the date and time in your device's local timezone.</p>
    <label
      >Visibility<select name="visibility"
        ><option value="claimed_only">Sealed until claimed</option><option value="lab">Lab-visible</option></select
      ></label
    >
  </fieldset>
  <fieldset>
    <legend>Data handling</legend><label
      >Sensitivity<select name="sensitivity"
        ><option value="general">General</option><option value="unpublished">Unpublished</option><option
          value="collaborator">Collaborator</option
        ><option value="other">Other</option></select
      ></label
    ><label>Sensitivity notes<textarea name="sensitivity_notes" maxlength="10000"></textarea></label>
    <p class="danger">
      Never include passwords, keys, tokens, PHI, restricted human-subject data, export-controlled data,
      personnel/student records, or unauthorized collaborator material.
    </p>
    <label class="ack"
      ><input type="checkbox" name="acknowledged" value="yes" required />I am authorized to share this with eligible
      helpers and the selected provider; I understand provider retention may differ and output needs human verification.</label
    >
  </fieldset>
  <section class="actions">
    <button name="intent" value="draft" class="secondary">Save draft</button><button name="intent" value="publish"
      >Create and publish now</button
    >
  </section>
</form>

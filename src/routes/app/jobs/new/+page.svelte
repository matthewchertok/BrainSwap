<script lang="ts">
  let { data, form } = $props();
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
    ><label>Exact current task<textarea name="current_task" required rows="8"></textarea></label><label
      >Definition of done<textarea name="success_criteria" required></textarea></label
    ><label>Desired output format<textarea name="output_format" required></textarea></label>
  </fieldset>
  <fieldset>
    <legend>Execution</legend><label
      >Preferred model<select name="preferred_model_id" required
        ><option value="">Choose…</option>{#each data.models as m}<option value={m.id}>{m.display_name}</option
          >{/each}</select
      ></label
    >
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
    ><label>Sensitivity notes<textarea name="sensitivity_notes"></textarea></label>
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
      >Publish job</button
    >
  </section>
</form>

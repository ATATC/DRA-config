---
name: harvest
description: Discover finished SLURM experiments, resolve their final status from sacct, update each run's metadata.yaml, and write a human-readable results narrative in the project's style. Asks for confirmation before writing (skip with --auto, safe for /loop). Use to collect results after jobs run.
argument-hint: "[--auto] [run_code]"
allowed-tools: Bash(sacct *), Bash(scontrol *), Bash(squeue *), Bash(ssh *), Bash(ls *), Bash(tail *), Bash(cat *), Bash(jq *), Bash(find *), Bash(date *), Bash(hostname *), Read, Edit, Write, Glob, Grep
---

# Harvest Experiment Results

Two artifacts per run:

- **`experiment/<run_code>/metadata.yaml`** — the *metadata* (status, provenance, metrics). The
  **single source of truth**. Status lives here and is **never parsed from prose**.
- **`docs/experiments/<run_code>.md`** — the human *narrative* (Goal / Setup / Results /
  Observations). `md = the story, yaml = the metadata`.

`docs/experiments.md` is a **derived index** regenerated from all `metadata.yaml`. This skill
resolves status from `sacct`, updates the yaml, fills the narrative md in the project's reporting
style, and rebuilds the index. Canonical layout + schema: the `submit-experiment` skill's
`references/experiment-layout.md`.

## Arguments

- no args → resolve every run whose `metadata.yaml` `status` is `submitted` or `running`.
- `--auto` → skip the confirmation prompt (safe for `/loop`).
- `<run_code>` → only that run.

## Step 0 — Learn project context & reporting style

Adapt to the project instead of imposing a format:

1. **Read the project's `CLAUDE.md`** for: where result files live and their format, which metrics
   matter (accuracy / loss / F1 / DSC / …), any post-processing/summary command, log locations.
2. **Read 1–2 existing *completed* `docs/experiments/<run_code>.md`** (ones with real Results, not
   "Pending") to match the reporting style — tables vs bullets, metric formatting, observation voice.
3. If neither exists, collect whatever quantitative results you find and pick a clean default.

## Step 1 — Discover open runs (metadata.yaml = SSOT)

```bash
for m in experiment/*/metadata.yaml; do
  grep -qE '^status:[[:space:]]*(submitted|running)' "$m" && echo "$m"
done
```

Read each open run's `metadata.yaml` (Read tool — do not regex-extract fields you will overwrite)
for its `slurm_job_ids` and `run_code`. A `<RUN_DIR>/exp_log/.done.json` marker, if present, is a
discovery/fallback hint. If a `<run_code>` arg was given, restrict to it.

## Step 2 — Resolve status from sacct (authoritative)

Query the most recent job id; `-X` for a clean terminal state; handle empty output:

```bash
sacct -X -j <JOB_ID> --format=State%20,ExitCode,Elapsed,End --noheader --parsable2 2>/dev/null
```

On a laptop, run it over `ssh fir.alliancecan.ca "<sacct …>"`.

**Status precedence:**

1. Non-empty `sacct` terminal state is authoritative: `COMPLETED|FAILED|TIMEOUT|CANCELLED|OUT_OF_MEMORY|NODE_FAIL` → `completed|failed|timeout|cancelled|oom|failed`.
2. `RUNNING`/`PENDING` → leave `running`/`submitted`; skip (report "still running/pending").
3. `sacct` **empty** (purged / cross-cluster / sacct down) → fall back to `exp_log/.done.json`
   (`{"status": …}`). If neither resolves, leave status unchanged and report "unresolved".

Never guess a terminal state; only write one you actually resolved.

## Step 3 — Collect results (strategy depends on outcome)

**COMPLETED:** read the run's narrative md Goal/Setup for what to look for; find result files via
the project's `CLAUDE.md` paths (`results/`, `output/`, a JSON, …); read the log tail
(`tail -50 experiment/<run_code>/exp_log/logs/*.out`) for inline metrics, timing, checkpoint path.
Extract the primary metric in the project's format. Note `checkpoint` / `wandb_run_id` if present.

**FAILED / TIMEOUT / CANCELLED / OUT_OF_MEMORY:** read `.out` and `.err` tails (last 50) for the
error; `sacct -j <id> --format=State,ExitCode,MaxRSS,Elapsed --noheader --parsable2` for usage;
check for partial results; summarize the failure reason. Do not fabricate metrics.

## Step 4 — Update both artifacts

**4a. `metadata.yaml` (SSOT):** set `status`, `finished_at` (the `End` time or now, ISO-8601),
and `best_metric: {name, value, epoch}` when a metric is discoverable. For failures, record a
one-line reason in `notes`.

**4b. `docs/experiments/<run_code>.md` (narrative):** create it if missing. Fill the `## Results`
section (table/bullets in the learned style) — for failures, a brief failure description; write
1–2 `## Observations` sentences interpreting the result against the run's `objective.goal` and
`decision_rule`. Do **not** write a status line in the prose — status lives in `metadata.yaml` and
appears in the derived index.

**4c. Post-processing:** if `CLAUDE.md` specifies a results-summary command, run it.

## Step 5 — Regenerate the index (derived, locked)

Rebuild `docs/experiments.md` **from** the `metadata.yaml` files so it can never drift:

```bash
exec 9>docs/.experiments.lock && flock 9 || { echo "another harvest is running"; exit 0; }
```

Write it fresh (overwrite, never append): a header plus one row per `experiment/*/metadata.yaml`,
sorted by `started_at`, each showing `run_code`, `status`, key result (`best_metric`), the one-line
`objective.goal`, and a link to `docs/experiments/<run_code>.md`.

## Step 6 — Report

```
Harvested N run(s):
  <run_code> (job <id>) — COMPLETED   best=<metric>:<value>
  <run_code> (job <id>) — FAILED      OOM
Still open: M (running/pending/unresolved)
```

If `--auto` was not passed, show the Step 1 discovery summary and confirm before writing.

## Notes & edge cases

- **No markdown parsing for state** — status lives only in `metadata.yaml`.
- **Idempotent** — re-running touches only `submitted`/`running` runs; resolved runs are skipped.
- **Environment**: login node = full access; local/laptop = `sacct` over `ssh`, else rely on
  markers/result files.
- **No result files**: update status, leave Results as "No results produced."
- **Multiple jobs for one run**: use the most recent (highest) job id.
- **`.done.json`** (optional): `experiment/<run_code>/exp_log/.done.json`
  (`{"status","finished_at","best_metric"}`) lets harvest resolve without `sacct`. Fallback, not SSOT.

---
name: harvest
description: Discover finished SLURM experiments, resolve their final status from sacct, update each run's metadata.yaml (the source of truth), and regenerate the docs/experiments.md index. Use to collect results after jobs run.
argument-hint: "[--auto] [run_code]"
allowed-tools: Bash(sacct *), Bash(squeue *), Bash(ssh *), Bash(ls *), Bash(tail *), Bash(cat *), Bash(find *), Bash(date *), Bash(hostname *), Read, Edit, Write, Glob, Grep
---

# Harvest Experiment Results

Resolve the status of submitted experiments and refresh their records. **`metadata.yaml` in each
`experiment/<run_code>/` folder is the single source of truth.** This skill reads it, updates it
from `sacct`, and then *regenerates* the human-readable `docs/experiments.md` index from all
`metadata.yaml` files. The markdown index is a derived view — it is never parsed for truth and
never the place a status is stored.

The canonical layout + full `metadata.yaml` schema (durable vs scratch artifacts, core/optional
fields) is defined in the `submit-experiment` skill's `references/experiment-layout.md` — follow
that, and resolve only fields it defines.

## Arguments

- no args → resolve every run whose `status` is `submitted` or `running`.
- `--auto` → skip the confirmation prompt (safe for `/loop`).
- `<run_code>` → only that run.

## Step 0 — Discover open runs

```bash
for m in experiment/*/metadata.yaml; do
  grep -qE '^status:[[:space:]]*(submitted|running)' "$m" && echo "$m"
done
```

Read each open run's `metadata.yaml` for its `slurm_job_ids` and `run_code`. (Read with the Read
tool — do not regex-extract fields you intend to overwrite.)

## Step 1 — Resolve status from sacct (authoritative)

For each open run, query the most recent job id. Use `-X` (allocation only) for a clean terminal
state, and handle empty output:

```bash
sacct -X -j <JOB_ID> --format=State%20,ExitCode,Elapsed,End --noheader --parsable2 2>/dev/null
```

If you are on a laptop, run it over `ssh fir.alliancecan.ca "<sacct …>"`.

**Status precedence (conflict rule):**

1. A non-empty `sacct` terminal state is authoritative: `COMPLETED|FAILED|TIMEOUT|CANCELLED|OUT_OF_MEMORY|NODE_FAIL` → map to `completed|failed|timeout|cancelled|oom|failed`.
2. `RUNNING`/`PENDING` → leave `status: running`/`submitted`; skip (report "still running/pending").
3. If `sacct` returns **empty** (old job purged, cross-cluster, sacct down): fall back to a
   `<RUN_DIR>/exp_log/.done.json` marker if present (`{"status": …}`). If neither resolves,
   leave the status unchanged and report "unresolved — could not reach sacct".

Never guess a terminal state; only write one you actually resolved.

## Step 2 — Update each run's metadata.yaml (SSOT)

For a resolved run, edit `experiment/<run_code>/metadata.yaml`:

- set `status:` to the resolved value,
- set `finished_at:` to the `End` time (or now, ISO 8601),
- if a primary metric is discoverable (job log tail, a results file named in the run, or a
  `.done.json` field), set `best_metric: { name: …, value: … }`.

Read the log tail for context / metrics:

```bash
tail -50 experiment/<run_code>/exp_log/logs/*.out 2>/dev/null
tail -50 experiment/<run_code>/exp_log/logs/*.err 2>/dev/null   # for failures
```

For failures, record a one-line reason in `notes` (e.g. OOM at epoch N). Do not fabricate metrics.

## Step 3 — Regenerate the index (derived view, with a lock)

After all `metadata.yaml` updates, rebuild `docs/experiments.md` **from** the metadata files so
the index can never drift from the truth. Guard against concurrent `/harvest` runs with a simple
lock:

```bash
exec 9>docs/.experiments.lock && flock 9 || { echo "another harvest is running"; exit 0; }
```

Then write `docs/experiments.md` fresh: a header plus one row per `experiment/*/metadata.yaml`,
sorted (e.g. by `started_at`), each line showing `run_code`, `status`, the key result
(`best_metric`), and the one-line `objective.goal`. Overwrite the file entirely — do not append.

## Step 4 — Report

```
Harvested N run(s):
  <run_code> (job <id>) — COMPLETED   best=<metric>:<value>
  <run_code> (job <id>) — FAILED      OOM
Still open: M (running/pending/unresolved)
```

If `--auto` was not passed, show the discovery summary in Step 0 and confirm before writing.

## Notes

- **No markdown parsing for state** — status lives only in `metadata.yaml`. This removes the
  brittle "parse `Status: Submitted` from prose" failure mode.
- **Idempotent**: re-running only touches runs still `submitted`/`running`; resolved runs are
  skipped.
- **`.done.json` marker (optional)**: a job script may write
  `experiment/<run_code>/exp_log/.done.json` (`{"status": "...", "finished_at": "...",
  "best_metric": {...}}`) so harvest can resolve without sacct. It is a fallback, not the SSOT.

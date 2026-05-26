---
name: submit-experiment
description: Submit a SLURM experiment on Alliance Canada (Fir) with a per-run folder, a metadata.yaml single source of truth (status + git provenance + objective), and a config/script snapshot. Infers the objective/decision_rule and waits for explicit user confirmation — will not write or sbatch until you confirm the draft. Use when launching a tracked experiment.
argument-hint: "<job_type> <run_config_or_script> [purpose description]"
allowed-tools: Bash(sbatch *), Bash(salloc *), Bash(srun *), Bash(seff *), Bash(squeue *), Bash(tail *), Bash(ssh *), Bash(git *), Bash(ls *), Bash(cat *), Bash(cp *), Bash(mkdir *), Bash(hostname *), Bash(date *), Read, Edit, Write, Glob, Grep
---

# Submit Experiment

Submit a SLURM job with a reproducible record. Each run gets its own folder containing a config
snapshot, the submit script, and a `metadata.yaml` that is the **single source of truth** for
status, git provenance, and the experiment's objective. Human-readable indexes are *derived*
from `metadata.yaml` (by `/harvest`), never the other way around.

## Arguments

- `$1` — job type (e.g. `sft`, `eval`, `pretrain` — project-defined).
- `$2` — run config or job-script path.
- Remaining text — free-form purpose.

**Infer, don't interrogate.** Derive what you can from the config, the conversation, and the
parent run's `metadata.yaml`; only ask for what you genuinely cannot infer. Present a complete
draft in Step 6 and let the user confirm or correct — never make them fill every field.

## Step 0 — Discover project context

Read the project's `CLAUDE.md` and scan for: the submit script / `sbatch` entry, the config
directory (`configs/`, `runs/`, …), and the experiment root. Default experiment root is
`experiment/`. If it does not exist, this is a fresh project — create `experiment/` and an empty
`docs/experiments.md` (the derived index, written by `/harvest`).

## Step 1 — Read prior runs (naming + dedup)

```bash
ls experiment/*/metadata.yaml 2>/dev/null
```

Note the naming convention already in use and avoid collisions.

## Step 2 — Read the run config

Read `$2` and extract: task/model, key hyperparameters, and resource requests (GPU profile,
count, mem, time). For Fir, the GPU is `--gpus-per-node=<gpu_type>:<count>` (full `h100` or a MIG
slice); see the `slurm-job` / `ccdb-clusters` skills.

## Step 2.5 — Optional: smoke test to size resources

Under-provisioned `--mem` is the most common Fir failure mode (jobs that run near 100% memory
often OOM or get cancelled). Before committing the full run, **ask the user** whether they want a
quick smoke test to measure real needs — especially for a new job type or an untested config:

> Run a smoke test first to size memory/GPU/time? (recommended for a new job type or config)

If yes, run the real job at reduced scale (a few steps / a tiny subset) in a short interactive
session — or one-shot with `srun` — then read the peaks:

```bash
salloc --account=<account> --gpus-per-node=<gpu_type>:1 --cpus-per-task=8 --mem=32G --time=1:00:00
# inside the allocation, run the job briefly, then measure:
/usr/bin/time -v <cmd>                                          # peak RSS = "Maximum resident set size"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv    # peak GPU memory
```

Set the real job from the observed peaks: `--mem` = peak RSS + ~20% headroom; GPU profile = full
`h100` vs a MIG slice (`*_1g.10gb` / `*_2g.20gb` / `*_3g.40gb`) when peak GPU memory is small;
`--time` from the smoke-test rate. Skip this for a re-run of an already-sized job. `/slurm-debug`
and `/slurm-seff-report` help interpret a prior run's `seff`.

## Step 3 — Local vs remote execution

```bash
hostname -f
```

- On the target cluster login node (`*.alliancecan.ca`) → submit **locally**.
- On a laptop / local machine → submit **remotely** over `ssh fir.alliancecan.ca "<command>"`
  (the `~/.ssh/config` host + key set up once by `/onboard`). If `ssh fir.alliancecan.ca` is not
  working, stop and have the user run `/connect` (or `/onboard` for first-time setup). Do not
  collect passwords / Duo in chat.

## Step 4 — Infer run_code, tags, and the objective (a draft to confirm)

Derive a draft — do not quiz the user field-by-field:

- `run_code`: unique, filesystem-safe, following the project convention (scan `experiment/*/`).
  Default `<job_type>-<descriptor>-<slug>` (lowercase, hyphens).
- `tags`: job type + descriptor + purpose keywords.
- `objective.goal`, `expected_result {metric, value, rationale}`, `decision_rule`: **infer** from
  the config (what changed vs the parent), the conversation, and the **parent run's
  `metadata.yaml`** (its result is usually the expected baseline). If this forks a prior run, set
  `parent_run`.
- Optional scientific fields (`hypothesis`, `assumptions`, …) only if the user actually expressed them.

The user fills any gaps at the Step 6 confirm — not through an upfront questionnaire.

## Step 5 — Capture git provenance (do NOT skip)

```bash
git rev-parse HEAD                 # full commit SHA
git status --porcelain            # empty => clean; non-empty => dirty
```

Record both. If the working tree is **dirty**, warn the user in Step 6 — the recorded commit
will not fully reproduce the run unless they commit first. (Record `dirty: true`; never claim a
clean provenance when it is not.) When dirty, you will also save the working-tree diff to the run
folder in Step 7 (`git.diff`) so the run stays reproducible.

## Step 6 — Confirm the draft (the gate)

Show the full **inferred** draft: `run_code`, tags, cluster, execution mode, account,
GPU/resources, and the **objective + expected_result + decision_rule you inferred**, plus a
**⚠ dirty working tree** warning if applicable. Ask the user to confirm or correct — this single
gate is where they adjust the inference, not an upfront questionnaire. Wait for explicit
confirmation before submitting (the gate, not metadata, prevents unwanted submits; the skill stays
model-invocable by design).

## Step 7 — Create the run folder + write metadata.yaml

The canonical layout + full `metadata.yaml` schema (with a complete example) is in
`references/experiment-layout.md`. Snapshot the small, durable inputs; **reference** (don't copy)
the large scratch artifacts (checkpoints / tensorboard / wandb).

```bash
RUN_DIR="experiment/<run_code>"
mkdir -p "$RUN_DIR"
cp "$2" "$RUN_DIR/config.yaml"                          # input config snapshot
[ -f <resolved_config> ] && cp <resolved_config> "$RUN_DIR/config_resolved.yaml"  # resolved config, if produced
cp <job_script> "$RUN_DIR/"                             # submit script(s): smoke / train / local
[ "<dirty>" = true ] && git diff > "$RUN_DIR/git.diff"  # save diff so a dirty run is reproducible
```

Write `$RUN_DIR/metadata.yaml`. **Core + reproducibility** (always sensible):

```yaml
run_code: <run_code>
status: submitted          # submitted|running|completed|failed|timeout|cancelled|oom
tags: [<job_type>, <descriptor>, <keywords>]
cluster: fir
account: <account>
git:
  commit: <full SHA>
  dirty: true|false
  diff_path: git.diff|null       # set when dirty
slurm_job_ids: []                # filled in Step 8
started_at: <ISO 8601>
finished_at: null
objective:
  goal: <one-line goal>
  expected_result: { metric: <name>, value: <number>, rationale: <why> }
decision_rule: <what each outcome (above/at/below expected) will mean>
best_metric: { name: null, value: null, epoch: null }
notes: <free text — purpose, key hyperparameters>
# reproducibility — fill what applies:
base_checkpoint: { path: <path>, sha256: <hash> }
data_split_version: <tag>
env_hash: <hash>
wandb_run_id: <id|null>
```

**Optional scientific / lineage fields** — `parent_run`, `superseded_by`, `stage`, `base`,
`hypothesis`, `assumptions`, `objective.expected_intermediate_signals` — add as the work warrants;
the complete annotated example is in `references/experiment-layout.md`.

Then create the **narrative stub** `docs/experiments/<run_code>.md` (the `md` half — the story):
a `# <run_code>` title, `## Goal` + `## Setup` filled from the confirmed objective and config, and
`## Results` / `## Observations` marked _Pending — filled by `/harvest`_. Keep status out of the
prose; status lives only in `metadata.yaml`.

## Step 8 — Submit

Local: `cd <project_root> && sbatch <job_script>`. Remote: sync code if the remote is a git
checkout (`git push`; `ssh fir.alliancecan.ca "cd <remote_path> && git pull"`), then
`ssh fir.alliancecan.ca "cd <remote_path> && sbatch <job_script>"`. Capture the job id from
`Submitted batch job <id>` and append it to `slurm_job_ids` in `metadata.yaml`.

## Step 9 — Report

Print `run_code`, job id, cluster, execution mode, `metadata.yaml` path, and the log-tail command
(`tail -f <RUN_DIR>/exp_log/logs/*.out`, or the `ssh fir.alliancecan.ca "tail …"` form when remote).

## Notes

- **`sbatch` runs on a login/submit node** — never a compute node, never locally for a cluster
  target (use the remote SSH path).
- **markdown is derived**: `/harvest` regenerates `docs/experiments.md` from all `metadata.yaml`
  files. Do not hand-edit the index as if it were the source.
- Optional discipline hook (reminds users to use `/submit-experiment` instead of bare `sbatch`)
  can live in `~/.claude/settings.local.json`; re-run `./setup.sh` after editing.

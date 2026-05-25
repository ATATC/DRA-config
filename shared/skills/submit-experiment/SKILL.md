---
name: submit-experiment
description: Submit a SLURM experiment with proper naming, documentation, and cross-cluster support. Reads project context to discover submission infrastructure.
argument-hint: "<job_type> <run_config_or_script> [purpose description]"
allowed-tools: Bash(sbatch *), Bash(squeue *), Bash(tail *), Bash(ssh *), Bash(git *), Bash(ls *), Bash(cat *), Bash(hostname *), Read, Edit, Write, Glob, Grep
---

# Submit Experiment

Submit a SLURM job with proper experiment naming, documentation, and cross-cluster support. This skill enforces experiment discipline: every run gets a unique name, structured documentation, and a reproducible record.

## Arguments

- `$ARGUMENTS[0]` — job type (e.g. `sft`, `grpo`, `eval`, `pretrain` — project-defined)
- `$ARGUMENTS[1]` — run config or job script path
- Remaining text — free-form description of the experiment's purpose

If arguments are missing, ask the user.

## Workflow

### Step 0: Discover project context

Before anything else, understand how this project submits experiments:

1. **Read the project's `CLAUDE.md`** (repo root). Look for:
   - Submission script path and its argument structure
   - Supported job types
   - Run config directory (e.g. `configs/`, `runs/`, `jobs/`)
   - Special environment variables the submission script expects
   - Any special submission instructions

2. **Scan the directory structure** if CLAUDE.md doesn't specify:
   - Look for submission scripts: `submit.sh`, `run.sh`, `slurm/submit.sh`, `scripts/submit.sh`
   - Look for config directories: `configs/`, `runs/`, `jobs/`, `experiments/`
   - Look for `docs/experiments.md` (existing experiment tracking)

3. **Bootstrap if needed**: If `docs/experiments.md` does not exist, this is a fresh project. Create it:
   ```markdown
   # Experiments

   <!-- Index of experiments. Each entry points to a detail file in experiments/. -->
   <!-- Keep entries <100 words. Focus on what, why, and the key takeaway. -->
   ```
   Also create `docs/experiments/` directory.

4. If no submission infrastructure is found, ask the user: "How do you submit experiments? (wrapper script, raw sbatch, etc.)"

### Step 1: Read prior experiments

Read `docs/experiments.md` to:
- Check for duplicate names
- Understand naming conventions already in use
- See what's been tried

### Step 2: Read the run config

Read the run config file to extract key parameters. The format varies by project — it may be:
- A shell script with variable assignments (`PARTITION=`, `GPUS=`, `MODEL=`, etc.)
- A YAML/JSON config file
- A Python config
- A raw sbatch script with `#SBATCH` directives

Extract: model/task name, key hyperparameters, resource requests (partition, GPUs, memory, time limit), and any experiment-defining settings.

### Step 3: Detect target cluster and execution mode

Determine the target cluster from the partition value in the config, then decide whether submission should happen locally or remotely.

1. Check the partition against the cluster-partition tables in the injected global cluster docs.
2. Detect the current execution environment:
   ```bash
   hostname -f
   ```
3. Apply this decision rule:
   - If the current hostname is already on the target cluster login node, use **local submission**.
   - If the target cluster is **Fir** and the current hostname does **not** look like Fir, Great Lakes, or Lighthouse, treat the current machine as a **local machine / laptop** and use **remote Fir submission** over:
     ```bash
     ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca "<command>"
     ```
   - If the current hostname is Great Lakes and the target is Lighthouse, or the current hostname is Lighthouse and the target is Great Lakes, use the existing **remote socket submission** path.
   - Otherwise, ask the user how they reach the target cluster before proceeding.

#### Remote Fir pre-check

Before the first remote Fir SSH command in a workflow:

- ask the user for their DUO passcode
- tell them the SSH login may prompt interactively for it

Then verify remote Fir access:

```bash
ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca "hostname -f && whoami && sinfo --version 2>&1"
```

#### Great Lakes / Lighthouse remote pre-check

If using the cross-cluster socket path, verify it first:

```bash
ssh -O check -o ControlPath=~/.ssh/ctrl-lighthouse lighthouse.arc-ts.umich.edu 2>&1
```

If the control socket is dead, tell the user to re-establish it and do not proceed until it is active.

### Step 4: Generate experiment name and tags

**Name format**: `{job_type}-{descriptor}-{slug}`

Examples:
- `sft-llama7b-baseline`
- `eval-gpt4o-zeroshot`
- `pretrain-bert-large-v2`
- `grpo-qwen0.6b-reward-v2`

Rules:
- Lowercase, hyphens only (no underscores)
- Descriptor: derived from model name, dataset, or task
- Slug: brief, descriptive (from user's purpose description or inferred from config)
- Must not duplicate any name in `docs/experiments.md`

**Tags** (comma-separated): job type + descriptor + purpose keywords.
Example: `sft,llama-7b,baseline`

### Step 5: Confirm with user

Show:
- **Experiment name**: the generated name
- **Tags**: the tags
- **Cluster**: target cluster
- **Execution mode**: local, remote over SSH to Fir, or remote over cross-cluster socket
- **Config summary**: key hyperparams and resources
- **Purpose**: the description

Ask for confirmation before submitting.

### Step 6: Submit

Use the submission method discovered in Step 0.

**Local submission** (with wrapper script):
```bash
cd <project_root>
EXPERIMENT_NAME=<name> EXPERIMENT_TAGS=<tags> <submission_command>
```

**Local submission** (raw sbatch, no wrapper):
```bash
cd <project_root>
EXPERIMENT_NAME=<name> EXPERIMENT_TAGS=<tags> sbatch <job_script>
```

**Remote submission** (Great Lakes <-> Lighthouse socket path):
```bash
# Sync code
cd <project_root>
git push 2>&1
ssh -o ControlPath=~/.ssh/ctrl-lighthouse <remote_host> \
    "cd <remote_project_path> && git pull" 2>&1

# Submit remotely
ssh -o ControlPath=~/.ssh/ctrl-lighthouse <remote_host> \
    "cd <remote_project_path> && mkdir -p logs && EXPERIMENT_NAME=<name> EXPERIMENT_TAGS=<tags> <submission_command>" 2>&1
```

**Remote submission** (local machine / laptop -> Fir):

Before the first SSH command, ask the user for their DUO passcode.

```bash
# Sync code if the remote project is a git checkout
cd <project_root>
git push 2>&1
ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca \
    "cd <remote_project_path> && git pull" 2>&1

# Submit remotely on Fir
ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca \
    "cd <remote_project_path> && mkdir -p logs && EXPERIMENT_NAME=<name> EXPERIMENT_TAGS=<tags> <submission_command>" 2>&1
```

If the remote Fir project path is not obvious, ask the user before submitting. Do not guess a remote checkout path.

Capture the SLURM job ID from the `sbatch` output (format: `Submitted batch job 12345678`).

### Step 7: Log to experiments

Two files must be written:

#### 7a. Create detail file

Create `docs/experiments/<date>_<name>.md`:

```markdown
# {EXPERIMENT_NAME}

**Date**: {YYYY-MM-DD}
**Status**: Submitted
**Job ID**: {slurm_job_id}
**Cluster**: {cluster name}
**Commit**: {git rev-parse --short HEAD}

## Goal

{purpose description}

## Setup

- **Model**: {model name from config}
- **GPUs**: {gpu_count}x {gpu_type} ({partition}, {account})
- **Config**: `{config_file_path}`
- **Key hyperparams**: {lr, steps/epochs, batch, etc. — whatever is relevant}
- **Job type**: {job_type}

## Results

Pending.

## Observations

_To be filled on completion._

## Reproduce

```bash
/submit-experiment {job_type} {config_path} {purpose}
```
```

#### 7b. Append index entry

Append a bullet to `docs/experiments.md`:

```markdown
- **{EXPERIMENT_NAME}** ({descriptor}): {one-line goal}.
  [detail](experiments/{date}_{name}.md)
```

Keep the entry under 100 words. If no appropriate section exists, create one.

### Step 8: Report

Print:
- Job ID
- Cluster name
- Execution mode
- Detail file path
- Log monitoring command:
  - Local: `tail -f logs/{EXPERIMENT_NAME}_{job_id}.out`
  - Remote via socket: `ssh -o ControlPath=~/.ssh/ctrl-<cluster> <host> "tail -50 <project>/logs/{EXPERIMENT_NAME}_{job_id}.out"`
  - Remote via Fir SSH: `ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca "tail -50 <remote_project_path>/logs/{EXPERIMENT_NAME}_{job_id}.out"`

## Environment check

`sbatch` must run on a login or submit node. If the hostname indicates a compute node (for example `SLURM_JOB_ID` is set), warn the user. If the current host is a local machine or laptop, do not attempt to run `sbatch` locally for a cluster target; use the appropriate remote SSH path instead.

## Tip: Enforcing submission discipline

Projects can add a PreToolUse hook to `~/.claude/settings.local.json` that reminds users to use `/submit-experiment` instead of direct `sbatch`. After editing, re-run `./setup.sh` to apply:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "INPUT=$(cat); CMD=$(echo \"$INPUT\" | jq -r '.tool_input.command // \"\"'); if echo \"$CMD\" | grep -qE '^sbatch\\s|;\\s*sbatch\\s|&&\\s*sbatch\\s'; then echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"REMINDER: Use /submit-experiment to submit jobs. It handles naming, tagging, and documentation.\"}}'; fi",
        "timeout": 5
      }]
    }]
  }
}
```

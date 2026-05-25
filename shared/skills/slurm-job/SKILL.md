---
name: slurm-job
description: Create or modify an sbatch job script with correct Alliance Canada (Fir) directives — account, GPU profile, resource requests, and best-practice defaults. Use when writing or editing a .sh/.slurm job script.
allowed-tools: Bash(sinfo *), Bash(sshare *), Bash(sacctmgr *), Bash(whoami), Bash(hostname *), Bash(cat *), Bash(ls *), Read, Edit, Write, Glob, Grep
---

# Create / Modify an Sbatch Job Script (Alliance Canada)

Help the user produce a correct, ready-to-submit sbatch script for an Alliance Canada cluster
(Fir by default). For GPU sizing / break-even, MAX_TRES billing, and storage tables, consult the
`ccdb-clusters` skill's `references/` — do not re-derive them here.

## Modifying an existing script

If the user points to an existing `.sh` / `.slurm` file, read it and adjust GPU profile, account,
resource requests, directives, or logging using the same rules below.

## Creating a new script

### 1. Gather requirements (combine into one question)

- What does the job do (train / infer / preprocess)?
- GPU need → pick the **smallest Fir profile that fits**: `nvidia_h100_80gb_hbm3_1g.10gb` (10 GB),
  `…_2g.20gb` (20 GB), `…_3g.40gb` (40 GB), or full `h100` (80 GB). Default to a MIG slice unless
  the model needs >40 GB VRAM or the job is ≥1 day.
- GPU count, wall time, job name, and where to save the script.

### 2. Pick the account

```bash
whoami
sshare -U -l --parsable2 | head
```

Use the `ccdb-clusters` skill's `pick-gpu-account.sh` to choose the highest-FairShare GPU account
(it prefers RRG/RPP). Accounts look like `def-<pi>_gpu` / `rrg-<pi>_gpu`; use `def-<pi>_cpu` for
CPU-only jobs.

### 3. Generate the script (Fir directive style)

```bash
#!/bin/bash
#SBATCH --job-name=<job_name>
#SBATCH --account=<account>
#SBATCH --gpus-per-node=<gpu_type>:<count>
#SBATCH --cpus-per-task=<cpus>
#SBATCH --mem=<memory>
#SBATCH --time=<time>
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail
mkdir -p logs
echo "Job $SLURM_JOB_ID on $(hostname) — $(date)"

# module load python/3.11.5 cuda/12.6   # uncomment as needed
# source <venv>/bin/activate

<user_command>
```

**Fir GPU rule**: choose the GPU only with `--gpus-per-node=<gpu_type>:<count>`. Never use
`--partition`, `--gres`, or `--constraint`. Match CPUs to the GPU break-even (1 / 3 / 5 / 12 for
1g / 2g / 3g / full H100 — see `ccdb-clusters/references/clusters/fir.md`); over-requesting CPUs
flips billing to the CPU rate.

### Best practices

1. **Logs** → `logs/%x_%j.out|err` (`%x` = job name, `%j` = job id).
2. `set -euo pipefail` at the top.
3. Print job id / host / date so logs are debuggable.
4. Always set `--time`; smoke-test on the smallest profile before the full run.
5. **Storage**: write large outputs to `$SCRATCH` or `$PROJECT`, never `$HOME`. For many-small-file
   I/O, stage to node-local `$SLURM_TMPDIR` and copy results back before the job exits — see
   `ccdb-clusters/references/storage.md` for the recipe and the Fir `$SLURM_TMPDIR` fallback.
   Scratch is purged (~60 days); keep durable data in `$PROJECT`.
6. After the run, `seff <jobid>` and trim over-requested CPU / mem / time / GPU.

### 4. Present and remind

Show the complete script, explain non-obvious choices, and write it to the requested path
(default `./job.sh`). Submit with `sbatch <script>.sh`; monitor with `sq` or `sacct -j <id>`;
cancel with `scancel <id>`.

### Optional (only if asked)

Email (`--mail-type` / `--mail-user`), array jobs (`--array` + `$SLURM_ARRAY_TASK_ID`),
dependency chains (`--dependency=afterok:<id>`), multi-node DDP (`--nodes`,
`--ntasks-per-node`, `srun` / `torchrun`, `MASTER_PORT`), checkpoint signal-trapping.

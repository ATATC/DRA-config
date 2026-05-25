---
name: ccdb-clusters
description: "**MANDATORY** for Alliance Canada (DRAC / CCDB) HPC tasks. Prefer `$CC_CLUSTER` when available, otherwise infer the cluster from hostname and paths. Covers SLURM mechanics, modules, scratch storage, CCDB Python wheels, MAX_TRES billing, and per-cluster facts for Fir, Trillium, Rorqual, Cedar, Graham, Béluga, Narval, Niagara, and Killarney. Use whenever you see /home/<user>, /scratch, sbatch, sshare, seff, sq, /cvmfs, or are working over SSH on *.alliancecan.ca."
allowed-tools: Bash(module *), Bash(sbatch *), Bash(salloc *), Bash(srun *), Bash(squeue *), Bash(sacct *), Bash(scontrol *), Bash(sinfo *), Bash(sshare *), Bash(seff *), Bash(df *), Bash(diskusage_report *), Bash(ls *), Bash(cat *), Bash(grep *), Bash(tail *), Bash(${CLAUDE_SKILL_DIR}/scripts/*), Read
---

# Alliance Canada Clusters — Skill Index

You are working on an **Alliance Canada** (formerly Compute Canada / DRAC) HPC
cluster. If site-config is present, use `$CC_CLUSTER` to identify which one.
If it is absent, infer the cluster from `hostname -f`, the SSH target, or
obvious path/domain clues such as `*.alliancecan.ca`. The rules in this file
apply on every cluster; cluster-specific facts (GPU types, partitions, node
layouts) live in `references/clusters/<name>.md`.

```bash
echo "Cluster:    $CC_CLUSTER"      # fir, trillium, cedar, graham, beluga, narval, niagara, rorqual, killarney
echo "Restricted: $CC_RESTRICTED"   # true on some clusters (e.g. Fir) — special export-control rules
```

If `$CC_CLUSTER` is unset, do not stop there. First try:

```bash
hostname -f
```

Then map the result to a cluster name and open the matching reference file
directly, for example `references/clusters/fir.md`.

## Critical rules (always apply on every Alliance cluster)

| Rule | Consequence of violating |
|---|---|
| **Pick the cluster first**: short jobs (<1 day) → Trillium; long jobs (≥1 day) → Fir/Rorqual; AI workloads → Killarney; CPU-parallel → Niagara; general workloads → Cedar/Graham/Narval/Béluga | Wrong queue, longer wait, wasted RAC allocation |
| **Login node = light tasks only**; heavy work (compile/train/install) must use `sbatch`. **No IDE remoting (VS Code / Cursor / JupyterHub) for >1 minute** — submit a small interactive job instead | Login node killed; session dies; admins may warn the lab |
| **Default GPU sizing = 20–40 GB MIG** (where supported, e.g. Fir's H100s). Only request a full 80 GB GPU when (a) the model genuinely needs >40 GB VRAM **or** (b) the job is ≥1 day | Burns shared LevelFS for unused VRAM |
| **Load modules before use** — nothing is in `PATH` by default (`python`, `node`, `go`, `uv`, ...) | "command not found" |
| **Store data in `$SCRATCH`**, never `$HOME` (small fixed quota everywhere, easy to fill) | Write errors mid-job |
| **GPU only inside SLURM** | Won't find device otherwise |
| **Never `--index-url` for PyTorch** — CCDB wheels (`/cvmfs/soft.computecanada.ca/...`) only | CUDA / glibc mismatch |
| **No internet on compute nodes** on Cedar / Graham / Béluga / Narval / Niagara — pre-stage data on the login node first. **Compute nodes DO have internet** on Fir (and historically Trillium/Killarney; verify) | Failed `pip install` / `wandb online` / `huggingface_hub` calls inside jobs |

Common module loads on the modern stack (`StdEnv/2023`):
```bash
module load python/3.11.5 nodejs/20.16.0 cuda/12.6 cmake/3.31.0 go/1.22.5 rust/1.91.0
```

## Pre-submit checklist (MANDATORY before every `sbatch`)

1. **Pick the highest-FairShare account** for the job type:
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/show-fairshare.sh
   sbatch --account=$(${CLAUDE_SKILL_DIR}/scripts/pick-gpu-account.sh) <script>
   ```
   Your accounts come from `sshare -U -l` — typically `def-<pi>_<gpu|cpu>`,
   `rrg-<pi>_<gpu|cpu>` (RAC-allocated), and `rpp-<pi>` (priority-access).
   `pick-gpu-account.sh` ranks by **FairShare** (the priority-relevant 0–1
   value SLURM uses), not LevelFS — these can disagree when you have RAC
   and default accounts under the same PI: the RAC account often has
   higher FairShare even with lower LevelFS, and gives ~1.5× higher
   FAIRSHARE priority. Prefer RRG/RPP first regardless: they're
   merit-awarded for a project on an annual use-it-or-lose-it cycle.
   For CPU jobs prefer `def-<pi>_cpu`.
2. **Dry-run imports** from the project dir, e.g.
   `python -c "from trainer import run_training; print('OK')"`
3. **Match CPU count to GPU break-even** on the cluster you're using (see
   `references/clusters/<cluster>.md` for the cluster-specific table; on Fir
   the break-even is 1/3/5/12 for 1g/2g/3g/full H100). Over-requesting CPUs
   flips billing to the CPU rate.

## Index — load only what you need

| You're doing… | Read this |
|---|---|
| Submitting a GPU/CPU job, picking an account | `references/billing.md` |
| Writing a job script, multi-GPU DDP, `MASTER_PORT` | `references/templates.md` |
| SLURM commands (`sq`, `scancel`, logs) | `references/slurm.md` |
| Installing Python packages (pip / uv / CCDB wheels) | `references/python-installs.md` |
| Storage layout, cache env vars, $SLURM_TMPDIR | `references/storage.md` |
| Iterative training protocol (5–10 sample smoke → full job) | `references/pipeline-iteration.md` |
| **Cluster-specific facts** (GPUs, partitions, login host, quirks) | `references/clusters/$CC_CLUSTER.md` when set, otherwise the inferred cluster file |

## Helper scripts

| Script | Purpose |
|---|---|
| `scripts/pick-gpu-account.sh` | Print highest-FairShare `*_gpu` account (`PICK_BY=levelfs` for old behaviour) |
| `scripts/show-fairshare.sh` | Pretty-print all your accounts' fair-share metrics, sorted best-first |
| `scripts/group-seff.sh [days] [account]` | Loop `seff` over your recent COMPLETED/TIMEOUT/FAILED jobs |

## Never do this (on any Alliance cluster)

1. Run `pip install` with compilation on the login node → use `sbatch`
2. Install into base Python → always use a venv (and `uv venv --python "$(which python)"` — not `--python python3.11`; see `python-installs.md`)
3. Run training without GPU allocation
4. Forget to load modules
5. Store large files in `$HOME` (small quota everywhere on Alliance)
6. Use PyTorch < 2.2 on H100 nodes (sm_90 needs ≥ 2.2; affects Fir / Rorqual / Killarney's H100 partition)
7. Use `--index-url https://download.pytorch.org/whl/cuXXX` — CCDB wheels only
8. **Leave an idle interactive GPU job running while AFK** — idle reservation bills the same as 100%-utilized and tanks LevelFS. Cancel with `scancel` when you step away
9. **Over-request CPUs past break-even** on a MIG slice or shared GPU — flips billing to CPU rate (see `billing.md`)
10. **Submit ≥1-day jobs on a partial GPU slice** — wall-time × small allocation is wasteful. 1-day jobs go on a full GPU; partial slices belong on jobs ≤12h
11. **Skip `seff <jobID>` after a run** — LevelFS is *shared with your whole lab group* (`def-<pi>_*`, `rrg-<pi>_*`). Idle / under-utilized jobs lower *everyone's* priority for ~1 week

## Useful primer

- `seff <jobID>` shows efficiency but does NOT change what you're billed. Billing = requested resources × wall-clock.
- LevelFS decays with 1-week half-life; only *time* recovers priority.
- Alliance uses **MAX_TRES** billing: you pay for the most expensive dimension (CPU, Mem, or GPU) per second. Over-requesting one dimension is "free" up to its break-even with the dominant dimension.
- `$SCRATCH`, `$HOME`, and `$PROJECT` are set on Alliance nodes. `$CC_CLUSTER` is available on some site-configured systems; otherwise infer the cluster from hostname and the SSH target. Use these variables and inferred names in scripts instead of hard-coded paths so the same script works on any cluster.

## Getting help

- **Running jobs (Alliance wiki)** — start here for SLURM concepts: <https://docs.alliancecan.ca/wiki/Running_jobs>
- **Technical support** — staff are responsive; prefer email: <https://docs.alliancecan.ca/wiki/Technical_support>
- **System status / outages** — <https://status.alliancecan.ca/>
- **CCDB account portal** (allocations, group membership) — <https://ccdb.alliancecan.ca/>
- **Per-cluster pages** — `https://docs.alliancecan.ca/wiki/<Cluster>` (Cedar, Graham, etc.)
- **Personal config** — your specific account names, venv catalog, and group memberships should live in your local assistant memory, not in this repo. The shared skill uses placeholders like `def-<pi>_gpu` / `rrg-<pi>_gpu`; resolve to your actual account names at runtime via `pick-gpu-account.sh` (or your local notes).

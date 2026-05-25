# Fir Cluster

> Sourced from live Fir session (2026-05) + Alliance wiki mirror oldid=164899 (June 2025).
> Status: **Operational.** `$CC_CLUSTER=fir`, `$CC_RESTRICTED=true`.

## At a glance

| Item | Value |
|---|---|
| Location | Simon Fraser University (Burnaby, BC) |
| Login host | Set by Alliance (check with `echo $HOSTNAME` from a login session) |
| Globus endpoint | (verify) |
| OS | AlmaLinux 9.6 |
| Special | `$CC_RESTRICTED=true` — export-control rules apply |
| Best for | **Long jobs (≥1 day)** on H100 |

## Hardware

| Nodes | Cores | Memory | CPU | GPU |
|---|---|---|---|---|
| 860 | 192 | 768 GB DDR5 | 2× AMD EPYC 9655 (Zen 5) @ 2.7 GHz, 384 MB L3 | — |
| 160 | 48 | 1 TB DDR5 | 1× AMD EPYC 9454 (Zen 4) @ 2.4 GHz, 256 MB L3 | 4× NVIDIA H100 SXM5 (80 GB) |

H100s on the GPU nodes support **MIG slicing**, so a single 80 GB GPU can be
partitioned into smaller virtual GPUs.

## GPU sizing — MIG slice names

| Slice | VRAM | `--gpus-per-node=` value | Break-even CPUs | Break-even Mem |
|---|---|---|---|---|
| 1g.10gb | 10 GB | `nvidia_h100_80gb_hbm3_1g.10gb:1` | 1 | ~41 GB |
| 2g.20gb | 20 GB | `nvidia_h100_80gb_hbm3_2g.20gb:1` | 3 | ~82 GB |
| 3g.40gb | 40 GB | `nvidia_h100_80gb_hbm3_3g.40gb:1` | 5 | ~123 GB |
| Full H100 | 80 GB | `h100:1` (or `h100:4` for whole node) | 12 | ~288 GB |

**Default to 20 GB or 40 GB** — full 80 GB is for genuine VRAM hogs or 1-day jobs.

## Storage

| Mount | Variable | Volume | Purge |
|---|---|---|---|
| `/home/$USER` | `$HOME` | small fixed (~48 GB) | persistent |
| `/scratch/$USER` | `$SCRATCH` | large fixed | inactive purge (60 days) |
| `/project/<group>` | `$PROJECT` | RAC | persistent |
| `/localscratch/<user>.<jobid>.0/` | (see below) | per-node NVMe (~7 TB) | per-job, auto-cleaned |
| `/cvmfs/soft.computecanada.ca/...` | — | shared software stack | read-only |

Total cluster storage: 51 PB (2 PB NVMe + 49 PB SAS).

### `/localscratch` — Fir-specific job-local NVMe

Each Fir compute node has a `/localscratch` mount on local NVMe — observed
on `fc10920` (2026-05-06) at **7.0 TB / 6.8 TB free**, mounted xfs with
`noquota`. SLURM auto-creates `/localscratch/$USER.$SLURM_JOB_ID.0/` for
every job; the directory is owned by you and writable. Contents are wiped at
job exit by the SLURM epilog.

Two important quirks vs. the generic `$SLURM_TMPDIR` pattern:

1. **`$SLURM_TMPDIR` is not always exported on Fir.** The dir exists, but if
   you `echo $SLURM_TMPDIR` from inside a job and get nothing, build the
   path yourself: `LOCAL_SCRATCH=/localscratch/${USER}.${SLURM_JOB_ID}.0`.
   The recipe in `references/storage.md` uses `${SLURM_TMPDIR:-…}` for
   safety.
2. **`/localscratch` does not count against `--mem=`** — it's real NVMe
   disk, not tmpfs. By contrast `/tmp` on Fir compute nodes IS tmpfs
   (RAM-backed) and bytes there ARE charged to `--mem=`. Staging a big
   dataset to `/tmp` on a small `--mem=` allocation will OOM-kill the job
   (observed on Fir 2026-05-06: a 28 GB `cp` of NPZ files into /tmp on a
   `--mem=64G` allocation triggered a cgroup-OOM SIGKILL; sacct showed
   `State=CANCELLED` with `ExitCode=0:0`).
   Stage to `/localscratch` instead.

`--tmp=200G` in the sbatch header is recommended even though the node has
~7 TB free — it documents intent for the scheduler and survives any future
node-pool rebalancing.

## Fir-specific quirks

- **Compute-node internet IS available** — `pip install`, `wandb online`, and
  `huggingface_hub` calls work inside `sbatch`. (Most Alliance clusters block
  this; Fir does not.)
- **`$CC_RESTRICTED=true`** — some software (CUDA toolkit, certain ML
  libraries) is gated; ITAR/EAR-style export-control rules. If a `module
  load` returns "permission denied", that's why; ask CCDB support.
- **Templates path** — example job templates live in `$SCRATCH/job_*.sh`
  (per-user; not shipped with this skill).
- **MASTER_PORT** — see `references/templates.md` for the torchrun pitfall;
  a documented case occurred on Fir.

## Partitions and wall-time

Fir uses banded partitions where SLURM picks the smallest band that fits
your `--time` request:

| Partition | Wall-time | Notes |
|---|---|---|
| `gpubase_bygpu_b1` | 3 h | |
| `gpubase_bygpu_b2` | 12 h | (was 6 h pre-2026-05; verify with `sinfo`) |
| `gpubase_bygpu_b3` | 1 day | (was 12 h pre-2026-05) |
| `gpubase_bygpu_b4` | 3 days | |
| `gpubase_bygpu_b5` | 7 days | |
| `gpubase_bygpu_b6` | 28 days | |
| `gpubackfill_bygpu` | (varies) | low-priority fill-in |

You normally don't pick the partition; SLURM picks it. **Verify the band
walltimes with `sinfo -o "%.20P %.20l"` before sizing a long job** —
walltime bands have shifted at least once (the table above was last
verified 2026-05-06).

## TRES weights (observed 2026-04, partition `gpubase_bygpu_b1`)

| Resource | Weight per unit |
|---|---|
| 1 CPU core | 1,016.67 |
| 1 GB RAM | 42.36 |
| 1× MIG 1g.10gb | 1,742.86 |
| 1× MIG 2g.20gb | 3,485.71 |
| 1× MIG 3g.40gb | 5,228.57 |
| 1× full H100 | 12,200 |

Re-verify with `scontrol show partition gpubase_bygpu_b1 | grep -i tresbill`.

## Daily cost (12h, requested vs used)

| GPU | Daily cost |
|---|---|
| 1g.10gb | ~75M / day |
| 2g.20gb | ~150M / day |
| 3g.40gb | ~226M / day |
| Full H100 | ~527M / day |

(Numbers are billing units, not currency; useful for relative comparison.)

## Account selection — RRG first, then default

If you have both an RRG (RAC competition award) and a default-allocation
account on Fir (e.g. `rrg-<pi>_gpu` and `def-<pi>-<sub>_gpu` for the
same PI), **use the RRG account first**. RRG/RPP allocations are
merit-awarded for a specific project on an annual use-it-or-lose-it
cycle; default accounts are auto-granted fallbacks. Reserving the RRG
account "for later" wastes the awarded cycles.

Submit-priority benefit, not just policy: on Fir the SLURM FAIRSHARE
priority component is dominated by the *FairShare* score (multi-level
FairTree), not by LevelFS. RRG accounts typically have higher FairShare
because their parent group has a larger root-level share allocation —
*even when LevelFS at the leaf account is lower*. Real numbers from a
def-* + rrg-* pair on Fir (2026-05-06, account names anonymised):

| Account | LevelFS | FairShare | FAIRSHARE priority |
|---|---|---|---|
| `def-<pi>-<sub>_gpu` | 2.998 | 0.337 | 1.68 M |
| `rrg-<pi>_gpu`       | 0.431 | **0.498** | **2.50 M** (1.48× ↑) |

`scripts/pick-gpu-account.sh` ranks by FairShare since 2026-05-06; the
older LevelFS-based behaviour is preserved behind `PICK_BY=levelfs`.

If a 12-h job submitted under the wrong account is still PENDING, you
can re-route it without losing queue position:

```bash
scontrol update JobId=<jobid> Account=rrg-<pi>_gpu
```

The job's FAIRSHARE priority is recomputed within the next SLURM
priority cycle (usually a minute).

## Common pitfalls on Fir

- **Idle full-H100 reservation while AFK** — bills the same as 100%-utilized.
  Cancel with `scancel` when you step away.
- **PyTorch < 2.2** — H100 is sm_90, needs PyTorch ≥ 2.2.
- **Hard-coded `os.environ['MASTER_PORT']` in `main.py`** — overwrites
  torchrun's port and hangs `dist.init_process_group` for 1800 s. See
  `templates.md`.
- **Submitting from `/home`** — fails with "Submitting jobs from
  directories residing in /home is not permitted". `cd $SCRATCH/<project>` first.

# Béluga Cluster

> Sourced from Alliance wiki mirror (June 2025).
> Status: **Operational since 2019-03**, but **Rorqual is being deployed as
> its successor** (winter–spring 2025). Plan accordingly if starting new
> long-running projects.

## At a glance

| Item | Value |
|---|---|
| Location | École de technologie supérieure (ÉTS Montréal, QC) |
| Login host | `beluga.alliancecan.ca` |
| Globus endpoint | `computecanada#beluga-dtn` |
| Copy node (rsync/scp/sftp) | `beluga.alliancecan.ca` |
| Portal | <https://portail.beluga.calculquebec.ca/> |
| Compute-node internet | **No** (policy) |
| Crontab | Not available |
| Job duration | 1 h to 168 h (7 days); test jobs ≥ 5 min |
| User job limit | 1000 jobs (running + pending) |
| Best for | General GPU + CPU |

## Hardware

| Nodes | Cores | Memory | CPU | Local | GPU |
|---|---|---|---|---|---|
| 160 | 40 | 92 GB | 2× Intel Gold 6148 Skylake @ 2.4 GHz | 1× 480 GB SSD | — |
| 579 | 40 | 186 GB | Same | Same | — |
| 51 | 40 | 752 GB | Same | Same | — |
| 172 | 40 | 186 GB | Same | 1× 1.6 TB NVMe SSD | 4× **V100SXM2 16 GB NVLink** |

Turbo mode is **enabled** on all Béluga nodes.

## GPU sizing

```bash
#SBATCH --gpus-per-node=1     # any V100SXM2 16 GB
#SBATCH --gpus-per-node=4     # whole node, NVLink between all 4 GPUs
```

Béluga V100s have **only 16 GB VRAM** (vs 32 GB on Graham/Cedar V100s).
Many modern models won't fit on a single GPU — plan multi-GPU + NVLink for
training, or use a different cluster.

## Storage

| Mount | Volume | Backup |
|---|---|---|
| `$HOME` | 105 TB total (Lustre) | yes (daily) |
| `$SCRATCH` | 2.6 PB (Lustre) | **no** — purge |
| `$PROJECT` | 25 PB (Lustre) | yes (daily) |

`$SLURM_TMPDIR` size: pass `--tmp=xG` where x ∈ [350, 2490] (GB) to size it.

## Interconnect

Mellanox InfiniBand EDR (100 Gb/s) connects all nodes via a 324-port
central switch. Max blocking factor 5:1 across islands; storage servers
use a non-blocking interconnect. Non-blocking parallel jobs up to ~640
cores.

## Site-specific policies

- Each task should last **at least 1 hour** (5 min for test jobs).
- Each task **at most 7 days** (168 h).
- **No more than 1000 tasks** running + pending at a time.
- Compute nodes have **no internet access**; for exceptions, contact CC
  technical support.
- `crontab` is **not available**.

## Monitoring

Use the portal at <https://portail.beluga.calculquebec.ca/> for real-time
CPU/memory/GPU utilization on your jobs (not just historical `seff`).

## Common pitfalls on Béluga

- **V100s are 16 GB only** — not 32 GB. Modern LLM/diffusion models often
  don't fit.
- **No compute-node internet** — pre-stage data and wheels.
- **172 GPU nodes only**, vs 160 + 579 + 51 = 790 CPU-only nodes — GPU queue
  is busier than CPU queue.
- **1-hour minimum** — test jobs less than 5 min are rejected.

# Killarney Cluster

> Sourced from Alliance wiki mirror oldid=174874 (June 2025).
> Status: **TBA in mirror — VERIFY on live wiki.** Likely operational by 2026-05.

## At a glance

| Item | Value |
|---|---|
| Location | University of Toronto (managed by **Vector Institute + SciNet**) |
| Login host | TBA (verify) |
| Globus endpoint | TBA (verify) |
| Status page | TBA (verify) |
| Affiliation | **PAICE — Pan-Canadian AI Compute Environment** |
| Best for | **AI workloads** — both inference (L40s) and training (H100) |

Killarney is named after Killarney Provincial Park (Ontario, near Georgian
Bay) and is dedicated to the Canadian scientific AI community.

## Hardware

| Tier | Nodes | Model | CPU | Cores | Memory | GPUs/node | Total GPUs |
|---|---|---|---|---|---|---|---|
| **Standard Compute** | 168 | Dell 750xa | 2× Intel Xeon Gold 6338 | 64 | 512 GB | **4× NVIDIA L40s 48 GB** | 672 |
| **Performance Compute** | 10 | Dell XE9680 | 2× Intel Xeon Gold 6442Y | 48 | 2048 GB | **8× NVIDIA H100 SXM 80 GB** | 80 |

L40s is Ampere/Ada Lovelace-derived (sm_89), excellent for inference and
moderate training. H100 SXM is sm_90, full top-tier training.

## GPU sizing

Standard compute (most queues):
```bash
#SBATCH --gpus-per-node=1     # 1× L40s 48 GB
#SBATCH --gpus-per-node=4     # whole 750xa node
```

Performance compute (limited capacity, high demand):
```bash
#SBATCH --gpus-per-node=1     # 1× H100 80 GB (verify partition naming)
#SBATCH --gpus-per-node=8     # whole XE9680 node, 640 GB VRAM
```

## Storage

All-NVMe **VastData** platform, 1.7 PB total usable.

| Mount | Filesystem | Backup | Quota |
|---|---|---|---|
| `$HOME` | VastData | yes (daily) | small fixed (TBA) |
| `$SCRATCH` | VastData (parallel high-perf) | **no** — purge | large fixed |
| `$PROJECT` | VastData (external persistent) | yes (daily) | RAC-allocated |

`/project` is **not** designed for parallel I/O — use `$SCRATCH` for active
training; sync to `$PROJECT` afterward. (Alliance-standard rule.)

## Interconnect

- Standard Compute: InfiniBand HDR100 (100 Gbps).
- Performance Compute: 2× HDR200 (400 Gbps aggregate). Optimized for
  multi-H100 training communication.

## Software

Module-based stack. Both the standard Alliance stack and Killarney-specific
software tuned for AI workloads. Slurm-based scheduling like every other
Alliance cluster.

## TODO — first time on Killarney

- Confirm cluster is in production.
- Pull login host, Globus endpoint, status page from
  <https://docs.alliancecan.ca/wiki/Killarney>.
- Confirm queue / partition names for Standard vs Performance tiers.
- Pull TRES billing weights.
- Confirm whether L40s or H100 supports MIG (L40s typically does not; H100
  may or may not have MIG enabled here).
- Confirm whether allocation is via standard RAC or a separate Vector / PAICE
  process.
- Bump the date stamp at top of this page.

## When to choose Killarney

```
LLM / multimodal training         → Performance Compute (H100 8-GPU node)
Inference, fine-tuning small      → Standard Compute (L40s)
Vector / SciNet collaboration     → Killarney is the natural home
General Alliance ML on H100       → Fir or Rorqual (more H100 capacity)
```

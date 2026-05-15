# Graham Cluster

> Sourced from Alliance wiki mirror oldid=175647 (June 2025).
> Status: **Reduced capacity since 2025-01-13** — operating at ~25% capacity
> until the new cluster **Nibi** comes online. Plan migration; don't start
> new long-running projects on Graham.

## At a glance

| Item | Value |
|---|---|
| Location | University of Waterloo (ON) |
| Login host | `graham.alliancecan.ca` |
| Globus endpoint | `computecanada#graham-globus` |
| Data transfer node | `gra-dtn1.alliancecan.ca` |
| Visualization | `gra-vdi.alliancecan.ca` (VNC only) |
| Compute-node internet | **No** (policy) |
| Crontab | Not offered |
| Job duration | 1 h to 168 h (7 days) |
| User job limit | 1000 jobs (running + queued; array tasks counted individually) |
| Status | **Retiring — replaced by Nibi.** Plan accordingly. |

## Hardware (post-2025-02 reduction)

In early 2025 Graham's capacity was reduced to make space for Nibi.
Remaining nodes:

| Nodes | Cores | Memory | CPU | Local disk | GPU |
|---|---|---|---|---|---|
| 2 | 40 | 377 GB | 2× Intel Xeon Gold 6248 Cascade Lake @ 2.5 GHz | 5.0 TB NVMe | 8× V100 32 GB **NVLink** |
| 6 | 16 | 187 GB | 2× Intel Xeon Silver 4110 Skylake @ 2.10 GHz | 11.0 TB SATA SSD | 4× T4 16 GB |
| 30 | 44 | 187 GB | 2× Intel Xeon Gold 6238 Cascade Lake @ 2.10 GHz | 5.8 TB NVMe | 4× T4 16 GB |
| 136 | 44 | 187 GB | Same | 879 GB SATA SSD | — |
| 1 | 128 | 2 TB | 2× AMD EPYC 7742 | 3.5 TB SATA SSD | 8× A100 |
| 2 | 32 | 256 GB | 2× Intel Xeon Gold 6326 @ 2.90 GHz | 3.5 TB SATA SSD | 4× A100 |
| 11 | 64 | 128 GB | 1× AMD EPYC 7713 | 1.8 TB SATA SSD | 4× RTX A5000 |
| 6 | 32 | 1024 GB | 1× AMD EPYC 7543 | 8× 2 TB NVMe | — |

Turbo Boost is **enabled** on all Graham nodes.

## GPU sizing — request the right type

| GPU type | `--gres=` syntax | When to use |
|---|---|---|
| V100 32 GB NVLink | `--gres=gpu:v100:1` (max 8) | Multi-GPU NVLink-bound work; only 2 nodes available |
| T4 16 GB | `--gres=gpu:t4:1` | Inference, fp16/int8, single-precision |
| A100 | `--gres=gpu:a100:1` | Large-memory training (only 3 nodes total) |
| RTX A5000 | `--gres=gpu:a5000:1` | General training, 4 cards/node |

V100 nodes have **40 cores total**, max **5 CPUs per GPU**. Older Volta
nodes (28-core, decommissioned) had max 3.5 CPUs per GPU.

For NVLink-required workloads on the 2-V100-NVLink nodes:
`--constraint=cascade,v100`.

## Storage

| Mount | Volume | Backup |
|---|---|---|
| `$HOME` | 133 TB total | yes (daily) |
| `$SCRATCH` | 3.2 PB (Lustre) | **no** — purge |
| `$PROJECT` | 16 PB | yes (daily) |

`$SLURM_TMPDIR` is local SSD/NVMe per node.

## Interconnect

Mellanox FDR (56 Gb/s) for GPU + cloud nodes; EDR (100 Gb/s) for other
nodes. 324-port central director switch aggregates 1024-core islands.
8:1 blocking factor between islands.

Non-blocking parallel jobs up to 1024 cores.

## Common pitfalls on Graham

- **Compute-node internet is blocked** — pre-stage everything.
- **Job duration cap of 7 days** (168 h).
- **1000-job limit** — including array tasks.
- **Visualization only via VNC** to `gra-vdi.alliancecan.ca`, no SSH X11.
- **P100 GPUs are gone** (decommissioned). V100 / T4 / A100 / A5000 only.
- **Reduced capacity** — expect long queue waits. Migrate to Nibi when it
  comes online.

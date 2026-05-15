# Cedar Cluster

> Sourced from Alliance wiki mirror oldid=153230 (June 2025).
> Status: **Operational** (in production since 2017-06-30).

## At a glance

| Item | Value |
|---|---|
| Location | Simon Fraser University (Burnaby, BC) |
| Login host | `cedar.alliancecan.ca` |
| Globus endpoint | `computecanada#cedar-globus` |
| Status page | <https://status.alliancecan.ca/> |
| Compute-node internet | **No** (policy) |
| Best for | General GPU + CPU workloads, larger jobs |

## Hardware

Cedar is heterogeneous — multiple node types coexist on the same cluster.
Total: 100,400 CPU cores + 1,352 GPUs.

| Nodes | Cores | Memory | CPU | Local disk | GPU |
|---|---|---|---|---|---|
| 256 | 32 | 125 GB | 2× Intel E5-2683 v4 Broadwell @ 2.1 GHz | 2× 480 GB SSD | — |
| 256 | 32 | 250 GB | Same | Same | — |
| 40 | 32 | 502 GB | Same | Same | — |
| 16 | 32 | 1.5 TB | Same | Same | — |
| 6 | 32 | 4 TB | 2× AMD EPYC 7302 @ 3.0 GHz | Same | — |
| 2 | 40 | 6 TB | 4× Intel Gold 5215 Cascade Lake @ 2.5 GHz | Same | — |
| 96 | 24 | 125 GB | 2× E5-2650 v4 Broadwell | 1× 800 GB SSD | 4× P100 12 GB |
| 32 | 24 | 250 GB | Same | Same | 4× P100 16 GB |
| 192 | 32 | 187 GB | 2× Intel Silver 4216 Cascade Lake @ 2.1 GHz | 1× 480 GB SSD | 4× V100 32 GB |
| 608 | 48 | 187 GB | 2× Intel Platinum 8160F Skylake @ 2.1 GHz | 2× 480 GB SSD | — |
| 768 | 48 | 187 GB | 2× Intel Platinum 8260 Cascade Lake @ 2.4 GHz | 2× 480 GB SSD | — |

Turbo Boost is **deactivated** on all Cedar nodes.

## GPU sizing

```bash
#SBATCH --gres=gpu:p100:1        # P100 (12 GB or 16 GB depending on node)
#SBATCH --gres=gpu:v100:1        # V100 (32 GB)
```

For GPU jobs, **request P100 unless you need >16 GB VRAM** — they're cheaper
fairshare-wise. V100 is for big-memory or NVLink-required workloads.

## Storage

| Mount | Volume | Filesystem | Backup |
|---|---|---|---|
| `$HOME` | 526 TB total | (NFS-like) | yes (daily) |
| `$SCRATCH` | 5.4 PB | Lustre (DDN ES14K, 640× 8 TB NL-SAS, dual-redundant SSD metadata) | **no** — purge |
| `$PROJECT` | 23 PB | (separate persistent storage) | yes (daily) |

`$SLURM_TMPDIR` is local SSD per node — use it for many-small-file workloads.

## Submitting jobs policy

- **Cannot run jobs from `/home`** as of 2019-04-17. Submit from `$SCRATCH/`
  or `$PROJECT/`. The error is "Submitting jobs from directories residing in
  /home is not permitted".

## Whole-node vs shared

- 48-core nodes (Skylake/Cascade Lake) include some reserved for whole-node
  jobs.
- 32-core nodes (Broadwell) are not reserved — jobs requesting < 48 cores can
  share with others.
- Constraints: `--constraint=cascade`, `--constraint=skylake`,
  `--constraint=broadwell`. For any AVX512 node:
  `--constraint=[skylake|cascade]`. **In general, don't constrain** —
  performance differences are small relative to queue waits.

## Interconnect

Intel OmniPath v1, 100 Gb/s. Non-blocking up to 1024 cores (Broadwell) or
1536 cores (Skylake/Cascade Lake) per island; 2:1 blocking factor for
larger jobs. Most islands are 32 nodes.

## Performance

~14 PFLOPS theoretical peak DP (6.5 PF CPUs + 7.4 PF GPUs).

## Common pitfalls on Cedar

- **Submitting from `/home`** — forbidden, see above.
- **Compute-node internet is blocked** — pre-stage wheels and data on the
  login node (`pip download`, `wget`, `git clone`) before submitting.
- **P100 12 GB** is the smallest GPU — many modern models won't fit.
- **AVX512 on Cascade Lake** — newer wheels may require it; constrain
  explicitly if you hit "illegal instruction".
- **Globus v4 endpoint `computecanada#cedar-dtn` is retired** — use
  `computecanada#cedar-globus`.

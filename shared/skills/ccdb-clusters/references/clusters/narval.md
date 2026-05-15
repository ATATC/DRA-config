# Narval Cluster

> Sourced from Alliance wiki mirror oldid=164850 (June 2025).
> Status: **Operational** (since 2021-10).

## At a glance

| Item | Value |
|---|---|
| Location | École de technologie supérieure (ÉTS Montréal, QC; same site as Béluga) |
| Login host | `narval.alliancecan.ca` |
| Globus collection | "Compute Canada - Narval" |
| Copy node | `narval.alliancecan.ca` |
| Portal | <https://portail.narval.calculquebec.ca/> |
| Compute-node internet | **No** (policy) |
| Crontab | Not available |
| Job duration | 1 h to 168 h (7 days) |
| User job limit | 1000 jobs |
| CPU architecture | **AMD EPYC (AVX2 only — no AVX512)** |
| Best for | General-purpose ML, large memory, A100 training |

## Hardware

| Nodes | Cores | Memory | CPU | Local | GPU |
|---|---|---|---|---|---|
| 1145 | 64 | 249 GB | 2× AMD EPYC 7532 (Zen 2) @ 2.40 GHz, 256 MB L3 | 1× 960 GB SSD | — |
| 33 | 64 | 2 TB or 4 TB | (large-memory variant) | — | — |
| 159 | 48 | 498 GB | 2× AMD EPYC 7413 (Zen 3) @ 2.65 GHz, 128 MB L3 | 1× 3.84 TB SSD | 4× **A100SXM4 40 GB NVLink** |

## GPU sizing

```bash
#SBATCH --gpus-per-node=1     # one A100 40 GB
#SBATCH --gpus-per-node=4     # whole node, NVLink
```

A100 40 GB is significantly more capacity than Béluga's V100 16 GB. For
modern LLM/diffusion work, **prefer Narval over Béluga** if you have access.

## Storage

| Mount | Volume | Backup |
|---|---|---|
| `$HOME` | 40 TB total (Lustre) | yes (daily) |
| `$SCRATCH` | 5.5 PB (Lustre) | **no** — purge |
| `$PROJECT` | 19 PB (Lustre) | yes (daily) |

## Interconnect

Mellanox HDR InfiniBand (HDR200 / HDR100). 40-port HDR switches connect up
to 66 nodes per cabinet at HDR100. Cabinet-to-spine: 7 HDR uplinks per
cabinet → 33:7 (4.7:1) max blocking. Storage servers use lower blocking.
Non-blocking parallel jobs up to **3,584 cores**.

## AMD-specific quirks

- **AVX2 only** — no AVX512. The Intel-style processor pinning macros
  (`-xCORE-AVX2`, `-xHOST`) compile to *AVX-only* on AMD because Intel's
  `-x` flags add a CPU-vendor check. **Use `-march=core-avx2`** (or
  `-march=znver2` / `-march=znver3` for tighter tuning) instead.
- Code compiled on Béluga / Niagara (or AVX512 nodes on Cedar/Graham)
  **will not run** on Narval — recompile.
- Code compiled on Cedar/Graham Broadwell nodes (or their login nodes,
  which are Broadwell) **does** run on Narval.

## BLAS/LAPACK

The default Intel MKL works on AMD but is not optimal. Narval recommends
**FlexiBLAS**. See the Alliance wiki BLAS page.

## Software environment

Default `StdEnv/2023`. Older `StdEnv/2016` and `StdEnv/2018` are blocked —
ask CC support if you genuinely need them.

## Common pitfalls on Narval

- **Intel-compiler `-xHOST` produces AVX-only binaries on AMD** — the binary
  runs but at ~1/4 expected speed. Always use `-march=core-avx2` instead.
- **No AVX512** — anything compiled with AVX512 instructions crashes.
- **No compute-node internet** — pre-stage data and wheels.
- **1-hour minimum job duration**.
- **Only 159 GPU nodes** — A100 queue is busy; check LevelFS before
  committing to a sizing.

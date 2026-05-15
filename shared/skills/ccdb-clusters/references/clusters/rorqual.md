# Rorqual Cluster

> Sourced from Alliance wiki mirror oldid=176376 (June 2025) — page was a
> "to-be-deployed" stub.
> Status: **Likely operational by 2026-05** (mirror said "deploy
> winter–spring 2025"). **VERIFY availability** on the live wiki.

## At a glance

| Item | Value |
|---|---|
| Location | Calcul Québec (Montréal — successor to Béluga) |
| Login host | **TBD** (verify) |
| Globus endpoint | **TBD** (verify) |
| Best for | Long jobs (≥ 1 day), H100 training (similar role to Fir) |

## Hardware (per mirror)

| Nodes | Cores | Memory | CPU | Local | GPU |
|---|---|---|---|---|---|
| 670 | 192 | 768 GB DDR5 | 2× AMD EPYC 9654 (Zen 4) @ 2.40 GHz, 384 MB L3 | 480 GB SATA SSD + 3.84 TB NVMe SSD | — |
| 8 | 64 | 3 TB DDR5 | (large memory) | Same | — |
| 81 | 64 | 512 GB DDR5 | 2× Intel Xeon Gold 6448Y @ 2.10 GHz, 60 MB L3 | 1× 3.84 TB NVMe SSD | 4× **H100 SXM5 80 GB** |

## GPU sizing

```bash
#SBATCH --gpus-per-node=1     # single H100 80 GB (verify slice naming)
#SBATCH --gpus-per-node=4     # whole node (4× H100)
```

Whether MIG slicing is enabled like on Fir is **unknown** — verify on the
live wiki. If it is, expect similar slice names (`h100_1g.10gb`,
`h100_2g.20gb`, `h100_3g.40gb`).

## Storage

Several PB total (mirror said "details to come"). Verify quotas and
filesystem on the live wiki before sizing big workflows.

## Interconnect

InfiniBand HDR 200 Gb/s. Maximum blocking factor 34:6 (≈5.667:1).

## TODO — first time on Rorqual

- Confirm cluster is in production (it should be by 2026-05).
- Pull updated hardware table from <https://docs.alliancecan.ca/wiki/Rorqual>.
- Confirm login host, Globus endpoint.
- Confirm whether MIG slicing is enabled on H100s.
- Confirm storage quotas.
- Confirm compute-node internet policy (likely yes, like Fir).
- Pull TRES weights with `scontrol show partition <partition> | grep -i tresbill`.
- Bump the date stamp at top of this page.

## Cluster choice

If Rorqual is operational, it's a peer to Fir — both are H100-based long-jobs
clusters. Pick whichever has better LevelFS for your group on the day.

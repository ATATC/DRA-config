# Niagara Cluster

> Sourced from Alliance wiki mirror (June 2025).
> Status: **Operational** (since 2018-04).

## At a glance

| Item | Value |
|---|---|
| Location | University of Toronto (operated by SciNet) |
| Login host | `niagara.alliancecan.ca` |
| Globus endpoint | `computecanada#niagara` |
| Data mover nodes (rsync/scp) | `nia-dm1`, `nia-dm2` |
| Status page | <https://docs.scinet.utoronto.ca> |
| Portal | <https://my.scinet.utoronto.ca> |
| **GPUs** | **None on Niagara itself** (Mist is the SciNet GPU expansion, separate) |
| Best for | **Large CPU-parallel jobs** (≥ 1040 cores), high-throughput parallel codes |

## Important access note

Access to Niagara is **NOT enabled automatically** with an Alliance account.
You must opt in via the [CCDB portal](https://ccdb.alliancecan.ca/) — click
"Join" on the Niagara opt-in page; access is typically granted in 1–2
business days.

## Hardware

- **2024 nodes total**, 80,640 cores.
- Each node: **40 cores** (Intel Skylake or Cascade Lake @ 2.4–2.5 GHz, AVX512).
- **202 GB (188 GiB)** of RAM per node — same on every node.
- **No local disks** — fast filesystem only.
- **No GPUs.**
- Operating system: Linux CentOS 7 (mirror; verify if upgraded since).
- Network: 100 Gb/s EDR InfiniBand in **Dragonfly+ topology**, 5 wings of up
  to 432 nodes.

Theoretical peak: 6.25 PFLOPS DP. Measured: 3.6 PFLOPS DP.

## Whole-node scheduling

Niagara is the only Alliance cluster that schedules **by whole node**:

```bash
#SBATCH --nodes=2                     # request 2 whole nodes
#SBATCH --ntasks-per-node=40         # 40 cores per node, mandatory
#SBATCH --time=24:00:00
```

- Jobs **must** use multiples of 40 cores per node.
- **Don't request memory** — every node has the same 202 GB and the
  scheduler ignores it. Specifying memory is discouraged.
- Asking for fewer than 40 cores per node is wasteful and disallowed.

## Storage

| Mount | Volume | Filesystem | Backup |
|---|---|---|---|
| `$HOME` | 200 TB | IBM Spectrum Scale (GPFS) — parallel | tape |
| `$SCRATCH` | 12.5 PB | Spectrum Scale | inactive purge |
| `$PROJECT` | 3.5 PB (RAC-allocated) | Spectrum Scale | tape |
| **Burst buffer** | 232 TB | Excelero + Spectrum Scale (extra-fast) | inactive purge |
| `$ARCHIVE` | 20 PB | IBM HPSS (tape-backed HSM) | tape |

The burst buffer is unique to Niagara — use it for many-small-file workloads
and parallel I/O-bound applications.

## Software

- **Modules don't auto-load** on Niagara (unlike Cedar / Graham). This
  prevents accidental version conflicts.
- To get the same StdEnv as on Cedar/Graham, load the **`CCEnv` module**
  first. See the Niagara Quickstart on the Alliance wiki.
- Cluster-specific software tuned for Niagara is also available alongside
  the standard Alliance stack.

## Network topology — Dragonfly+

5 wings of up to 432 nodes (17,280 cores) each; within a wing, 1-to-1
non-blocking. Cross-wing traffic uses adaptive routing with effective 2:1
blocking. Optimized for large MPI jobs.

## Common pitfalls on Niagara

- **No GPUs.** If you need GPUs, use Mist (separate SciNet system) or another
  Alliance cluster.
- **Whole-node scheduling** — single-core jobs waste 39 cores. If you have
  many small jobs, pack them into a job array filling whole nodes.
- **CCEnv module** — without it, the StdEnv stack you see on Cedar/Graham
  isn't there.
- **Opt-in required** — you don't have access by default.
- **No local disks** — `$SLURM_TMPDIR` is on the parallel filesystem
  (Spectrum Scale or burst buffer), not local SSD.
- **CentOS 7** in the mirror — verify whether the OS has been upgraded.

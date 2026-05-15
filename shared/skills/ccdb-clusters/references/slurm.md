# SLURM Basics on Alliance Canada

These commands work on every Alliance cluster (Fir, Trillium, Cedar, Graham,
Béluga, Narval, Niagara, Rorqual, Killarney). Cluster-specific partition
names and wall-time limits live in `clusters/<cluster>.md`.

## Check status

```bash
sq                          # Your jobs (Alliance shorthand for squeue -u $USER)
squeue -u $USER             # Same, explicit
squeue -j <job_id>          # Specific job
scontrol show job <job_id>  # Full info (recent/active jobs only)
sacct -j <job_id> -X        # Historic record (after job leaves squeue)
```

`sacct -a` is restricted on most Alliance clusters — you'll only see your own
jobs even with `-a`.

## Submit jobs

```bash
sbatch <script.sh>
sbatch --account=<winner> <script.sh>           # override account (see billing.md)
sbatch --time=12:00:00 --mem=32G <script.sh>    # CLI overrides win over #SBATCH
```

Always pass `--account=$(scripts/pick-gpu-account.sh)`
before each submit — your lab's LevelFS shifts daily and the highest-priority
account changes.

## Cancel jobs

```bash
scancel <job_id>            # Cancel specific job
scancel -u $USER            # Cancel all your jobs
scancel --state=PENDING -u $USER  # Cancel only queued (preserve running)
```

## View logs

Logs go wherever your `#SBATCH --output=` says. Common pattern:
```bash
#SBATCH --output=$SCRATCH/slurm_logs/%x_%j.out
#SBATCH --error=$SCRATCH/slurm_logs/%x_%j.err
```
Tail a running job:
```bash
tail -f "$SCRATCH/slurm_logs/<jobname>_<jobid>.out"
```

## Post-hoc efficiency

```bash
seff <jobID>                # Your jobs only — REQUIRED after every job
```

`seff` shows CPU efficiency, memory used vs requested, and (on GPU jobs) GPU
utilization. Bars to clear (see `billing.md` for why):

- CPU efficiency ≥ 80%
- GPU utilization ≥ 90% sustained
- Memory used vs requested ≥ 80%

Below those bars, you're burning shared LevelFS for your whole lab group.

`sacct -a` is restricted: for group-wide visibility see `billing.md`.

## Resource selection cheat sheet (general — see per-cluster pages for specifics)

| Workload | GPU | Why |
|----------|-----|-----|
| Debug / small script | smallest MIG slice (1g.10gb on Fir) | cheapest, quick allocation |
| Dev: VS Code SSH + multi-Claude | medium MIG slice (2g.20gb on Fir) | balanced VRAM and CPU |
| Medium inference | larger MIG slice (3g.40gb on Fir) | balanced memory/compute |
| Training / large batch | full GPU (H100 / A100 / V100 / L40s depending on cluster) | full VRAM and tensor cores |
| CPU-parallel (large MPI) | none — Niagara | dragonfly+ topology, whole-node scheduling |

## Partition / wall-time limits

`sinfo -o "%P %l"` lists partitions and time limits on the current cluster.
Patterns differ:

- **Fir** uses `gpubase_bygpu_b<N>` (b1=3h, b2=6h, b3=12h, b4=1d, b5=3d, b6=7d) and SLURM picks the first that fits your `--time`.
- **Cedar / Graham / Béluga / Narval** typically use generic CPU and GPU partitions selected by `--time` and `--gres`.
- **Niagara** has `compute` (24h max), `debug` (1h, max 4 nodes), and `archive`.

Always check on the cluster you're using — `references/clusters/<cluster>.md`
has the verified table.

## Common gotchas

- `sacct -a` is restricted on Alliance — you only see your own jobs.
- `squeue -u $USER` shows queued + running; use `sq` for cleaner output.
- Job IDs are not reused during a cluster's lifetime, so `sacct -j <id>` works
  long after completion.
- `--time=24:00:00` and `--time=1-00:00:00` are both 1 day (different syntaxes).
- `--mem=0` on a whole-node GPU job allocates ALL node memory (recommended for
  whole-node training).
- On clusters that share GPUs (Fir's MIG), `--gpus-per-node=h100_3g.40gb:1` (or
  similar) is needed to specifically target a slice — see the cluster page.

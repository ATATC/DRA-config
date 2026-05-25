# Storage on Alliance Canada

## Three-tier filesystem (every cluster)

| Variable | Path pattern | Quota | Use for | Backup | Persistence |
|---|---|---|---|---|---|
| `$HOME` | `/home/$USER/` | small fixed (varies, often ~50 GB) | configs, dotfiles ONLY | yes | persistent |
| `$SCRATCH` | `/scratch/$USER/` (Lustre / GPFS) | large fixed (TB) | active/temporary work, venvs, caches, training | NO | **purged** if inactive |
| `$PROJECT` | `/project/<group>/` | RAC-allocated (TB–PB) | shared lab data, long-term archive | yes | persistent |

`$HOME`, `$SCRATCH`, `$PROJECT` are set on every Alliance node — use them in
scripts instead of hard-coded paths so the same script works across clusters.

## Cluster-specific quotas (selected)

| Cluster | $HOME | $SCRATCH | $PROJECT | Filesystem |
|---|---|---|---|---|
| Cedar | 526 TB shared | 5.4 PB | 23 PB | Lustre (DDN ES14K) |
| Graham | 133 TB shared | 3.2 PB | 16 PB | Lustre |
| Béluga | 105 TB shared | 2.6 PB | 25 PB | Lustre |
| Narval | 40 TB shared | 5.5 PB | 19 PB | Lustre |
| Niagara | 200 TB shared | 12.5 PB + 232 TB burst-buffer | 3.5 PB | IBM Spectrum Scale (GPFS) |
| Fir | 51 PB total (2 PB NVMe + 49 PB SAS) | (same pool) | (same pool) | Single-pool (verify partitioning) |
| Killarney | 1.7 PB total (all NVMe VastData) | (same pool) | (same pool) | VastData |
| Trillium | VERIFY | VERIFY | VERIFY | VERIFY |
| Rorqual | several PB (details TBD per mirror) | VERIFY | VERIFY | VERIFY |

Per-user quotas are not the same as total volume — run `diskusage_report` on
the cluster to see your actual quota and current usage.

## Keep everything in `$SCRATCH`

`$HOME` is small and on slower NFS (Lustre on some clusters). It fills fast
and running jobs from it can fail on write errors. Standard pattern:

1. **Symlink caches into scratch** (Alliance often pre-symlinks `~/.cache` and
   `~/.local` to scratch — check with `readlink ~/.cache`).
2. **Export cache env vars in `~/.bashrc`** so any tool that bypasses XDG
   still lands in scratch:
   ```bash
   export PIP_CACHE_DIR=$SCRATCH/.cache/pip
   export UV_CACHE_DIR=$SCRATCH/.cache/uv
   export HF_HOME=$SCRATCH/.cache/huggingface
   export TORCH_HOME=$SCRATCH/.cache/torch
   export XDG_CACHE_HOME=$SCRATCH/.cache
   export TMPDIR=$SCRATCH/tmp
   ```
3. **Verify in a fresh login shell:**
   ```bash
   env | grep -E "(CACHE|TMPDIR|HF_HOME)="
   # All values must begin with $SCRATCH/
   ```

## Job-local fast disk: `$SLURM_TMPDIR`

Every Alliance compute node provides a per-job temporary directory at
`$SLURM_TMPDIR` (typically a fast local SSD/NVMe). On most clusters it's
machine-local, so:

- **Best practice:** copy input data to `$SLURM_TMPDIR` at job start, do all
  fast I/O there, copy results back to `$SCRATCH` at job end. This avoids
  hammering the parallel filesystem when many small files are involved.
- The directory and its contents **disappear when the job ends** — copy
  anything you need to keep before the job exits.
- Some clusters let you size it: `--tmp=2400G` on Béluga gets you 2.4 TB
  (range typically 350–2490 GB). On Fir / Cedar / Graham the size is
  determined by node hardware.
- **`$SLURM_TMPDIR` may not be set in your env on every cluster.** On Fir, the
  per-job NVMe scratch is mounted at `/localscratch/$USER.$SLURM_JOB_ID.0/`
  but the env var is not auto-exported — see `clusters/fir.md`. Construct the
  path explicitly in your job script if `$SLURM_TMPDIR` is empty.

Pattern inside a job script:

```bash
# Guard: on Fir (and any cluster where $SLURM_TMPDIR isn't auto-exported)
# fall back to the per-job NVMe mount before using it.
: "${SLURM_TMPDIR:=/localscratch/$USER.$SLURM_JOB_ID.0}"
cp -r $SCRATCH/dataset $SLURM_TMPDIR/
python train.py --data $SLURM_TMPDIR/dataset
cp -r $SLURM_TMPDIR/results $SCRATCH/results_${SLURM_JOB_ID}/
```

## Staging targets — what counts against which quota

The single most common mistake is staging a large dataset to `/tmp`, hitting
the cgroup memory limit, and getting OOM-killed mid-stage. Targets to
consider:

| Target | Backed by | Counts against | Per-job clean? | Verdict |
|---|---|---|---|---|
| `/tmp` (tmpfs) | RAM | **`--mem=` cgroup** | partial | OK only for **< 5 % of `--mem=`** |
| `$SLURM_TMPDIR` / `/localscratch/<user>.<jobid>.0/` | local NVMe | nothing per-user | yes (auto-cleaned) | **DEFAULT for staging** |
| `$SCRATCH` | parallel FS (Lustre / GPFS) | scratch quota | no | source/destination, not staging |
| `$PROJECT` | parallel FS, slow | project quota | no | archive only — not for active I/O |

The `/tmp` trap: tmpfs is RAM-backed. Bytes in `/tmp` are charged to your
cgroup memory allocation. A `cp` of a 30 GB dataset to `/tmp` inside a
`--mem=64G` job leaves you with 34 GB for everything else (Python process,
dataloader workers, page cache). Once a 65th GB lands the cgroup OOM-killer
SIGKILLs the job — `sacct` shows `State=CANCELLED` / `ExitCode=0:0` even
though no `scancel` was issued. **Observed on Fir 2026-05-06**: a 28 GB
`cp` of NPZ files into /tmp on a `--mem=64G` allocation tripped the
cgroup-OOM partway through and SIGKILLed the job mid-stage.

Always check disk quotas / capacity before staging:

```bash
diskusage_report                # per-user $HOME/$SCRATCH/$PROJECT quota
df -h /localscratch             # node-local NVMe free space
df -h /tmp                      # tmpfs (capped by your --mem=)
```

## Bulk staging recipe — many small files

When the dataset is many small files (< 100 MB each) on a parallel
filesystem, **per-file metadata latency dominates** — single-stream `cp -r`
runs at the speed of one metadata-server round-trip per file. Parallelising
the copy hides this latency.

Empirical numbers from a Fir GPU node (`fc10920`, 2026-05-06, 9700-NPZ
dataset, 13 MB avg, GPFS source → `/localscratch` NVMe destination, cold
page cache):

| Parallelism | Throughput | Time for 128 GB |
|---|---|---|
| `cp -r` (P=1) | 74 MB/s | ~28 min |
| `xargs -P 4` | 313 MB/s | ~7 min |
| `xargs -P 8` | 978 MB/s | ~2.2 min |
| `xargs -P 16` | 1367 MB/s | ~1.6 min |
| `xargs -P 32` | 1691 MB/s | ~1.3 min |

P=8 is a sensible default — it matches a typical `--cpus-per-task=8`
allocation and saturates >900 MB/s without monopolising the metadata server.
Past P=16 the curve flattens.

Recipe (drop into a job script after `module load` / `cd $SCRATCH/<repo>`):

```bash
LOCAL_SCRATCH="${SLURM_TMPDIR:-/localscratch/${USER}.${SLURM_JOB_ID}.0}"
STAGED_DATA="${LOCAL_SCRATCH}/<your_dataset>"
mkdir -p "$STAGED_DATA"
SECONDS=0
( cd "$SCRATCH/<repo>/data/<your_dataset>" \
  && find . -maxdepth 1 -name "*.npz" -print0 | xargs -0 -P 8 -I {} cp {} "$STAGED_DATA/" )
echo "Stage: ${SECONDS}s for $(du -sh "$STAGED_DATA" | cut -f1)"

python train.py --data "$STAGED_DATA"
```

For a single big file or a tarball, use a single-stream pipe
(`tar -C src -cf - . | tar -C dst -xf -`) and skip `xargs`.

## I/O speedup expected from staging

Per-NPZ-file open + read benchmark (Fir, 64 random 13 MB NPZ files, mean of
3 runs, 2026-05-06):

| Source | files/s | open p50 | open p99 | decode p50 |
|---|---|---|---|---|
| `/scratch` cold (GPFS, first read) | 3.76 | 60 ms | **464 ms** | 87 ms |
| `/scratch` warm (GPFS, page-cached) | 5.93 | 0.8 ms | 1.8 ms | 86 ms |
| `/localscratch` NVMe | **19.4** | 0.1 ms | 0.7 ms | 32 ms |
| `/tmp` tmpfs (RAM) | 19.2 | 0.1 ms | 0.7 ms | 33 ms |

Two cost components:
1. **GPFS open latency** — p99 spikes to ~460 ms when cold; this produces the
   multi-second `data_time` stalls visible mid-epoch in dataloader logs.
2. **Decompression** — 86 ms (GPFS) vs 32 ms (NVMe) per `np.load(...)['imgs']`.
   GPFS streaming reads through a small warm cache; NVMe + page cache is much
   faster. The deflate decode itself is the same; the difference is how
   quickly bytes reach the CPU.

End-to-end: a `data_time`-bound training loop typically drops to be
`compute_time`-bound after staging — a 3–6× per-step speedup is common when
GPFS warm reads are the baseline.

## When NOT to stage

Staging buys throughput at the cost of upfront copy time. Skip it when:

- The dataset is **smaller than the kernel page cache** that one epoch already
  warms — second-epoch reads are sub-ms either way.
- The job is **shorter than ~3× the stage time** (e.g. a 10-min eval with a
  5-min stage rarely amortises).
- You only **read each file once per job** — staging adds one extra full read.

The win is biggest for **multi-epoch training over many small files** where
the same files are re-read ~`max_epochs` times.

## Purge policies

- **`$SCRATCH` is purged** when files are inactive (typically 60 days). Move
  anything you want to keep long-term to `$PROJECT`.
- **`$PROJECT` is allocated**: small default for unallocated groups (~1 TB),
  much larger after RAC. Apply via the CCDB portal.
- **Burst buffer** (Niagara only): also purged, like scratch, but much faster.
  Use for I/O-bound parallel jobs.

## Common gotchas

- **Submitting jobs from `/home`** is forbidden on Cedar and several other
  clusters: "Submitting jobs from directories residing in /home is not
  permitted". Always `cd $SCRATCH/<project>` first.
- **`/scratch` filesystem performance varies** — Lustre (Cedar/Graham/etc.) is
  optimized for parallel large-file I/O; many small files hit metadata
  latency. Use `$SLURM_TMPDIR` for many-small-file workloads.
- **`/project` is NOT for active jobs**: it's not designed for parallel I/O.
  Read or write `$SCRATCH` during a job, sync to `$PROJECT` afterward.

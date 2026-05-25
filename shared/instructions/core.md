# Shared HPC Configuration

Tool-agnostic guidance shared by Claude Code and Codex so they do not drift.
**Keep this lean** — it is injected into the always-loaded instruction file.
Cluster-specific facts, submission recipes, GPU sizing, and storage/billing
tables live in the on-demand **`ccdb-clusters`** skill (`references/`), not here.

## Storage (Alliance Canada)

- `$HOME` — small fixed quota, backed up. Config / scripts / dotfiles only;
  never large or growing files.
- `$SCRATCH` — large, high-performance, **purged** after ~60 days of inactivity.
  Active-job I/O and logs. Never treat as permanent storage.
- `$PROJECT` — RAC-allocated, backed up. Durable datasets and checkpoints.
- For many-small-file I/O, stage hot data to node-local `$SLURM_TMPDIR` and copy
  results back to `$SCRATCH`/`$PROJECT` before the job exits. The staging recipe
  and quota details are in the `ccdb-clusters` skill.

## Compute discipline

- Login nodes = light tasks only (edit, git, small scripts). Heavy work
  (compile / train / install) goes through `sbatch` / `salloc` / `srun`.
- Check `hostname` before running anything heavy. GPUs exist only inside a
  SLURM allocation.
- Write long-running logs to a persistent, inspectable location (`logs/` or `$SCRATCH`).

## Experiment discipline

Track every SLURM experiment with structured, reproducible records — a config
snapshot, run metadata (including git commit + dirty state), and a status file
as the single source of truth. The experiment-workflow skills define the
recommended per-run layout; do not inline the schema here. Pin seeds, log
hyperparameters, and version-control configs.

## Coding conventions

- Prefer clarity over cleverness; use type hints in Python where practical.
- Use virtual environments (or the CCDB module Python); never install packages globally.

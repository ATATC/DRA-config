---
name: slurm-seff-report
description: Modify a Slurm job script to write a self-contained CPU + memory usage report at the end, reading kernel cgroup-v2 files (memory.peak, cpu.stat) directly — works in-script because it does not depend on sacct/seff finalizing only after the job exits. Use when you want a job to automatically self-report its CPU/memory efficiency without a follow-up job.
allowed-tools: Read, Edit, Write, Glob, Grep
---

# Add an Inline Cgroup-Based Usage Report

Modify the user's existing Slurm job script so it writes a per-job usage report
(`logs/<job_name>_<jobid>_usage.txt`) at the **end** of the script, by reading the kernel's
cgroup-v2 accounting files directly.

## Why this pattern (and not `seff $SLURM_JOB_ID` in-script)

- `seff` queries `sacct`. While the job script is still running, the job is in state `RUNNING`
  and `sacct` has **not finalized** the per-step accounting (`TotalCPU`/`Elapsed`/CPU efficiency).
  In-script `seff` therefore prints incomplete or misleading data, or refuses with "Job is still
  running".
- A follow-up `--dependency=afterany` sbatch that runs `seff` post-completion is the obvious
  alternative, but on Alliance clusters where the user's CPU account has low FairShare the
  follow-up can queue indefinitely. No scheduler dependency is acceptable here.
- The **cgroup-v2 files** (`memory.peak`, `cpu.stat`) are kernel-tracked **continuously**, are
  accurate at the moment you read them, and exist inside the job's own cgroup. Verified live on
  Fir 2026-05 (RHEL 9 EL9, kernel 5.14, cgroup v2) inside a real `srun` job step.

GPU efficiency is **not** available from cgroup — the cluster's `sacct`/`seff` is the correct
source for that, **after** the job exits. The report points the user there.

## Inputs

The user provides one of:
- A path to an existing `.sh` / `.slurm` job script
- The contents of an existing job script

If neither is given, ask.

## Workflow

### 1. Inspect the script

- `#SBATCH` directives, job name, output dir, shell conventions
- Whether a usage-report block is already present (look for the `Self-contained cgroup-based
  usage report` marker, **or** the old `seff "$SLURM_JOB_ID"` pattern that this skill used to
  insert) — replace in place rather than appending a duplicate.

### 2. Insert the report block at the end of the script

Add the block **after** the main workload command, before any final `echo "End"` line if present.
Keep the marker comment exactly as written so future runs of this skill find and update the block
instead of duplicating it.

```bash
# ---- Self-contained cgroup-based usage report (do not depend on sacct finalize) ----
REPORT_DIR="${SLURM_SUBMIT_DIR:-$PWD}/logs"
mkdir -p "$REPORT_DIR"
USAGE_REPORT="${REPORT_DIR}/${SLURM_JOB_NAME:-job}_${SLURM_JOB_ID}_usage.txt"

# Job's own cgroup path (cgroup v2; /proc/self/cgroup line begins "0::/...")
JOB_CG=$(awk -F: '/^0::/{print $3; exit}' /proc/self/cgroup 2>/dev/null)

# Peak memory (bytes) — kernel-tracked, accurate at read time
MEM_PEAK="unavailable"
if [ -n "$JOB_CG" ] && [ -r "/sys/fs/cgroup${JOB_CG}/memory.peak" ]; then
  MEM_PEAK=$(cat "/sys/fs/cgroup${JOB_CG}/memory.peak")
fi

# Total CPU time (microseconds across all task threads)
CPU_USEC="unavailable"
if [ -n "$JOB_CG" ] && [ -r "/sys/fs/cgroup${JOB_CG}/cpu.stat" ]; then
  CPU_USEC=$(awk '/^usage_usec/{print $2}' "/sys/fs/cgroup${JOB_CG}/cpu.stat")
fi

WALL_SEC="${SECONDS:-unavailable}"

{
  echo "Slurm job usage report"
  echo "  Job ID    : ${SLURM_JOB_ID}"
  echo "  Job name  : ${SLURM_JOB_NAME:-?}"
  echo "  Generated : $(date -Iseconds)"
  echo "  Host      : $(hostname)"
  echo
  echo "== Resources requested =="
  echo "  --cpus-per-task  : ${SLURM_CPUS_PER_TASK:-?}"
  echo "  --mem (per node) : ${SLURM_MEM_PER_NODE:-?} MB"
  echo "  --gpus-per-node  : ${SLURM_GPUS_PER_NODE:-?}"
  echo
  echo "== Cgroup measurements (kernel-direct; accurate at end of script) =="
  if [ "$MEM_PEAK" != "unavailable" ]; then
    awk -v b="$MEM_PEAK" 'BEGIN{ printf "  Peak memory      : %s bytes (%.2f GB)\n", b, b/1024/1024/1024 }'
    if [ -n "$SLURM_MEM_PER_NODE" ]; then
      awk -v p="$MEM_PEAK" -v r="$SLURM_MEM_PER_NODE" \
        'BEGIN{ printf "  Memory efficiency: %.1f%% of requested\n", p/(r*1024*1024)*100 }'
    fi
  else
    echo "  Peak memory      : unavailable (cgroup v1 / EL7 cluster?)"
  fi
  echo "  CPU time         : ${CPU_USEC} us"
  echo "  Wall time        : ${WALL_SEC} s"
  if [ "$CPU_USEC" != "unavailable" ] && [ -n "$SLURM_CPUS_PER_TASK" ] \
     && [ "$WALL_SEC" != "unavailable" ] && [ "$WALL_SEC" -gt 0 ]; then
    awk -v c="$CPU_USEC" -v w="$WALL_SEC" -v n="$SLURM_CPUS_PER_TASK" \
      'BEGIN{ printf "  CPU efficiency   : %.1f%% of (wall * n_cpus)\n", c/(w*1000000*n)*100 }'
  fi
  echo
  echo "Note: cgroup numbers are kernel-direct. For finalized post-completion accounting"
  echo "(incl. GPU efficiency, which cgroup does not expose), run after the job exits:"
  echo "  seff ${SLURM_JOB_ID}"
} > "${USAGE_REPORT}" 2>&1
echo "Usage report -> ${USAGE_REPORT}"
# ---- End usage report ----
```

### 3. If the old `seff`-in-script block is found

The previous version of this skill inserted `seff "$SLURM_JOB_ID"` in-script. That pattern is
**broken** (sacct unfinalized while the job is still running). Replace any such block with the
cgroup-based block above — do not leave both.

### 4. Tell the user what changed

- Which script was edited
- The usage-report path (`logs/<job_name>_<jobid>_usage.txt`)
- That **CPU + memory** are now kernel-direct (no sacct dependency) and accurate at end of script
- That **GPU efficiency** is not in this report — `seff <jobid>` after the job exits is the
  source for that (cgroup does not track GPU)

## Editing Rules

- Scope edits to the report block; do not refactor unrelated job logic.
- Preserve existing comments and shell setup.
- If the user pasted contents (not a path), return the full modified script.
- If a file path was given, edit in place.

## Limitations

- **GPU efficiency** is not in this report — see the footer note that points the user to
  `seff <jobid>` after the job exits.
- **Cgroup v1** systems (older Alliance clusters on EL7/CentOS 7) do not expose
  `memory.peak` / `cpu.stat` at the documented v2 paths. On those systems the report will say
  `unavailable` for affected fields and otherwise still produce a useful skeleton. Fir, Trillium,
  Rorqual, Killarney (all EL9, cgroup v2) are fully supported. Verified on Fir 2026-05.

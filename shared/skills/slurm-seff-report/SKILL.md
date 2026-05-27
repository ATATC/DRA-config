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

# Resolve the job's own cgroup-v2 path (the "0::/..." line in /proc/self/cgroup)
JOB_CG=$(awk -F: '/^0::/{print $3; exit}' /proc/self/cgroup 2>/dev/null)

# Peak memory in bytes and total CPU microseconds (both kernel-tracked continuously)
MEM_PEAK="unavailable"; CPU_USEC="unavailable"
[ -n "$JOB_CG" ] && [ -r "/sys/fs/cgroup${JOB_CG}/memory.peak" ] && \
  MEM_PEAK=$(cat "/sys/fs/cgroup${JOB_CG}/memory.peak")
[ -n "$JOB_CG" ] && [ -r "/sys/fs/cgroup${JOB_CG}/cpu.stat" ] && \
  CPU_USEC=$(awk '/^usage_usec/{print $2}' "/sys/fs/cgroup${JOB_CG}/cpu.stat")

# Format the report in seff-like style: GB / HH:MM:SS / efficiency lines
awk -v jid="$SLURM_JOB_ID" -v jname="${SLURM_JOB_NAME:-?}" \
    -v host="$(hostname)" -v gen="$(date -Iseconds)" \
    -v cpus="${SLURM_CPUS_PER_TASK:-1}" -v mem_req_mb="${SLURM_MEM_PER_NODE:-0}" \
    -v gpu_req="${SLURM_GPUS_PER_NODE:-?}" \
    -v mem_peak="$MEM_PEAK" -v cpu_usec="$CPU_USEC" -v wall_sec="${SECONDS:-0}" \
'function hms(s,    h,m,ss){ h=int(s/3600); m=int((s%3600)/60); ss=int(s%60);
  return sprintf("%02d:%02d:%02d", h, m, ss) }
 BEGIN{
  print "Slurm job usage report (cgroup-direct, end-of-script)"
  printf "  Job ID    : %s\n  Job name  : %s\n  Host      : %s\n  Generated : %s\n\n", \
    jid, jname, host, gen
  print "== Resources requested =="
  printf "  --cpus-per-task : %s\n  --mem (per node): %s MB\n  --gpus-per-node : %s\n\n", \
    cpus, mem_req_mb, gpu_req
  print "== Cgroup measurements (kernel-direct; accurate at end of script) =="
  if (mem_peak == "unavailable") {
    print "  Memory Utilized  : unavailable (cgroup v1 / EL7 cluster?)"
  } else {
    mb = mem_peak/1048576; gb = mb/1024
    if (gb >= 1) printf "  Memory Utilized  : %.2f GB\n", gb
    else         printf "  Memory Utilized  : %.2f MB\n", mb
    if (mem_req_mb+0 > 0)
      printf "  Memory Efficiency: %.1f%% of %.2f GB (requested)\n", mb/mem_req_mb*100, mem_req_mb/1024
  }
  if (cpu_usec == "unavailable") {
    print "  CPU Utilized     : unavailable"
  } else {
    printf "  CPU Utilized     : %s\n", hms(cpu_usec/1000000)
  }
  if (wall_sec+0 > 0) printf "  Wall-clock time  : %s\n", hms(wall_sec)
  if (cpu_usec != "unavailable" && wall_sec+0 > 0 && cpus+0 > 0) {
    cw  = wall_sec * cpus
    eff = (cpu_usec/1000000) / cw * 100
    printf "  CPU Efficiency   : %.2f%% of %s core-walltime (wall * %s cpus)\n", eff, hms(cw), cpus
  }
  print ""
  print "Note: cgroup numbers are kernel-direct (no sacct dependency). For finalized"
  print "post-completion accounting including GPU efficiency, run after the job exits:"
  printf "  seff %s\n", jid
}' > "$USAGE_REPORT"
echo "Usage report -> $USAGE_REPORT"
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

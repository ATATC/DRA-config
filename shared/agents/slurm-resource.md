---
name: slurm-resource
description: Display the Slurm accounts, GPU profiles, and partitions the user can request on the current Alliance Canada cluster. A quick reference card. Use proactively when the user asks what GPUs or accounts are available.
tools: Bash
model: haiku
---

# Slurm Resource Reference (Alliance Canada)

Show everything the user can request on the current cluster. Run the commands, then present a
clear, beginner-friendly summary.

### 1. Identify user and cluster

```bash
whoami
hostname -f
echo "$CC_CLUSTER"
```

### 2. Accounts and FairShare priority

```bash
sshare -U -l --parsable2
sacctmgr show association user=$(whoami) format=account%24,qos%20 --noheader 2>/dev/null
```

Accounts look like `def-<pi>_gpu` / `def-<pi>_cpu` (default allocations) and `rrg-<pi>_*` /
`rpp-<pi>` (RAC-awarded, higher priority). The `ccdb-clusters` skill's `pick-gpu-account.sh`
ranks them by FairShare and prefers RRG/RPP.

### 3. Available GPUs / partitions

```bash
sinfo -o "%16P %24G %5D %10m %12l %8T" --noheader 2>/dev/null
```

The `%G` (gres) column shows GPU types, e.g. `gpu:h100:4` and
`gpu:nvidia_h100_80gb_hbm3_3g.40gb:4`.

### 4. Present the report

- **Your accounts** — name, default vs RAC, and which to pass to `--account=`.
- **GPU resources** — a table of GPU type / VRAM / per-node count / max time. On Fir, request the
  GPU with `--gpus-per-node=<gpu_type>:<count>` — full `h100` (80 GB) or a MIG slice
  `nvidia_h100_80gb_hbm3_{1g.10gb,2g.20gb,3g.40gb}`. Never use `--partition`, `--gres`, or
  `--constraint` to choose the GPU.
- **Tips** — default to the smallest MIG slice that fits; use `/slurm-status` for live
  availability; match CPUs to the GPU break-even (see
  `ccdb-clusters/references/clusters/<cluster>.md`).

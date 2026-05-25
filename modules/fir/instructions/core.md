# Fir HPC Cluster (Alliance Canada)

You are on **Fir** (Digital Research Alliance of Canada), an H100 cluster that
keeps the Cedar filesystem layout. `$CC_CLUSTER=fir`, `$CC_RESTRICTED=true`
(export-control rules apply).

- **Account**: `{{FIR_ACCOUNT}}` — a shared Alliance allocation; it affects
  scheduling priority, not a hard simultaneous-GPU cap. Pick the best account at
  submit time with the `ccdb-clusters` helper `pick-gpu-account.sh`.
- **GPUs**: full `h100` (80 GB) and MIG slices
  `nvidia_h100_80gb_hbm3_{1g.10gb,2g.20gb,3g.40gb}`. Default to the smallest MIG
  slice that fits the workload.
- **GPU request rule**: choose the GPU with `--gpus-per-node=<gpu_type>:<count>`
  only. Never use `--partition`, `--gres`, or `--constraint`.
- Smoke-test on the smallest profile first; after each job run `seff <jobid>`
  and trim over-requested CPU / mem / time / GPU.

For submission templates, GPU sizing and break-even tables, storage quotas, and
MAX_TRES billing, use the **`ccdb-clusters`** and **`slurm-job`** skills (loaded
on demand) — those tables are intentionally not inlined here.

Connect from a local machine via the `fir.alliancecan.ca` host in
`~/.ssh/config` with ControlMaster (enter password + Duo once in your own
terminal; the socket is reused). See the `connect` skill. Run `/slurm-status`
before submitting large jobs.

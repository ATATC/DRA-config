# Fir Claude Notes

- Use `/slurm-status` to check real-time availability before submitting large jobs.
- Fir is a shared Alliance cluster. Prefer `salloc`, `srun`, or `sbatch` for heavy work instead of the login node.
- Fir has both full `h100` GPUs and H100 MIG profiles: `nvidia_h100_80gb_hbm3_1g.10gb`, `nvidia_h100_80gb_hbm3_2g.20gb`, and `nvidia_h100_80gb_hbm3_3g.40gb`.
- For Fir job scripts, specify the GPU only with `--gpus-per-node=<gpu_type>:<count>`. Do not use `--partition`, `--gres`, or `--constraint`.
- Before running the actual job, do a smoke test on the smallest feasible profile.
- After a job finishes, run `seff <jobid>` and reduce future requests so jobs do not ask for materially more CPU, memory, time, or GPU than they use.
- When working on a local machine, connect to Fir via the `fir.alliancecan.ca` host in `~/.ssh/config` using ControlMaster (the user completes password + Duo once in their own terminal; the socket is then reused). See the `connect` skill. Do not collect the Duo passcode in chat.

Once connected:

```bash
sinfo -p {{FIR_PARTITION}} -o "%12P %16G %5D %8T %10C %12m"
squeue -u $(whoami)
```

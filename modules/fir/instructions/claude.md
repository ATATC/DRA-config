# Fir Claude Notes

- Use `/slurm-status` to check real-time availability before submitting large jobs.
- Fir is a shared Alliance cluster. Prefer `salloc`, `srun`, or `sbatch` for heavy work instead of the login node.
- Fir has both full `h100` GPUs and H100 MIG profiles: `nvidia_h100_80gb_hbm3_1g.10gb`, `nvidia_h100_80gb_hbm3_2g.20gb`, and `nvidia_h100_80gb_hbm3_3g.40gb`.
- Before running the actual job, do a smoke test on the smallest feasible profile.
- After a job finishes, run `seff <jobid>` and reduce future requests so jobs do not ask for materially more CPU, memory, time, or GPU than they use.
- When working on a local machine, connect to Fir with `ssh -i ~/.ssh/id_rsa -Y ${USER}@fir.alliancecan.ca` and ask the user for their DUO passcode before starting the login.

Once connected:

```bash
sinfo -p {{FIR_PARTITION}} -o "%12P %16G %5D %8T %10C %12m"
squeue -u $(whoami)
```

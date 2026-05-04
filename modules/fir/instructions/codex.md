# Fir Codex Notes

- Use the `slurm-status` skill to check real-time availability before submitting large jobs.
- Fir is a shared Alliance cluster. Prefer `salloc`, `srun`, or `sbatch` for heavy work instead of the login node.
- Fir has both full `h100` GPUs and H100 MIG profiles: `nvidia_h100_80gb_hbm3_1g.10gb`, `nvidia_h100_80gb_hbm3_2g.20gb`, and `nvidia_h100_80gb_hbm3_3g.40gb`.

Once connected:

```bash
sinfo -p {{FIR_PARTITION}} -o "%12P %16G %5D %8T %10C %12m"
squeue -u $(whoami)
```

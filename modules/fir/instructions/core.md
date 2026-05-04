# Fir HPC Cluster

This is the Digital Research Alliance of Canada Fir cluster, the H100-based successor to Cedar. Fir retains the Cedar filesystem layout.

## Accounts

| Account | Partition | GPU Type / Constraint | Notes |
|---|---|---|---|
| `{{FIR_ACCOUNT}}` | `{{FIR_PARTITION}}` | `{{FIR_GPU_TYPE}}` | Shared Alliance allocation; priority depends on account and recent usage |

## GPU Resources

| Cluster | GPU | Notes |
|---|---|---|
| Fir | `h100` | Full H100 with 80 GB HBM3 |
| Fir | `nvidia_h100_80gb_hbm3_3g.40gb` | MIG slice with 40 GB |
| Fir | `nvidia_h100_80gb_hbm3_2g.20gb` | MIG slice with 20 GB |
| Fir | `nvidia_h100_80gb_hbm3_1g.10gb` | MIG slice with 10 GB |

## Common Submission Patterns

```bash
# Single full H100
sbatch --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint={{FIR_GPU_TYPE}} --gres=gpu:1 --cpus-per-task=12 --mem=124G --time=8:00:00 job.sh

# Multi-GPU full H100
sbatch --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint={{FIR_GPU_TYPE}} --gres=gpu:4 --cpus-per-task=48 --mem=496G --time=8:00:00 job.sh

# 40 GB MIG
sbatch --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint=nvidia_h100_80gb_hbm3_3g.40gb --gres=gpu:1 --cpus-per-task=6 --mem=64G --time=8:00:00 job.sh

# 20 GB MIG
sbatch --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint=nvidia_h100_80gb_hbm3_2g.20gb --gres=gpu:1 --cpus-per-task=4 --mem=32G --time=8:00:00 job.sh

# 10 GB MIG
sbatch --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint=nvidia_h100_80gb_hbm3_1g.10gb --gres=gpu:1 --cpus-per-task=2 --mem=16G --time=8:00:00 job.sh

# Interactive session
salloc --account={{FIR_ACCOUNT}} --partition={{FIR_PARTITION}} --constraint={{FIR_GPU_TYPE}} --gres=gpu:1 --cpus-per-task=12 --mem=124G --time=4:00:00
srun --pty bash
```

## Storage Paths

| Storage | Path | Quota | Notes |
|---|---|---|---|
| Home | `/home/{{FIR_USERNAME}}/` | 50 GB / 500k files | Backed up |
| Scratch | `/scratch/{{FIR_USERNAME}}/` | 20 TB / 1M files | Purged; use for active jobs and logs |
| Project | `/project/<group>/` | 1 TB default per user per cluster | Backed up; request increases if needed |

## Key Constraints

- Fir is a shared Alliance cluster. Account allocations affect scheduling priority; they are not a hard simultaneous GPU cap.
- Fir exposes both full H100s (`h100`) and H100 MIG slices. Match `--constraint` to the smallest profile that fits the workload.
- Scratch is not backed up and old files are purged. Keep durable data in home or project storage.
- Fir keeps the legacy Cedar filesystem layout, so older Cedar storage paths may still apply.
- Use the Slurm status helper before submitting large jobs.

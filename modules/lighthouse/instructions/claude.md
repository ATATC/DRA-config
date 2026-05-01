# Lighthouse Claude Notes

- Use `/slurm-status` to check real-time availability before submitting large jobs.
- If you also use Great Lakes, run `/connect` to set up SSH.

Once connected:

```bash
ssh greatlakes "sinfo -p spgpu2"
ssh greatlakes "squeue -u $(whoami)"
```

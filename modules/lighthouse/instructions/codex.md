# Lighthouse Codex Notes

- Use the `slurm-status` skill to check real-time availability before submitting large jobs.
- If you also use Great Lakes, use the `connect` skill to set up SSH.

Once connected:

```bash
ssh greatlakes "sinfo -p spgpu2"
ssh greatlakes "squeue -u $(whoami)"
```

# Great Lakes Codex Notes

- Use the `slurm-status` skill to check real-time availability before submitting large jobs.
- If you also use Lighthouse, use the `connect` skill to set up SSH.

Once connected:

```bash
ssh lighthouse "sinfo"
ssh lighthouse "squeue -u $(whoami)"
```

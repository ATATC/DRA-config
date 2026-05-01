# Great Lakes Claude Notes

- Use `/slurm-status` to check real-time availability before submitting large jobs.
- If you also use Lighthouse, run `/connect` to set up SSH.

Once connected:

```bash
ssh lighthouse "sinfo"
ssh lighthouse "squeue -u $(whoami)"
```

# Codex Adapter

This file contains Codex-specific instructions layered on top of the shared lab configuration.

## Codex Operating Rules

- Be careful on shared HPC login nodes. Before running expensive commands, check `hostname` and whether `SLURM_JOB_ID` is set.
- If `SLURM_JOB_ID` is unset and the host ends in `.alliancecan.ca` (or matches a cluster short name like `fir*`), treat the shell as a login node.
- If the hostname does not look like a cluster login node, treat the machine as a local machine or laptop.
- On login nodes, only run lightweight inspection, editing, Git, package management, and Slurm control commands.
- Do not run training, inference, test suites, large data processing, compilation of large codebases, or sustained CPU/GPU/I/O work on login nodes. Use `srun`, `salloc`, or `sbatch` instead.
- Inside a Slurm allocation (`SLURM_JOB_ID` set), arbitrary workloads are allowed.
- On a local machine or laptop, run cluster-specific commands remotely when needed. For Fir work, use `ssh fir.alliancecan.ca "<command>"` (via the `~/.ssh/config` host set up by `onboard`) unless already on the Fir login node.

## Available Codex Skills

Ask Codex to use these skills by name:

- `slurm-status` - real-time GPU and resource availability on the cluster.
- `slurm-job` - create or modify sbatch scripts with correct accounts, partitions, and best practices.
- `slurm-seff-report` - retrofit a job script so it schedules a post-job `seff` usage report.
- `slurm-debug` - diagnose why a Slurm job failed, was killed, or is stuck.
- `submit-experiment` - submit a Slurm experiment with naming, documentation, and remote-submission support.
- `harvest` - discover completed experiments, collect results, and update documentation.
- `onboard` - set up a lab member's Claude Code and/or Codex configuration.
- `connect` - decide local vs remote cluster operation and establish SSH access, including local machine -> Fir.
- `slurm-queue` - show active, pending, and recent jobs.
- `slurm-resource` - list accounts, partitions, and GPU types you can request.
- `slurm-storage` - scan home/scratch usage and suggest what to move to $PROJECT or $SCRATCH.

Some shared skill docs mention Claude slash commands such as `/slurm-status`. In Codex, treat those as references to the Codex skill with the same name.

## Codex-Specific Constraints

- Codex does not use Claude's `settings.json`, statusline command, or hooks directly.
- Login-node safety rules live in `AGENTS.md` for Codex instead of relying on Claude hooks.
- Claude agents are installed as Codex skills because Codex skills are the durable reusable instruction unit.

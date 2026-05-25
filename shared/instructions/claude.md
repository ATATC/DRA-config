# Claude Code Adapter

This file contains Claude Code-specific instructions layered on top of the shared lab configuration.

## Available Skills & Agents

Skills are invoked with `/command`:

- `/slurm-status` - real-time GPU and resource availability on the cluster.
- `/slurm-job` - create or modify sbatch scripts with correct accounts, GPU profiles, and best practices.
- `/slurm-seff-report` - retrofit a job script so it schedules a post-job `seff` usage report.
- `/slurm-debug` - diagnose why a job failed, was killed, or is stuck pending.
- `/submit-experiment` - submit a Slurm experiment with naming, documentation, and remote-submission support.
- `/harvest` - discover completed experiments, collect results, and update documentation.
- `/onboard` - set up a new lab member's Claude Code configuration.
- `/connect` - decide local vs remote cluster operation and establish SSH access, including local machine -> Fir.

Agents are invoked with `@agent-name` or used automatically by Claude when relevant:

- `slurm-queue` - show active, pending, and recent jobs with status and quick actions.
- `slurm-resource` - list accounts, partitions, and GPU types you can request.
- `slurm-storage` - scan home/scratch usage and suggest what to move to $PROJECT or $SCRATCH.

## Claude-Specific Automation

- `settings.json` configures Claude permissions, statusline, and hooks.
- `node-context.sh` runs as a `PreToolUse` hook for Bash and injects login-node versus compute-node context.
- Claude hooks are advisory. They should guide behavior without replacing the shared compute discipline in `shared/instructions/core.md`.

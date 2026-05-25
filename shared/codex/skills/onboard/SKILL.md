---
name: onboard
description: One-time setup to get a lab member onto Alliance Canada (DRAC) with the shared Claude Code and/or Codex config. Sets up SSH key access, detects the Slurm allocation account, writes saved values, and runs setup.sh.
---

# Alliance Canada Setup — Onboarding (one-time)

Help a lab member do the **one-time** setup that connects this shared config (Claude Code,
Codex, or both) to an Alliance Canada (DRAC / CCDB) cluster — Fir by default. Be concise.
Greet with **"Welcome onboard, Foreseer!"** and explain it sets up passwordless SSH access,
records the Slurm allocation account, and installs the lab config.

Two distinct things are needed: **(A) SSH login access** (username + a registered SSH key) and
**(B) a Slurm allocation account** (the `--account=` value, e.g. `def-<pi>_gpu`).

## Pre-flight

```bash
ls -ld ~/.claude ~/.codex 2>/dev/null
```

- If neither exists, ask the user to run `claude` or `codex` once first.
- Configure whichever exists (default both if both exist).
- Confirm the repo: `ls -d ~/DRA-config 2>/dev/null`; if missing:
  ```bash
  git clone https://github.com/ATATC/DRA-config.git ~/DRA-config
  ```

## Step A — SSH access (one-time; skip if already on a cluster login node)

If `hostname -f` ends in `.alliancecan.ca`, skip to Step B. Otherwise set up key-based access
from this local machine. **Only needed once per machine** — the `connect` skill reuses it and
never re-uploads.

1. Ensure a keypair: `ls ~/.ssh/*.pub 2>/dev/null`; if none:
   ```bash
   ssh-keygen -t ed25519 -C "<user-email-or-label>" -f ~/.ssh/id_ed25519
   ```
2. Register the PUBLIC key (one-time MFA on the website): print `cat ~/.ssh/id_ed25519.pub` and
   have the user paste it at <https://ccdb.alliancecan.ca/ssh_authorized_keys> (CCDB → Manage
   SSH Keys). Do not handle their password or Duo passcode.
3. Add a `~/.ssh/config` host entry (ask for the Alliance username if it differs from local
   `whoami`):
   ```text
   Host fir.alliancecan.ca
       User <ccdb_username>
       IdentityFile ~/.ssh/id_ed25519
       IdentitiesOnly yes
       ControlMaster auto
       ControlPath ~/.ssh/cm-%r@%h:%p
       ControlPersist 8h
   ```
4. Verify: `ssh fir.alliancecan.ca "hostname -f && whoami"`. A password prompt means the key
   has not propagated yet — wait and retry.

## Step B — Detect the Slurm allocation account

```bash
ssh fir.alliancecan.ca "whoami; sshare -U -l --parsable2 | head"
```

Alliance accounts look like `def-<pi>_gpu`, `rrg-<pi>_gpu` (RAC-allocated), `rpp-<pi>`. Prefer
RRG/RPP for GPU work; use `def-<pi>_cpu` for CPU jobs. The `ccdb-clusters` skill's
`pick-gpu-account.sh` ranks accounts by FairShare if you want it chosen automatically.

## Step C — Confirm and save

Show a short summary (username, cluster, GPU account). After confirmation, write
`~/DRA-config/build/.env.local`:

```bash
# Lab Claude Config - saved template variables
FIR_USERNAME=<ccdb_username>
FIR_ACCOUNT=<def-or-rrg account>
FIR_GPU_TYPE=h100
```

## Step D — Run setup

```bash
cd ~/DRA-config && ./setup.sh --modules fir --targets <targets> --non-interactive
```

Examples: `--targets codex` (Codex only), `--targets claude,codex` (both).

## Post-setup

- Claude: lab block in `~/.claude/CLAUDE.md`, settings, hooks, skills, agents.
- Codex: lab block in `~/.codex/AGENTS.md` and skills in `~/.codex/skills`.
- Personal content outside the lab markers is preserved.
- Update: `cd ~/DRA-config && git pull && ./setup.sh --modules fir --targets <targets>`.
- In Codex, ask for skills by name (e.g. "use the slurm-status skill"). `/connect` re-establishes
  SSH in later sessions without re-uploading the key.

## If setup fails

Read the error and help debug. Common issues: key not yet propagated, wrong account name, or a
missing `~/.claude` / `~/.codex` directory. `setup.sh` is idempotent.

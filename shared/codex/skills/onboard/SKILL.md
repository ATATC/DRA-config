---
name: onboard
description: One-time setup to get a lab member onto Alliance Canada (DRAC) with the shared Claude Code and/or Codex config. Use when first configuring Claude Code or Codex on a new machine for the cluster. Sets up key-based SSH with ControlMaster reuse where supported and a Windows Duo Push fallback, detects the Slurm allocation account, writes saved values, and runs setup.sh.
---

# Alliance Canada Setup — Onboarding (one-time)

Help a lab member do the **one-time** setup that connects this shared config (Claude Code,
Codex, or both) to an Alliance Canada (DRAC / CCDB) cluster — Fir by default. Be concise.
Greet with **"Welcome onboard, Foreseer!"** and explain it sets up key-based SSH with
ControlMaster reuse where supported (one interactive Duo login, then passwordless reuse), plus a
Windows askpass fallback that selects Duo Push while the user approves it. It also records the
Slurm allocation account and installs the lab config.

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
from this local machine. **Only needed once per machine** — `connect` reuses it and never
re-uploads.

**The agent cannot approve Duo for the user.** Fir requires **Duo 2FA on every fresh login, even
with a registered key** (the key is only factor 1). On Unix-like hosts, the user can complete an
interactive login and Codex can reuse its socket. On Windows, the bundled askpass helper can select
Duo Push, but the **user** must approve it on their device. Full detail (key formats, encrypted
keys, Windows, agent-driven Mode B, troubleshooting) is in
`references/fir-ssh-setup.md` (bundled with this skill).

1. Ensure a keypair (the user may already have one in any format — see the reference):
   `ls ~/.ssh/*.pub 2>/dev/null`; if none:
   ```bash
   ssh-keygen -t ed25519 -C "<user-email-or-label>" -f ~/.ssh/id_ed25519
   ```
2. Register the PUBLIC key (one-time MFA on the website): print `cat ~/.ssh/id_ed25519.pub` and
   have the user paste it at <https://ccdb.alliancecan.ca/ssh_authorized_keys> (CCDB → Manage
   SSH Keys). Propagation takes ~10–30 min. Never handle their password or Duo passcode.
3. Add a `~/.ssh/config` host entry (ask for the Alliance username if it differs from local
   `whoami`). ControlMaster provides passwordless reuse on platforms where it works:
   ```text
   Host fir.alliancecan.ca
       User <ccdb_username>
       IdentityFile ~/.ssh/id_ed25519
       IdentitiesOnly yes
       AddKeysToAgent yes
       ServerAliveInterval 60
       ControlMaster auto
       ControlPath ~/.ssh/cm-%r@%h:%p
       ControlPersist 8h
   ```
4. **First login.** Run `/connect`. On Unix-like hosts, the user can complete the login in a
   separate terminal and Codex reuses the socket. On Windows, `/connect` can use the bundled
   `fir-duo-push-askpass.cmd` helper to select Duo Push; tell the user a push is coming and have
   them approve it. The helper never approves the second factor. If the key is encrypted and not
   unlocked in `ssh-agent`, fall back to a separate terminal:
   ```bash
   ssh fir.alliancecan.ca "hostname -f && whoami"
   ```
   Enter the passphrase (if any), pick `1` at the Duo menu, and approve the push. On Windows, each
   independent connection may trigger another push, so batch commands when multiplexing is absent.
5. Verify (agent): on a working ControlMaster host, run `ssh -O check fir.alliancecan.ca` then
   `ssh fir.alliancecan.ca "hostname -f"`. On Windows, follow `/connect` and verify with its
   askpass command plus `-o ControlMaster=no -o ControlPath=none`.
   `Permission denied (publickey)` before any Duo prompt = real key problem; reaching the Duo prompt
   = normal 2FA (have the user finish it in their terminal).

## Step B — Detect the Slurm allocation account

**Prerequisite:** Step A's verify must have passed (socket live). If not — `Permission denied
(publickey)` (key still propagating, ~10–30 min) or Duo not done — finish Step A first.

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

## Step E — Smoke test (optional but recommended)

Verify the install routes correctly: open a fresh Codex session (or sub-context if your harness
supports one) and feed it the 18 routing cases in `~/DRA-config/evals/routing-trigger.json`
together with the 9 installed skill descriptions. For each case, the model should pick a
`picked_skill` that matches `expect`. Baseline:
`~/DRA-config/evals/routing-trigger-baseline.md` (18/18 routed, 17 clean). Failures point at a
description that needs tightening.

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

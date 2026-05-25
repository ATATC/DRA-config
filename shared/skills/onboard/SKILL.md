---
name: onboard
description: One-time setup to get a lab member onto Alliance Canada (DRAC) with this shared Claude Code config. Sets up SSH key access to the cluster, detects the Slurm allocation account, writes saved values, and runs setup.sh. Use when first configuring a machine.
allowed-tools: Bash(git *), Bash(hostname *), Bash(whoami), Bash(which *), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(chmod *), Bash(ssh-keygen *), Bash(ssh *), Bash(sinfo *), Bash(sshare *), Bash(sacctmgr *), Bash(*/setup.sh *), Bash(${CLAUDE_SKILL_DIR}/scripts/*), Read, Edit, Write
---

# Alliance Canada Setup — Onboarding (one-time)

You are helping a lab member do the **one-time** setup that connects this Claude Code
config to an Alliance Canada (DRAC / CCDB) cluster — Fir by default. Walk them through it
interactively; be concise. Greet with **"Welcome onboard, Foreseer!"** then explain: this
sets up passwordless SSH access to the cluster, records the user's Slurm allocation account,
and installs the lab config so Claude understands the cluster.

Two things are distinct and both needed: **(A) SSH login access** (username + a registered
SSH key) and **(B) a Slurm allocation account** (the `--account=` value, e.g. `def-<pi>_gpu`).

## Pre-flight

1. `ls -ld ~/.claude 2>/dev/null` — if missing, ask the user to run `claude` once first.
2. Confirm the repo is cloned: `ls -d ~/DRA-config 2>/dev/null`. If not:
   ```bash
   git clone https://github.com/ATATC/DRA-config.git ~/DRA-config
   ```
3. `which jq` — needed for Claude's statusline.

## Step A — SSH access (one-time; skip if already on a cluster login node)

If `hostname -f` already ends in `.alliancecan.ca`, you are on the cluster — skip to Step B.
Otherwise set up key-based access from this local machine. **This only needs to be done once
per machine** — the `connect` skill reuses it afterward and never re-uploads.

1. **Ensure an SSH keypair exists:**
   ```bash
   ls ~/.ssh/*.pub 2>/dev/null
   ```
   If none, create one (ed25519):
   ```bash
   ssh-keygen -t ed25519 -C "<user-email-or-label>" -f ~/.ssh/id_ed25519
   ```
2. **Register the PUBLIC key with CCDB (one-time MFA on the website):**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   Tell the user to paste that line at <https://ccdb.alliancecan.ca/ssh_authorized_keys>
   (CCDB → Manage SSH Keys). After it propagates (usually minutes), key-based login works on
   all Alliance clusters. Do **not** handle the user's password or Duo passcode in chat.
3. **Add a `~/.ssh/config` host entry** (ask for the Alliance username if it differs from local
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
   (ControlMaster is an optional speed-up — it reuses one connection. With a registered key it
   is not required, but it avoids repeated handshakes.)
4. **Verify:**
   ```bash
   ssh fir.alliancecan.ca "hostname -f && whoami"
   ```
   If this still prompts for a password, the key has not propagated yet — wait and retry.

## Step B — Detect the Slurm allocation account

Run on the cluster (directly if on a login node, else over the SSH from Step A). Don't make the
user look things up — run it yourself:

```bash
ssh fir.alliancecan.ca "whoami; sshare -U -l --parsable2 | head"
```

Pick the best GPU account with the bundled helper (ranks by FairShare, prefers RRG/RPP):

```bash
ssh fir.alliancecan.ca "bash -s" < ${CLAUDE_SKILL_DIR}/../ccdb-clusters/scripts/pick-gpu-account.sh
```

(or run `pick-gpu-account.sh` directly when on the cluster). Alliance accounts look like
`def-<pi>_gpu`, `rrg-<pi>_gpu` (RAC-allocated), `rpp-<pi>`. Use `def-<pi>_cpu` for CPU jobs.

## Step C — Confirm and save

Show a short, plain-language summary: username, cluster (Fir), and the GPU account you'll
record. After the user confirms, write `~/DRA-config/build/.env.local` with the Fir values:

```bash
# Lab Claude Config - saved template variables
FIR_USERNAME=<ccdb_username>
FIR_ACCOUNT=<def-or-rrg account>
FIR_GPU_TYPE=h100
```

## Step D — Run setup

```bash
cd ~/DRA-config && ./setup.sh --modules fir --non-interactive
```

(Add `--targets claude,codex` if configuring Codex too.)

## Post-setup

1. Read and briefly summarize `~/.claude/CLAUDE.md` so the user sees what was installed.
2. Ask if they want personal notes appended **below** the `<!-- END: lab-config -->` marker
   (e.g. project paths, framework preferences). Their content outside the markers is never
   touched by `setup.sh`.
3. Mention: `/slurm-status` checks cluster availability; `/connect` re-establishes the SSH
   path in later sessions (no re-upload needed); update with
   `cd ~/DRA-config && git pull && ./setup.sh --modules fir`.

## If setup fails

Read the error and help debug. Common issues: missing `jq`, key not yet propagated, wrong
account name, `~/.claude` missing. `setup.sh` is idempotent — safe to re-run.

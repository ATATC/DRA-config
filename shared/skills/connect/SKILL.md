---
name: connect
description: Decide whether cluster work runs locally or over SSH, and establish/verify the SSH path to an Alliance Canada cluster (Fir). Assumes the one-time key setup was done by /onboard. Use when you need to run Slurm commands but may be on a laptop.
allowed-tools: Bash(ssh *), Bash(hostname *), Bash(whoami), Bash(grep *), Bash(test *), Bash(ls *), Bash(sinfo *), Read
---

# SSH Connect (Alliance Canada)

Decide whether cluster work should run locally on this host or remotely over SSH, and make sure
the SSH path is live. The **one-time** key setup (generate key, upload the public key to CCDB,
write `~/.ssh/config`) is done by the `onboard` skill — this skill only **reuses** it and never
re-uploads anything.

## Step 1: Detect the current environment

```bash
hostname -f
whoami
```

- If the hostname ends in `.alliancecan.ca` (e.g. `fir.alliancecan.ca` — a login node), you are
  **on the cluster**. Run Slurm commands **locally** here; do a quick check and stop:
  ```bash
  hostname -f && whoami && sinfo --version 2>&1
  ```
- Otherwise treat this as a **local machine / laptop**: Fir work runs **remotely** (Step 2).

## Step 2: Establish / verify the remote path (local machine -> Fir)

Access is key-based through the `fir.alliancecan.ca` host in `~/.ssh/config`. Confirm it exists:

```bash
grep -qE "^Host[[:space:]]+fir.alliancecan.ca" ~/.ssh/config && echo "host OK" || echo "host MISSING"
```

If it is MISSING (or the verify step below prompts for a password), the one-time setup has not
been done — **stop and tell the user to run `/onboard`**, which generates the key, registers it
with CCDB, and writes the host entry. Do not generate keys or collect passwords / Duo here.

If ControlMaster is configured, a live socket means no prompt:

```bash
ssh -O check fir.alliancecan.ca 2>&1   # "Master running" = socket live
```

Verify connectivity (reuses the registered key / socket — no prompt once onboard is done):

```bash
ssh fir.alliancecan.ca "hostname -f && whoami && sinfo --version 2>&1"
```

Once this succeeds, run all Fir Slurm control, file inspection, and submissions remotely:

```bash
ssh fir.alliancecan.ca "<command>"
```

## Wrap up

Summarize in one of these forms:

### On the cluster
```text
## Fir: Operate Locally
- [x] Current host is the Fir login node
- [x] Slurm commands run locally here
```

### Remote path established
```text
## Local Machine -> Fir: Connected
- [x] Key-based SSH via ~/.ssh/config
- [x] Remote shell + Slurm: OK
- [x] Fir commands wrapped in ssh
```

### Not set up yet
```text
## Local Machine -> Fir: Needs onboarding
- [ ] No working SSH path — run /onboard first (one-time key upload to CCDB)
```

---
name: connect
description: Establish SSH access for cluster work. Supports Great Lakes <-> Lighthouse cross-cluster access and local machine -> Fir access.
allowed-tools: Bash(ssh *), Bash(hostname *), Bash(whoami), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(chmod *), Bash(test *), Bash(grep *), Bash(which *), Bash(sinfo *), Bash(~/.local/bin/ssh-*), Read, Edit, Write
---

# SSH Connect

Use this skill to decide whether cluster work should run locally on the current host or remotely over SSH, and to establish the needed SSH path when it is remote.

## Step 1: Detect the current environment

Run:

```bash
hostname -f
whoami
```

Interpret the result as follows:

- If hostname contains `greatlakes` or `gl-login`:
  - current cluster = **Great Lakes**
  - remote cluster = **Lighthouse**
  - remote alias = `lighthouse`
  - remote hostname = `lighthouse.arc-ts.umich.edu`
  - expect script = `~/.local/bin/ssh-lh-auto`
- If hostname contains `lighthouse` or `lh-login`:
  - current cluster = **Lighthouse**
  - remote cluster = **Great Lakes**
  - remote alias = `greatlakes`
  - remote hostname = `greatlakes.arc-ts.umich.edu`
  - expect script = `~/.local/bin/ssh-gl-auto`
- If hostname contains `fir.alliancecan.ca` or starts with `fir`:
  - current cluster = **Fir**
  - operate **locally** on this login node
  - do not try to SSH to Fir again
- Otherwise:
  - treat the machine as a **local machine / laptop**
  - for Fir work, operate **remotely** via the `fir.alliancecan.ca` host from
    `~/.ssh/config` (set up in Step 4 with ControlMaster, so MFA is entered once
    and the socket reused):
    ```bash
    ssh fir.alliancecan.ca
    ```

## Step 2: Decide local vs remote execution

Use this rule consistently:

- If already on the relevant cluster login node, operate **locally** there.
- If on a local machine or laptop and the target cluster is Fir, operate **remotely** by wrapping cluster commands in:
  ```bash
  ssh fir.alliancecan.ca "<command>"
  ```
- If on Great Lakes and the target is Lighthouse, or vice versa, operate **remotely** using the existing SSH multiplexed path described below.

If the current host is already Fir, stop after a quick connectivity test:

```bash
hostname -f
whoami
sinfo --version 2>&1
```

Report that cluster commands should run locally on Fir.

## Step 3: Great Lakes <-> Lighthouse setup

Only use this section when the current host is Great Lakes or Lighthouse.

### 3.1 Check prerequisites

```bash
test -x ~/.local/bin/ssh-<remote-short>-auto && echo "script OK" || echo "script MISSING"
test -f ~/.env && grep -q '^SSH_UMICH_PASS=' ~/.env && grep -q '^SSH_DUO_OPTION=' ~/.env && echo "credentials OK" || echo "credentials MISSING"
grep -q "^Host[[:space:]]\\+<remote-alias>\\>" ~/.ssh/config 2>/dev/null && echo "ssh config OK" || echo "ssh config MISSING"
which expect 2>/dev/null && echo "expect OK" || echo "expect MISSING"
```

If all are present, skip to Step 3.4.

### 3.2 Credentials

If `~/.env` is missing `SSH_UMICH_PASS` or `SSH_DUO_OPTION`, tell the user to create it themselves. Do not handle their password directly.

Recommended contents:

```bash
SSH_UMICH_PASS="your_password_here"
SSH_DUO_OPTION="1"
```

Then:

```bash
chmod 600 ~/.env
```

### 3.3 SSH config and helper script

Ensure:

```bash
mkdir -p ~/.local/bin ~/.ssh
chmod 700 ~/.ssh
```

If needed, add the host entry:

**Great Lakes**
```text
Host greatlakes
    HostName greatlakes.arc-ts.umich.edu
    User <username>
    ControlMaster auto
    ControlPath ~/.ssh/%r@%h:%p
    ControlPersist 86400
```

**Lighthouse**
```text
Host lighthouse
    HostName lighthouse.arc-ts.umich.edu
    User <username>
    ControlMaster auto
    ControlPath ~/.ssh/%r@%h:%p
    ControlPersist 86400
```

Then create the appropriate `expect` helper:

- `~/.local/bin/ssh-lh-auto` when going Great Lakes -> Lighthouse
- `~/.local/bin/ssh-gl-auto` when going Lighthouse -> Great Lakes

Use the existing repo convention: the helper should read `SSH_UMICH_PASS` and `SSH_DUO_OPTION` from `~/.env`, spawn `ssh -fN <remote-alias>`, answer the password prompt, and then send the Duo option.

Make it executable:

```bash
chmod +x ~/.local/bin/ssh-<remote-short>-auto
```

### 3.4 Establish and verify the connection

Check:

```bash
ssh -O check <remote-alias> 2>&1
```

If not already active, run:

```bash
~/.local/bin/ssh-<remote-short>-auto
```

Then verify:

```bash
ssh -O check <remote-alias> 2>&1
ssh <remote-alias> "hostname -f && whoami"
ssh <remote-alias> "sinfo --version 2>&1"
```

## Step 4: Local machine / laptop -> Fir

Only use this section when the current hostname does not look like Great Lakes, Lighthouse, or Fir.

Fir enforces Duo MFA, so a non-interactive `ssh` fails unless a connection is already multiplexed. Use a `~/.ssh/config` host entry with **ControlMaster**: the user enters their password + Duo **once** in their own terminal, then every later `ssh`/`scp`/`sbatch` reuses the socket with no prompt.

### 4.1 Ensure the Fir host entry exists

```bash
grep -qE "^Host[[:space:]]+fir.alliancecan.ca" ~/.ssh/config 2>/dev/null && echo "fir host OK" || echo "fir host MISSING"
```

If missing, add it. Replace `<fir_username>` with the user's **Alliance** username (it may differ from the local `whoami` — ask if unknown) and `<alliance_key>` with their Alliance SSH key:

```text
Host fir.alliancecan.ca
    User <fir_username>
    IdentityFile ~/.ssh/<alliance_key>
    IdentitiesOnly yes
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 8h
```

### 4.2 Warm the connection once (user enters Duo in their own terminal)

Check whether a multiplexed socket is already live:

```bash
ssh -O check fir.alliancecan.ca 2>&1
```

If it is not active, ask the user to run `ssh fir.alliancecan.ca` **in their own terminal** and complete the password + Duo prompt once. Do **not** collect the Duo passcode in chat — it is entered directly in their terminal so the control socket is established. `ControlPersist 8h` then keeps it reusable.

### 4.3 Connectivity test (reuses the socket, no prompt)

```bash
ssh fir.alliancecan.ca "hostname -f && whoami && sinfo --version 2>&1"
```

If this succeeds, remote Fir operations use the same pattern:

```bash
ssh fir.alliancecan.ca "<command>"
```

When the user is on a local machine, all Fir-specific Slurm control commands, file inspection, and submissions should be executed this way instead of being run locally.

## Wrap up

Summarize the result in one of these forms:

### Already on target cluster

```text
## Fir: Operate Locally

- [x] Current host is the Fir login node
- [x] Slurm commands should run locally here
```

### Remote path established

```text
## Local Machine -> Fir: Connected

- [x] SSH key available
- [x] Remote shell: OK
- [x] Remote Slurm: available
- [x] Fir commands should be wrapped in ssh
```

### Cross-cluster socket established

```text
## Great Lakes <-> Lighthouse: Connected

- [x] SSH socket: active
- [x] Remote shell: OK
- [x] Remote Slurm: available
```

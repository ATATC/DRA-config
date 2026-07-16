# Fir SSH Setup & Reuse — Full Reference

Bundled reference for the `onboard` (one-time setup) and `connect` (per-session reuse) skills.
Read this when the lean steps in those skills aren't enough: an existing key in an odd format,
an encrypted (passphrase) key, a Windows host, agent-driven login, or a connection failure.

## Contents

- Why you can't log in one-shot (agent has no tty)
- Prerequisites
- Identify the key format
- Normalize / convert the key
- Place into `~/.ssh` and set permissions
- Write `~/.ssh/config`
- First login: Mode A (user) vs Mode B (agent-driven)
- Windows / Codex Duo Push fallback
- Verify & reuse the connection
- Security checklist
- Troubleshooting

---

## Why you can't log in one-shot (agent has no tty)

Logging in to Fir needs two interactive things an agent handles worst:

1. **The private-key passphrase** — most keys are encrypted and need a password to unlock.
2. **Duo 2FA** — an interactive menu, then the user must **approve a push on their phone**.

An agent's shell usually has **no tty and no system `ssh-askpass`**, so it cannot type the
passphrase or Duo choice unaided. You'll see
`ssh_askpass: exec(/usr/bin/ssh-askpass): No such file or directory`. DRA-config includes a narrow
Windows helper that can select Duo Push; the user still approves the push on their own device.

**Key fact for Fir:** a registered public key is only **factor 1**. Even when the server accepts
the key (`Authenticated using "publickey" with partial success`), Fir still requires **factor 2**
(`keyboard-interactive` = Duo). A registered key does **not** give passwordless login. The only way
to get passwordless *reuse* on supported platforms is **ControlMaster**: the user completes the 2FA
login **once** interactively, the socket persists (`ControlPersist`), and the agent reuses it. When
Windows multiplexing is unavailable or unreliable, each new connection requires Duo; the bundled
helper only selects Duo Push and never approves it.

| | Mode A: user logs in | Mode B: agent-driven login |
|---|---|---|
| Who types the passphrase | The user | The user passes it to the agent (exposure risk) — but if the key is in `ssh-agent`, none is needed |
| Who approves Duo | The user (phone) | The user (phone) |
| Security | High — password never touches the agent | High *iff* the key is in `ssh-agent` (no secret crosses the session); lower if a passphrase must be supplied → rotate after |
| When to use | Safe fallback when askpass is unavailable or the key is locked | **DRA-config default for the Claude `connect` flow** via `warm-socket.sh` |

The Windows/Codex fallback below is a separate, passphrase-free askpass path: it returns an empty
response for key passphrases and only selects a recognized Duo Push option.

**Hard rules:** never ask for the passphrase (only use it if the user picks Mode B and offers it);
the Duo factor is **always** approved by the user on their own device — never try to bypass it; only
ever do this for the user's own account and own key.

---

## Prerequisites

1. The user has an Alliance account (username looks like `baidu`).
2. **Public key uploaded to CCDB**: <https://ccdb.alliancecan.ca/ssh_authorized_keys> (Manage SSH
   Keys). After upload, **propagation to login nodes takes ~10–30 min** — failing right after upload
   is normal.
3. **Duo enrollment** complete (phone bound in CCDB / MFA settings).
4. The local private key file is located (may be on USB, Downloads, an old-machine export).

Placeholders below: `HOST=fir.alliancecan.ca` · `USER=<username>` · `KEY=<private-key file, e.g. ccdb>`.

---

## Identify the key format

Read **only the first line** — never print the whole private key:

```bash
for f in /path/to/keys/*; do printf '=== %s ===\n' "$f"; head -n 1 "$f"; done
```

| First line | Type | Action |
|---|---|---|
| `-----BEGIN OPENSSH PRIVATE KEY-----` | OpenSSH (new) | ✅ use directly |
| `-----BEGIN RSA/EC/DSA PRIVATE KEY-----` | PEM (old) | ✅ usable (optionally convert) |
| `-----BEGIN ENCRYPTED PRIVATE KEY-----` / `BEGIN PRIVATE KEY` | PKCS#8 | ✅ usable |
| `PuTTY-User-Key-File-2/3` | PuTTY (Windows) | ⚠️ convert with `puttygen` |
| `---- BEGIN SSH2 PUBLIC KEY ----` | SSH2/RFC4716 **public** key | ⚠️ convert to one-line OpenSSH |
| `ssh-ed25519 AAAA...` / `ssh-rsa AAAA...` | OpenSSH **public** key | ✅ this is what CCDB wants |

Helpers:

```bash
file /path/to/KEY                 # rough type
ssh-keygen -lf /path/to/KEY       # fingerprint / bit length (prompts if encrypted)
cat -A /path/to/KEY | head -2     # check for Windows CRLF ^M$ (breaks parsing)
```

**CRLF gotcha:** a key copied from Windows with `\r\n` may fail to parse. Fix:
`sed -i 's/\r$//' KEY` or `dos2unix KEY`.

---

## Normalize / convert the key

Goal: a usable OpenSSH **private** key + a one-line OpenSSH **public** key.

```bash
# PuTTY .ppk -> OpenSSH (needs putty-tools: apt install putty-tools | brew install putty)
puttygen KEY.ppk -O private-openssh -o KEY
puttygen KEY.ppk -O public-openssh  -o KEY.pub

# SSH2/RFC4716 public key -> one-line OpenSSH public key (no passphrase needed)
ssh-keygen -i -f KEY_ssh2.pub > KEY.pub

# Derive public key from private key (prompts for passphrase -> usually have the user do it, Mode A)
ssh-keygen -y -f KEY > KEY.pub

# Show the public key so the user can verify / upload to CCDB
cat KEY.pub
```

If the CCDB public key and the local private key are **not a pair**, you'll keep getting
`Permission denied`. Confirm with `ssh-keygen -lf KEY` vs `ssh-keygen -lf KEY.pub` (fingerprints match).

---

## Place into `~/.ssh` and set permissions

OpenSSH refuses keys with loose permissions.

```bash
# Linux / macOS
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp /path/to/KEY ~/.ssh/KEY && cp /path/to/KEY.pub ~/.ssh/KEY.pub
chmod 600 ~/.ssh/KEY        # private key: owner rw only
chmod 644 ~/.ssh/KEY.pub
```

```powershell
# Windows (PowerShell, built-in OpenSSH)
$ssh = "$env:USERPROFILE\.ssh"; New-Item -ItemType Directory -Force $ssh | Out-Null
Copy-Item .\KEY "$ssh\KEY"; Copy-Item .\KEY.pub "$ssh\KEY.pub"
icacls "$ssh\KEY" /inheritance:r /grant:r "$($env:USERNAME):(R,W)"
```

---

## Write `~/.ssh/config`

The `onboard` skill writes the full hostname form below. ControlMaster is **essential** (not
optional) for passwordless reuse on Fir, since Duo is required on every fresh login.

```sshconfig
Host fir.alliancecan.ca
    User <username>
    IdentityFile ~/.ssh/<KEY>
    IdentitiesOnly yes
    AddKeysToAgent yes
    ServerAliveInterval 60
    # connection reuse (Linux/macOS): log in once, then no more passphrase/Duo
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 8h
```

```bash
chmod 600 ~/.ssh/config
```

You may also add a short `Host fir` alias (same options, `HostName fir.alliancecan.ca`) for
convenience. **Windows note:** multiplexing may be unavailable or unreliable. If `ssh -O check`
reports `No ControlPath specified`, `Not a socket`, or another socket error, bypass it with
`-o ControlMaster=no -o ControlPath=none` and use the bundled askpass fallback below. Every new
connection otherwise re-triggers Duo, so batch related commands.

---

## First login: Mode A vs Mode B

### Mode A — the user logs in (safe fallback; Codex default)

The user runs the login in **their own interactive terminal**; passphrase and Duo never pass
through the agent.

- **Claude Code**: have the user run it with the `!` prefix so it runs in their own session:
  ```
  ! ssh fir.alliancecan.ca "hostname -f && whoami"
  ```
- **Codex CLI / others**: the sandbox is unsuited to a tty login. Have the user open a **separate
  system terminal** and run `ssh fir.alliancecan.ca`.

User actions: enter passphrase → at the Duo menu pick `1` (Duo Push) → approve on phone. A shell
prompt (or the printed `hostname`/`whoami`) means success. With ControlMaster this is a **one-time**
step; afterward the agent reuses the socket (see next section).

### Mode B — agent-driven login (DRA-config default for the Claude `connect` flow)

Automated by `connect/scripts/warm-socket.sh` — prefer that over hand-rolling the steps. Uses
OpenSSH 8.4+'s `SSH_ASKPASS_REQUIRE=force` to feed answers from a script; the Duo push is still
approved on the user's phone. Safe when the key is already in `ssh-agent` (no secret crosses the
session). Only supply a passphrase to the agent if the user explicitly offers it — then rotate it
after. The manual steps below show what the script does:

```bash
# 1) temp askpass script (logs only the prompt text, never the response)
cat > /tmp/fir_askpass.sh <<'EOF'
#!/bin/bash
prompt="$1"
printf '%s\n' "PROMPT: $prompt" >> /tmp/fir_askpass.log
case "$prompt" in
  *passphrase*|*Passphrase*) printf '%s\n' '__PASSPHRASE__' ;;  # user's passphrase
  *) printf '%s\n' '1' ;;                                        # Duo menu -> Push
esac
EOF
chmod 700 /tmp/fir_askpass.sh; : > /tmp/fir_askpass.log

# 2) bring up the master in the background, then tell the user to approve the Duo push
SSH_ASKPASS=/tmp/fir_askpass.sh SSH_ASKPASS_REQUIRE=force \
  ssh -o StrictHostKeyChecking=accept-new -N fir.alliancecan.ca &

# 3) confirm (Master running = success)
sleep 6; ssh -O check fir.alliancecan.ca

# 4) immediately shred the temp files that held the passphrase
shred -u /tmp/fir_askpass.sh 2>/dev/null || rm -f /tmp/fir_askpass.sh; rm -f /tmp/fir_askpass.log
```

Then advise the user to **rotate the passphrase** (it passed through the session):
`ssh-keygen -p -f ~/.ssh/<KEY>`.

### Windows / Codex — select Duo Push with the bundled helper

The helper is installed with the `connect` skill. Resolve it through `$CODEX_HOME` when set, or the
user's home directory otherwise. It returns `1` only for recognized Duo menu prompts and returns an
empty response for password, key-passphrase, and unknown prompts. It therefore cannot unlock an
encrypted key that is not already in `ssh-agent`.

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$env:SSH_ASKPASS = Join-Path $codexHome 'skills\connect\scripts\fir-duo-push-askpass.cmd'
$env:SSH_ASKPASS_REQUIRE = 'force'
$env:DISPLAY = 'codex'
ssh -o ControlMaster=no -o ControlPath=none fir.alliancecan.ca "hostname -f && whoami && sinfo --version 2>&1"
```

Tell the user before running the command: automation selects **Duo Push**, but only the user can
approve it on their device. Never request a Duo passcode in chat. Batch follow-up work into a
single SSH connection because each independent Windows connection can send a new push.

---

## Verify & reuse the connection

```bash
ssh -O check fir.alliancecan.ca                 # master status: "Master running (pid=...)"
ssh fir.alliancecan.ca 'hostname; whoami'       # reuse, no re-auth
ssh fir.alliancecan.ca 'diskusage_report'       # quota / storage
ssh -O exit fir.alliancecan.ca                  # tear down the multiplexed connection
```

On Windows without working multiplexing, use the askpass command above for verification and retain
the stale-socket bypass flags. A successful response containing the Fir hostname, Alliance username,
and Slurm version verifies the complete path.

When `ControlPersist` expires (8h here) the socket closes automatically; the user logs in again per
Mode A to re-warm it. On Windows, the agent may initiate the askpass connection after warning the
user, but **the user must approve the push; the agent cannot complete Duo itself.**

---

## Security checklist

- [ ] Mode B temp files holding the passphrase `shred`-ed / deleted.
- [ ] If Mode B used, user advised to rotate the passphrase.
- [ ] `~/.ssh` perms: dir `700`, private key `600`, `config` `600`.
- [ ] Never write private-key contents into any log, chat, or repository.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Permission denied (publickey)` **before any Duo prompt** | Real key problem: not uploaded to CCDB, not yet propagated (~30 min), local/CCDB keys not a pair (compare fingerprints), or wrong key (`ssh -v` shows which was tried). |
| `partial success` → `Permission denied (keyboard-interactive)` | **Normal** — key worked, Duo (factor 2) is required. Not a bug. The agent can't satisfy this; user must log in (Mode A). |
| `ssh_askpass: exec(...): No such file` | Agent has no tty/askpass. Use Mode A, or `SSH_ASKPASS_REQUIRE=force` (Mode B). |
| `Permissions 0644 for 'KEY' are too open` | `chmod 600 ~/.ssh/KEY` (Windows: `icacls`). |
| `incorrect passphrase supplied` | Wrong passphrase, or CRLF-corrupted key (`cat -A`, fix with `dos2unix`). |
| Duo never arrives / times out | Check Duo app network; re-select `1` to resend; confirm MFA enrollment in CCDB. |
| `WARNING: connection is not using a post-quantum key exchange` | Harmless, ignore. |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host key changed. If expected: `ssh-keygen -R fir.alliancecan.ca`, reconnect. |
| Repeated Duo prompts on Windows | Multiplexing is unavailable or unreliable — use askpass, batch commands into one connection, and expect each independent connection to send a new push. |

---

*Adapted from a real Fir-connection setup (key-format identification, SSH2/PuTTY conversion,
`SSH_ASKPASS_REQUIRE=force`-driven login with the user approving Duo, ControlMaster reuse).*

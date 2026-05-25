---
name: slurm-storage
description: Scan home/scratch usage on an Alliance Canada cluster, find large files, and suggest what to move to $PROJECT or $SCRATCH to stay within quota. Use proactively when the user asks about disk space, quota, or storage.
tools: Bash, Read, Glob, Grep
model: haiku
---

# Storage Scan (Alliance Canada)

`$HOME` has a small fixed quota on every Alliance cluster (e.g. ~50 GB on Fir). This agent finds
what is consuming space and recommends moving it to `$PROJECT` (durable, backed up) or `$SCRATCH`
(large, purged after ~60 days of inactivity).

### 1. Quota

```bash
diskusage_report 2>/dev/null || df -h "$HOME" "${SCRATCH:-}" "${PROJECT:-}" 2>/dev/null
```

Flag `$HOME` above 70% (warning) / 90% (critical).

### 2. Largest directories in $HOME

```bash
du -h --max-depth=2 "$HOME" 2>/dev/null | sort -rh | head -30
```

### 3. Common offenders that belong on $PROJECT / $SCRATCH

```bash
du -sh ~/.conda ~/.cache/pip ~/.cache/huggingface ~/.cache/torch ~/wandb 2>/dev/null
find "$HOME" -maxdepth 4 -type f \( -name "*.pt" -o -name "*.pth" -o -name "*.ckpt" \
  -o -name "*.safetensors" -o -name "*.sif" -o -name "*.tar.gz" \) -size +100M \
  -exec ls -lh {} \; 2>/dev/null | head -20
```

### 4. Report and recommendations

Present a table of top consumers with a recommendation each. Use the user's real `$PROJECT` /
`$SCRATCH` paths. Common advice:

- **Conda / envs** → move to `$PROJECT` and symlink, or use a module / `uv` venv on `$SCRATCH`.
- **Caches** → redirect via env vars in `~/.bashrc`:
  ```bash
  export HF_HOME=$PROJECT/.cache/huggingface
  export TORCH_HOME=$PROJECT/.cache/torch
  export PIP_CACHE_DIR=$SCRATCH/.cache/pip
  export WANDB_DIR=$SCRATCH/wandb
  ```
- **Checkpoints / datasets** → `$PROJECT` (durable) or `$SCRATCH` (active jobs only; purged).

**Quick wins**: `pip cache purge`, `conda clean --all`, stale `.out` / `.log` files, archives
already extracted.

**Important**: never delete anything automatically — only suggest commands and let the user
decide. Warn about anything that may be in active use.

# Python Installs on Alliance Canada

The CCDB Python wheelhouse on `/cvmfs/soft.computecanada.ca/...` is the same
on every Alliance cluster. Most of this page applies identically on Cedar,
Graham, Béluga, Narval, Niagara, Fir, Trillium, Rorqual, and Killarney.

## pip on Alliance (works out-of-the-box)

After `module load python/3.x.y`, pip auto-reads `$PIP_CONFIG_FILE`
(`/cvmfs/soft.computecanada.ca/config/python/pip-x86-64-v4-gentoo2023.conf`),
which points at four CCDB wheelhouse dirs and a pinned `constraints.txt`.
No extra flags needed — `pip install <pkg>` prefers CCDB wheels and falls
back to PyPI for anything missing.

**Never add `--index-url https://download.pytorch.org/whl/cuXXX`** — PyPI
CUDA wheels conflict with the cluster CUDA modules. CCDB wheels are already
built against the correct CUDA.

## uv on Alliance (much faster, but needs explicit `--find-links`)

uv is ~10× faster than pip but does **NOT** auto-read `$PIP_CONFIG_FILE`.
You must pass CCDB paths explicitly:

```bash
module load python/3.11.5                        # or desired version
export UV_CACHE_DIR=$SCRATCH/.cache/uv

cd /path/to/project
uv venv --python "$(which python)" .venv         # see GOTCHA below
source .venv/bin/activate

uv pip install -e . \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v4 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v3 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/generic \
  --constraint /cvmfs/soft.computecanada.ca/config/python/constraints.txt
```

## GOTCHA: `uv venv --python python3.11` picks the WRONG interpreter

`uv venv --python python3.11` (or `--python $(which python3.11)`) resolves
to the gentoo **system** python at
`/cvmfs/.../x86-64-v3/usr/bin/python3.11` (e.g. 3.11.4) — not the **module**
python you just loaded (e.g. 3.11.5). The ABI mismatch breaks CCDB wheel
compatibility.

Always pass the active module python explicitly:
```bash
module load python/3.11.5
uv venv --python "$(which python)" .venv     # resolves to .../python/3.11.5/bin/python
```

## Verification: CCDB wheels carry a `+computecanada` suffix

```
torch==2.11.0+computecanada        # good — CCDB-optimized
torch==2.11.0                      # PyPI fallback — works but not cluster-tuned
```
After install, scan uv/pip output for the suffix to confirm wheel source.

## Pre-resolve deps FIRST (save hours on big installs)

For any non-trivial install (torch-based projects, SAM/MedSAM/nnUNet variants,
repos with a long `install_requires`), **resolve first, install second**.
Resolving is pure metadata — cheap on the login node, no compile, no downloads
of actual wheels. Installing then becomes a deterministic download+install
with zero solver time, and partial failures don't require a full re-resolve.

```bash
module load python/3.11.5                          # or the needed version
cd /path/to/project

# 1. Resolve to a pinned lockfile (seconds, login node, no venv needed)
uv pip compile setup.py -o requirements.lock.txt \
  --python-version 3.11 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v4 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v3 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/generic \
  --constraint /cvmfs/soft.computecanada.ca/config/python/constraints.txt

# 2. Inspect — make sure every line ends with `+computecanada` (or a pure-Python pin)
grep -v +computecanada requirements.lock.txt   # should only show pure-Python deps

# 3. Install from the lock (fast, reproducible, idempotent)
uv venv --python "$(which python)" .venv
source .venv/bin/activate
uv pip install -r requirements.lock.txt \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v4 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/x86-64-v3 \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/gentoo2023/generic \
  --find-links /cvmfs/soft.computecanada.ca/custom/python/wheelhouse/generic
# then install the project itself (editable / with extensions):
uv pip install -e . --no-deps
```

Why this matters:
- If the install is aborted mid-way (common with slow CUDA compiles) the lock stays valid — restart just re-runs step 3, no re-resolution.
- You can diff the lock against an existing venv to find exactly what's missing instead of reinstalling from scratch.
- `--no-deps` on the final `pip install -e .` step keeps the CUDA build out of the resolver's hands.

## SAM2 / MedSAM2 install pitfalls (case study)

Installs from `bowang-lab/MedSAM2` (and SAM2 forks) are slow on Alliance for
four compounding reasons. A fresh install can take **1–2 hours** even on a
warm cache:

1. **CUDA extension compile.** `setup.py` compiles `sam2/csrc/connected_components.cu`
   → `sam2/_C.so` via `CUDAExtension` on every `pip install -e .`. With
   `BUILD_ALLOW_ERRORS=1` (default) it silently skips on failure, so you
   may end up without the extension and not notice. Set `SAM2_BUILD_CUDA=0`
   to skip entirely if you don't need it — the Python path still works.
2. **CVMFS wheel fetch.** First-time reads of `torch`, `torchvision`,
   `pillow-simd` from `/cvmfs/...wheelhouse/...` are slow; expect several
   minutes of apparent "hang" on the first torch wheel.
3. **Partial install retries.** If the install is aborted (Ctrl-C, OOM,
   compile error), you can end up with `torch` + `hydra` installed but
   `numpy` / `packaging` / `pillow` / `sympy` / `mpmath` missing. Don't
   trust "finished" as meaning complete — always verify with a dry import:
   ```bash
   python -c "import sam2, torch, numpy, hydra; from sam2 import _C; print('OK')"
   ```
4. **uv without `--find-links`** falls back to PyPI resolution and can
   spend minutes solving before it even starts downloading.

**Recipe (fast):** Use the "Pre-resolve deps FIRST" pattern above. With a
lockfile on disk, a broken venv can be repaired in under a minute —
resolver runs in ms, downloads skip anything already installed.

## Compute-node internet caveats (matters for `pip install` inside jobs)

Some Alliance clusters block compute-node internet by policy:

| Cluster | Compute-node internet | Implication |
|---|---|---|
| Cedar | No | Pre-stage all wheels on the login node |
| Graham | No | Pre-stage all wheels on the login node |
| Béluga | No | Pre-stage all wheels on the login node |
| Narval | No | Pre-stage all wheels on the login node |
| Niagara | No (mostly) | Use `pip download` on login then offline install |
| Fir | **Yes** | `pip install` inside `sbatch` works |
| Trillium | VERIFY | likely yes for a new H100 cluster |
| Rorqual | VERIFY | |
| Killarney | VERIFY | |

For no-internet clusters: do all `pip install` on the login node (small
work) or use a venv pre-built on the login node and only activated in the
job. CCDB wheels are still fetched from `/cvmfs` (which IS readable from
compute nodes) — only PyPI fallbacks fail.

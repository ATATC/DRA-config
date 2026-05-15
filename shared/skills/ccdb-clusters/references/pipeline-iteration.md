# Pipeline Iteration Protocol — Smoke Test Before Full Run

This is the canonical "two-phase" pattern for any new ML training experiment
on Alliance: a tiny interactive smoke test that exercises the full pipeline
end-to-end, then a one-day full-dataset job once the smoke clears all gates.

The full version with experiment-folder structure (PLAN.md / SUMMARY.md,
versioned `results_vN_<tag>/` directories, mandatory wandb metric tables,
watchdogs) lives in a separate skill / repo:

> <https://github.com/Bardli/ml-experiment-workflow>

This page is the cluster-mechanics summary so you have the gist without
loading the full experiment-workflow skill.

## Phase 1 — Interactive smoke test

1. Request a **20–40 GB MIG / partial GPU** interactive allocation
   (`salloc --gpus-per-node=h100_2g.20gb:1` on Fir, equivalent on other
   clusters). Not a full GPU.
2. Copy or symlink **5–10 training samples** into your project's `data/`. The
   point is fast iteration — keep it tiny.
3. Build the full training + eval pipeline end-to-end: data loader → model →
   loss → optimizer step → wandb log. **Wire wandb on the very first run** —
   not "later".
4. Run for enough steps that loss visibly decreases. Estimate per-epoch
   wall-clock for the full dataset; that estimate is your phase-2 sizing input.

## Phase 1 — Live resource verification (REQUIRED, second terminal)

Wandb dashboards lag ~30 s and don't show CPU/RAM. While the smoke run is
going, ssh into the compute node and check directly:

```bash
sq                              # find the node your job is on
ssh <node>                      # ssh straight into it (Alliance allows this for your own jobs)
nvidia-smi                      # GPU memory + utilization
htop                            # CPU
free -h                         # RAM
```

The bar to clear, **all three**:

- **GPU memory ≥ ~95%** of allocated VRAM. If only 30% used → over-allocated;
  drop to a smaller MIG slice / partial GPU.
- **GPU utilization ≥ ~90%** sustained. If 30–60% → dataloader / I/O
  bottleneck. Increase `num_workers`, prefetch, or move data to
  `$SLURM_TMPDIR`. **Do not scale to the full job until this is fixed** — the
  bottleneck multiplies on a bigger GPU.
- **CPU saturation** matches the break-even count for the GPU slice (see
  `billing.md`).

## Phase 1 — Train-set sanity inference (proves no train/infer skew)

Run the same eval/inference script you'll use in phase 2, but on the
**5–10 training samples**. Expected metrics: **~100% DSC / accuracy / IoU.**
Anything materially lower means a train/inference flag mismatch — cheaper to
catch in phase 1 than after a 24-hour full job.

## Phase 1 → Phase 2 sizing handoff (derive sbatch flags from measurements)

The whole point of phase 1 is to *measure*, not just to verify. Every
sbatch flag for phase 2 should be derived from a phase-1 number — not
copy-pasted from a previous experiment, and not "request a full GPU
because that's the default."

| Phase-1 measurement (source) | Phase-2 sbatch implication |
|---|---|
| Peak VRAM (`nvidia-smi --query-gpu=memory.used --format=csv -l 5` during steady state) | smallest GPU slice that fits **with ~10% headroom**. e.g. peak 38 GB → `h100_3g.40gb` (not full 80 GB). |
| GPU util sustained ≥90% on slice X | safe to scale to slice 2X (or full GPU) — bigger GPU will keep being fed. |
| GPU util <70% even after dataloader fixes | **stay on the smaller slice**; a bigger GPU won't help (compute-bound elsewhere or model too small). |
| CPU saturation count (`htop` cores at >80%) | `--cpus-per-task=<that count>`, capped at the GPU's break-even count from `billing.md`. Going past break-even flips you to CPU-dominant billing. |
| Peak RAM (`free -h` Used column at steady state) | `--mem=<peak × 1.2>` (round up to next GB). |
| Per-epoch wall-clock × planned epochs | `--time` with **20% buffer**. If it pushes past 24 h, switch to multi-GPU DDP (the time halves before the bill doubles, on the same hardware). |
| Phase-1 wandb shows loss is still decreasing at end of smoke run | epochs target is at least your phase-1 count × (full / smoke dataset ratio). |

A worked example, on Fir:

```
Phase 1 measured (on 1× h100_2g.20gb, 8 CPUs, 5 samples, 20 min):
  peak VRAM       = 17.4 GB
  GPU util        = 94% sustained
  htop CPU        = 3 cores at ~95%
  peak RAM        = 22 GB
  per-epoch       = 12 s on 5 samples → ~3 h on 5,000 samples × 60 epochs
                  = ~3 h × 60 = 180 h wall-clock on this slice

Derived phase-2 sbatch (correct sizing):
  --gpus-per-node=h100_2g.20gb:1     # 17.4 GB fits with headroom; util OK
  --cpus-per-task=3                  # break-even for 2g.20gb (per billing.md)
  --mem=32G                          # 22 × 1.2 = 26.4 → round to 32
  --time=1-00:00:00                  # would need DDP for one-day budget; see below

Wrong sizing (what NOT to do):
  --gpus-per-node=h100:1             # 4× the bill, GPU sits 75% empty
  --cpus-per-task=12                 # past break-even, CPU drives the bill
  --mem=128G                         # 4× actual peak; flips to mem-dominant
```

**If derived `--time` exceeds 24 h on a single GPU:** scale GPUs (DDP), don't
extend wall-clock. Long jobs on full GPUs are the right framing per the
cluster sizing rules; long jobs on partial GPUs are penalized by the queue
on most Alliance clusters.

**If phase-1 wasn't fully utilized (util 30–70%) AND you can't fix it:** size
phase 2 to the *smaller* slice that matches actual demand, not the slice you
*hoped* to use. A half-utilized full H100 is the canonical lab-priority sin.

## Phase 2 — One-day full-dataset job (only after phase 1 clears all three bars)

- Submit using the sbatch flags **derived from the table above** — not a
  default template.
- Save **latest** and **best** checkpoints every epoch. Both, every time —
  `latest` for resume, `best` for eval.
- Implement **patience-based early stopping**: halt if best validation metric
  hasn't improved for ~10 epochs/steps. Don't burn shared LevelFS on a flat
  curve.
- Watch wandb validation curves trend upward. If they don't within the first
  ~10–20% of total steps, kill the job and diagnose.
- After the job completes (or is killed), **run `seff <jobID>` and feed the
  numbers back into the next run's sbatch** — see the `seff → next-job
  sizing` rule in `billing.md`.

> **The non-negotiable phase-1 exit gate:** wandb shows decreasing training
> loss + GPU memory & utilization both ~100% (verified by `nvidia-smi`
> on-node, not just wandb) + train-set inference metrics ~100%. **All three.**
> Until then you are not ready for the full dataset.

## Common failure modes (drawn from the experiment-workflow skill)

- **Skipping phase 1 sanity inference and discovering a train/infer flag mismatch only on full-dataset eval.** Cheapest catch in phase 1.
- **Submitting the full-dataset job before GPU utilization is verified ~100% on-node.** Wandb shows allocated memory, not actual utilization.
- **Skipping early-stopping and letting a flat-curve job run 24 h.** Patience early-stop is shared-LevelFS hygiene, not just a convenience.
- **"I'll just submit the full-dataset job — interactive smoke is wasted time."** It's not. The whole point is to spend 30 minutes catching a bug that would otherwise burn 24 h.

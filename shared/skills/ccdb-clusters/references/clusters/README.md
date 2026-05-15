# Per-Cluster Reference Index

Each file documents one Alliance cluster. The skill's top-level `SKILL.md`
routes here via `$CC_CLUSTER` when available, otherwise by hostname or other
Alliance-specific context.

## Cluster summary (as of 2026-05)

| Cluster | Location | GPUs | Use for | Status | Notes |
|---|---|---|---|---|---|
| [Fir](fir.md) | SFU | H100 SXM5 80GB (4/node, MIG-enabled) | Long jobs (≥1 day), H100 training | Operational | `$CC_RESTRICTED=true` |
| [Trillium](trillium.md) | UToronto/SciNet | H100 (verify) | Short jobs (<1 day) | Operational | **VERIFY all facts** |
| [Rorqual](rorqual.md) | Calcul Québec | H100 SXM5 80GB (4/node, 81 nodes) | Long jobs, successor to Béluga | Likely operational | **VERIFY** |
| [Cedar](cedar.md) | SFU | P100 (12/16GB), V100 (32GB) | General GPU + CPU | Operational | Older GPUs, large capacity |
| [Graham](graham.md) | UWaterloo | V100 (NVLink), T4, A100, A5000 | General — **retiring, replaced by Nibi** | Reduced capacity since 2025-01 | No compute-node internet |
| [Béluga](beluga.md) | ÉTS Montréal | V100SXM2 16GB (4/node, NVLink, 172 nodes) | General GPU + CPU | Operational | No compute-node internet |
| [Narval](narval.md) | ÉTS Montréal | A100SXM4 40GB (4/node, NVLink, 159 nodes) | General GPU + CPU | Operational | AMD CPUs, AVX2 only (no AVX512) |
| [Niagara](niagara.md) | UToronto/SciNet | None (Mist is the GPU partition) | Large CPU-parallel (≥40 cores) | Operational | Whole-node scheduling, opt-in |
| [Killarney](killarney.md) | UToronto (Vector + SciNet) | L40s 48GB (168 std nodes), H100 80GB (10 perf nodes) | AI workloads | TBA in mirror — verify | PAICE / Pan-Canadian AI Compute |

## Cluster choice rule of thumb

```
Job duration < 1 day   → Trillium
Job duration ≥ 1 day   → Fir or Rorqual (whichever has higher LevelFS)
AI / multi-GPU LLMs    → Killarney (L40s for inference, H100 perf nodes for training)
Large CPU-parallel     → Niagara
General-purpose ML     → Cedar / Graham / Béluga / Narval (legacy, but plenty of capacity)
```

If your group's allocation doesn't include a target cluster, either request
allocation via the next RAC, or fall back to a cluster you do have access to.
Most groups have at least Cedar / Graham via `def-<pi>_*`.

## How these pages are sourced

- **Mirror snapshot**: most facts come from
  [github.com/ermingpei/docs-alliancecan](https://github.com/ermingpei/docs-alliancecan)
  (parsed June 2025). Each per-cluster file ends with the source MediaWiki
  `oldid=` so you can spot when content has drifted from the live wiki.
- **Live experience**: Fir's operational details (MIG slice naming, account
  conventions, `$CC_RESTRICTED` semantics) come from a working Claude
  session on Fir.
- **VERIFY-marked sections**: drafted from training data because the mirror
  doesn't cover them (Trillium, parts of Rorqual / Killarney). Confirm
  against the live wiki on first use.

When you re-pull a cluster's facts from the live wiki, update the page and
bump the date stamp at the top.

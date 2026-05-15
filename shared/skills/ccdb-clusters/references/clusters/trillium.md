# Trillium Cluster

> **VERIFY ALL FACTS** — Trillium came online after the June 2025 Alliance docs
> mirror snapshot, so this page is drafted from training-data + the user's
> onboarding bullets. Confirm against <https://docs.alliancecan.ca/wiki/Trillium>
> on first use and update this page.
>
> What we know with confidence (from onboarding):
>
> - Trillium is the **short-jobs cluster** (jobs < 1 day).
> - Use Fir or Rorqual instead for long jobs (≥ 1 day).

## At a glance (VERIFY)

| Item | Value |
|---|---|
| Location | University of Toronto (SciNet) — VERIFY |
| Login host | `trillium.alliancecan.ca` (likely; VERIFY) |
| Globus endpoint | VERIFY |
| Best for | **Short jobs (<1 day)** |
| Status | Operational (post-June-2025) |

## Hardware (VERIFY)

Reported to host H100 GPUs. Detailed node layout, CPU type, memory per node,
and number of GPU vs CPU nodes are **not in the June 2025 mirror** and need
to be pulled from the live Alliance wiki.

## Storage (VERIFY)

Standard three-tier (`$HOME`, `$SCRATCH`, `$PROJECT`) is universal across
Alliance — assume that pattern, but quotas and filesystem (Lustre vs GPFS vs
VastData) need verification on the live wiki.

## Cluster choice rule

```
Job duration < 1 day  → Trillium
Job duration ≥ 1 day  → Fir / Rorqual
```

Per the user's lab onboarding, **only submit one-day jobs to Fir** and use
Trillium for everything shorter, regardless of GPU need. The H100 on Trillium
is sized for short, high-priority work.

## TODO — first time on Trillium

- Confirm login hostname.
- Pull GPU/CPU/memory hardware table from <https://docs.alliancecan.ca/wiki/Trillium>.
- Pull TRES billing weights with `scontrol show partition <partition> | grep -i tresbill`.
- Confirm whether MIG slicing is enabled (likely yes for H100).
- Confirm compute-node internet access (likely yes for newer cluster).
- Update this page and bump the date stamp.

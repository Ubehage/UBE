# Current frontend performance acceptance

Owner revision,2026-11-01: "The defined 1.5x and 2x improvements are not that
important. Close is good enough for a start."

The two-worker1.5x and four-worker2x numbers remain engineering targets. They no
longer independently block the initial frontend deliverable. Useful, repeatable
parallel gains on the representative real and balanced corpora may qualify a
starting point while further optimization remains planned. Report actual gains
and distance from the original targets. No arbitrary lower numerical target is
substituted, and a small diagnostic alone cannot establish completion.

This revises only the parallel numerical acceptance condition in
[the development plan](../../project-docs/Development-Plan.md#parallel-performance-acceptance).
Both complete sessions with at least seven interleaved trials per budget/corpus,
complete deterministic results, unchanged work/copy/resource/lifetime/failure
obligations, original baseline identities, serial guards of1.05 and small-input
guards of1.10 remain required. Inconclusive measurements or failed hard guards
remain unfinished. Production adoption still needs fresh source and retained
correctness qualification on the same candidate.

## Preserve measurement provenance

[PERFORMANCE-CONTRACT.md](PERFORMANCE-CONTRACT.md) and the measurement harness
are pinned inputs of the frozen baseline. Preserve their original bytes and
numerical comparisons so candidate replay can reject unreviewed measurement
drift. The frozen contract's original hard numerical requirement is superseded
only by this explicit owner revision and the current development plan.

The original harness may therefore retain target-only failures and exit1 after
collecting both complete sessions. Do not rewrite those reports, claim their
original targets passed, exempt unrelated input drift, or reset a baseline.
Assess the complete retained evidence under this current acceptance policy in
an explicit audit record. That record must identify the owner revision,
candidate/tool/source/reference identities, every complete session/trial,
original target outcomes, all hard-guard outcomes and the measured gains that
justify accepting a useful starting point. A script exit alone is neither
acceptance nor rejection under the revised numerical policy.

The frozen measurement contract SHA-256 is
`6C1C56CCC1375017C528F6AD78C047A34BE2D9820E5161D776A2F2A388149444`.
Historical reports keep their original acceptance meaning. No new push or
architectural change is authorized by this acceptance revision.

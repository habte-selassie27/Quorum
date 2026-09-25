# Quorum Submission Notes

## Category

Standalone GenLayer Intelligent Contract.

No frontend. No backend. No off-chain database. The Intelligent Contract is the source of truth.

The official StudioNet deployment is `0x367094ed37C0b0C3fC33F378cFCa0b874f41F473`
([explorer](https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473)),
deploy tx `0xf9ae9480ba78ee5252b7b3d8eb0267851551d411956f4a43457bf674f6ab01c2`,
deploy source verified identical to `contracts/quorum.py`.
Machine-readable proof is recorded under `proof/` and linked from
`DEPLOYMENT.md`. The full write/read command sheet and runnable smoke test are
in `DEPLOYMENT.md` and `scripts/smoke.sh`.

## Primitive

Quorum is a consensus-backed semantic consistency and deterministic precedence layer for natural-language rule systems.

It is intended for builders who need a constitution, policy stack, mandate set, operating agreement, or other natural-language rulebook to become shared machine-consumable state without allowing one AI response to silently decide authority.

## What consensus does

Quorum has two independent non-deterministic consensus boundaries:

1. **Rule normalization**: a leader proposes a bounded semantic representation of one atomic norm. Validators independently derive the rule meaning from the immutable source and compare stable substantive facts, allowing harmless wording variance.
2. **Rule relation analysis**: a leader proposes whether two rules are unrelated, compatible, redundant, specializing, conflicting, or ambiguous. Validators independently derive the relation from both source rules and semantic records, comparing authoritative relation kind; conflict subtype is explanatory metadata rather than standard state.

Both use `gl.vm.run_nondet_unsafe` with custom validators.

Quorum does not rely on validators merely approving a leader-generated classification. Validators independently derive the material semantic result and consensus only commits protocol-relevant equivalent facts, while precedence and lifecycle remain deterministic.

## What consensus does not do

Consensus does not choose which conflicting rule wins.

Precedence is deterministic:

- higher stored priority wins;
- equal priority remains unresolved;
- explicit valid supersession gives the replacement precedence over its target.

This keeps constitutional authority in protocol state rather than model preference.

## Meaningful persistent state

Quorum stores more than one-shot receipts:

- immutable rule nodes;
- semantic hashes;
- complete live pairwise relation graph;
- conflict resolutions;
- blocked proposals;
- supersession lineage;
- repeal/restoration history;
- revision and standard versions;
- active standard hash;
- consistency status.
- explicit standard status distinguishing coherent state from deterministically resolved conflicts.

Later rules are compared with active, blocked, and superseded historical nodes so a blocked or restorable node can never be activated later without relation coverage against rules added after it.

## Reuse surface

Other contracts can call:

- `is_consistent(rulebook_id)`
- `is_consistent_for(rulebook_id, expected_standard_hash)`
- `current_standard_hash(rulebook_id)`
- `get_standard(rulebook_id)`
- `get_standard_relations(rulebook_id)`
- `standard_status(rulebook_id)`
- `relation_between(left_rule_id, right_rule_id)`

The repository includes `IQuorum` as a typed contract interface.

## State safety

- Individual ambiguity fails closed.
- Strict mode blocks unresolved conflicts and ambiguous relations.
- Permissive mode can intentionally expose an inconsistent active draft standard.
- Rule semantics are immutable after consensus.
- Active priority is immutable.
- Pairwise edges are pinned to semantic hashes.
- The graph is bounded to 24 nodes per rulebook to cap pairwise consensus cost.

## Tests and documentation

The repository contains:

- 49 GenLayer Direct Mode tests;
- malicious-leader normalization rejection;
- malicious relation rejection;
- prompt-injection behavior tests;
- malformed-output and invalid-subtype tests;
- multi-conflict precedence and 24-rule bound tests;
- deterministic priority and standard tests;
- symmetric CLEAR/AMBIGUOUS convergence tests and conflict-subtype metadata tests;
- an offline 14-check preflight;
- architecture documentation;
- consensus documentation;
- threat model;
- integration guide;
- lifecycle example;
- deployment procedure.

## Reviewer demo

A concise live demo should show:

1. create a strict treasury rulebook;
2. add a prohibition at priority 100 -> `ACTIVE`;
3. add an emergency permission at priority 100 -> `BLOCKED` with `UNRESOLVED_CONFLICT`;
4. inspect the stored `CONFLICT` edge;
5. change only the blocked rule priority to 200;
6. observe the existing edge change deterministically to `RIGHT_PREVAILS`;
7. activate the blocked rule without any new semantic LLM call;
8. pin the new `standard_hash` with `is_consistent_for`;
9. submit a superseding amendment and show immutable lineage.

That sequence demonstrates consensus, state design, deterministic mechanics, reuse, and graph compounding in one lifecycle.

# Quorum Integration Guide

## Consumer pattern: pin a constitution

A downstream contract can store:

```text
rulebook_id
expected_standard_hash
```

Before a sensitive transition, it calls Quorum:

```python
quorum = IQuorum(quorum_address)
valid = quorum.view().is_consistent_for(rulebook_id, expected_standard_hash)
```

If `valid` is false, the consumer can fail closed because either the rulebook is inconsistent or active standard state changed since the consumer pinned it. For a resolved-conflict standard, also inspect `standard_status` and `get_standard_relations` before executing an action in an affected scope.

## Consumer pattern: inspect current standard

`get_standard(rulebook_id)` returns active rules with normalized semantics and priority.

`get_standard_relations(rulebook_id)` returns the bounded active-active graph,
including relation kind, semantic hashes, and deterministic conflict resolution.
Consumers must read this view when resolved conflicts are meaningful to execution.

`standard_status(rulebook_id)` makes the distinction explicit:

- `COHERENT`: no active conflict or ambiguity;
- `RESOLVED_CONFLICTS`: conflicts exist, but every active conflict has deterministic precedence;
- `UNRESOLVED`: at least one active conflict has no deterministic winner;
- `AMBIGUOUS`: at least one active relation is semantically ambiguous.

`consistent=true` means no unresolved or ambiguous active relation. It does not
mean that no conflict edge exists.

A consumer can use this as trusted shared context for a separate adjudication contract without repeating normalization work.

## Consumer pattern: inspect a conflict

`relation_between(left_rule_id, right_rule_id)` exposes semantic relation, conflict subtype, overlap description, deterministic resolution, and semantic hashes used by the edge.

This is useful for governance tooling or another Intelligent Contract deciding whether a candidate action enters a disputed part of the rule graph.

## Ownership composition

The rulebook owner is an address. It can be a normal account or another contract-controlled address depending on the governance architecture.

Quorum itself does not implement voting. It is intentionally a primitive for semantic consistency and standard state.

## Recommended integration invariant

For high-stakes consumers, pin all of:

1. Quorum contract address;
2. rulebook ID;
3. expected standard hash.

Do not trust only a human-readable rulebook name.

## Version handling

`revision` changes for any persisted rulebook governance change.

`standard_version` changes only when active standard state changes.

Consumers interested only in operative rules should track `standard_version` and `standard_hash`. Audit systems interested in failed or blocked proposals may also track `revision`.

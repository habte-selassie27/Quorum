# Quorum Architecture

## Design objective

Quorum is designed as a reusable semantic-consistency primitive, not as a policy application.

The contract owns a versioned graph in which rule text, semantic interpretation, pairwise relations, deterministic precedence, lifecycle status, and consumer-facing standard hashes are all explicit on-chain state.

## Layer separation

Quorum has three layers.

### Layer 1: immutable source nodes

A `Rule` begins with authoritative text submitted by the rulebook owner. The text is stored permanently with a Keccak hash.

Quorum does not provide an edit method. Semantic amendments are represented by new nodes. This prevents history from being rewritten underneath old relation receipts.

### Layer 2: consensus semantic graph

GenLayer consensus handles two questions that ordinary deterministic code cannot safely answer for arbitrary prose:

1. What atomic norm does this text express?
2. What is the semantic relationship between two rule nodes?

Those answers are bounded into enums and short standard fields before storage.

### Layer 3: deterministic governance mechanics

Priority, admission, versioning, supersession, repeal, restoration, counts, consistency, and standard hashing are deterministic.

This keeps normative authority outside the model.

## Rulebook lifecycle

```text
create_rulebook
      |
      v
 empty standard
      |
      v
 propose_rule
      |
      +--> normalize by consensus
      |
      +--> compare with every live historical node
      |
      +--> persist relation edges
      |
      +--> deterministic blocker evaluation
                 |
          +------+------+
          |             |
        ACTIVE        BLOCKED
          |             |
          |         priority change
          |             |
          |         activate_blocked_rule
          |             |
          +-------------+
          |
      repeal / supersede
```

## Why blocked nodes stay in the graph

A blocked rule may later become activatable because governance changes its explicit priority or because another active rule is repealed.

If blocked nodes were ignored by later proposals, a previously blocked rule could eventually be activated without ever being compared to rules added after it.

Quorum avoids that gap by comparing each candidate against every currently live historical node, including `BLOCKED` nodes.

That invariant allows deterministic later activation without rerunning old semantic interpretation.

## Strict versus permissive standard

Strict mode is appropriate when downstream systems want a fail-closed rule set. Unresolved semantic relationships cannot enter active standard.

Permissive mode is useful for drafting, research, and governance processes that want unresolved conflicts to remain visible in active state.

The mode is immutable per rulebook so consumers know the admission policy that produced the standard hash.

## Standard version versus revision

`revision` tracks every persisted governance change, including blocked proposals and blocked-rule priority changes.

`standard_version` changes only when active standard state changes.

This distinction prevents a rejected proposal from falsely appearing as a new constitution version while still preserving complete rulebook history.

## Standard hash contents

The hash includes active rules and active-active relation edges. Blocked, repealed, and superseded nodes remain queryable but do not alter current standard.

This allows a consumer to pin exactly the rule system it depended upon.

## Complexity bound

A complete pairwise graph grows quadratically. Quorum therefore limits each
rulebook to 24 nodes: at most 276 unique edges and at most 23 comparisons for
the 24th proposal. Superseded nodes remain in the bounded historical comparison
set because they may be restored later; repealed nodes remain excluded because
there is no repeal-restoration operation.

The contract treats semantic partitioning as part of architecture: large policy systems should use multiple coherent rulebooks instead of a single unbounded graph.

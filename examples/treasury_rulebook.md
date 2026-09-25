# Quorum Treasury Rulebook Example

This example demonstrates the difference between semantic conflict detection and deterministic precedence. It targets the renamed Quorum project and its current official StudioNet deployment, rather than the former Concord deployment.

## Current deployment

- Contract: [`0x367094ed37C0b0C3fC33F378cFCa0b874f41F473`](https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473)
- Explorer: https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473
- Studio import: https://studio.genlayer.com/?import-contract=0x367094ed37C0b0C3fC33F378cFCa0b874f41F473

The deployment above is the current Quorum source. Historical, pre-rename evidence remains under [`proof/`](../proof/).

## Create rulebook

```text
name: Treasury Constitution
purpose: Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury.
strict_mode: true
```

## Rule 1

```text
A treasury withdrawal must not execute when fewer than three approvals are present.
priority: 100
```

Expected result: `ACTIVE`.

## Rule 2

```text
Withdrawals above $10,000 require three approvals before execution.
priority: 100
```

Expected semantic relation with Rule 1: `COMPATIBLE` or `SPECIALIZES` depending on exact normalization. Expected result: `ACTIVE` if validators agree it is jointly satisfiable.

## Rule 3

```text
During an active exploit the security council may execute a withdrawal without three approvals.
priority: 100
```

Expected relation with Rule 1: `CONFLICT` in the emergency-withdrawal overlap.

Because priorities are equal, deterministic resolution is `UNRESOLVED`. In strict mode Rule 3 becomes `BLOCKED`.

## Resolve without semantic reinterpretation

Governance can explicitly change the blocked Rule 3 priority:

```text
set_blocked_rule_priority(rule_3, 200)
```

The stored conflict edge is recomputed deterministically as `RIGHT_PREVAILS`.

Then:

```text
activate_blocked_rule(rule_3)
```

No LLM is asked to reinterpret Rule 3. The semantic graph is reused.

## Amendment

To change Rule 1 from three approvals to four approvals, do not edit Rule 1. Submit a new rule:

```text
A treasury withdrawal must not execute when fewer than four approvals are present.
supersedes_rule_id: rule_1
```

If the relation is a plausible replacement and the node has no unresolved blockers, Quorum activates it and marks Rule 1 `SUPERSEDED` atomically, preserving historical standard.

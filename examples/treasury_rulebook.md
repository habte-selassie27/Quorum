# Quorum Treasury Rulebook Example

This example demonstrates the difference between semantic conflict detection and deterministic precedence. It targets the renamed Quorum project and its current official StudioNet deployment.

## Current deployment

- Contract: [`0x367094ed37C0b0C3fC33F378cFCa0b874f41F473`](https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473)
- Explorer: https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473
- Studio import: https://studio.genlayer.com/?import-contract=0x367094ed37C0b0C3fC33F378cFCa0b874f41F473

The deployment above is the current Quorum source.

## Create rulebook

```text
name: Treasury Constitution
purpose: Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury.
strict_mode: true
```

```bash
export QUORUM_CONTRACT="0x367094ed37C0b0C3fC33F378cFCa0b874f41F473"
BOOK_ID=1
RULE_A_ID=1
BLOCKED_RULE_ID=3
AMENDMENT_RULE_ID=4

genlayer write "$QUORUM_CONTRACT" create_rulebook \
  --args "Treasury Constitution" \
  "Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury." \
  true
```

Wait for finalization with `genlayer receipt <TRANSACTION_HASH> --status FINALIZED --retries 60 --interval 3000`.

## Rule 1

```text
A treasury withdrawal must not execute when fewer than three approvals are present.
priority: 100
```

```bash
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than three approvals are present." \
  100 0
```

Expected result: `ACTIVE`.

## Rule 2

```text
Withdrawals above $10,000 require three approvals before execution.
priority: 100
```

```bash
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "Withdrawals above 10000 USD require three approvals before execution." \
  100 0
```

Expected semantic relation with Rule 1: `COMPATIBLE` or `SPECIALIZES` depending on exact normalization. Expected result: `ACTIVE` if validators agree it is jointly satisfiable.

## Rule 3

```text
During an active exploit the security council may execute a withdrawal without three approvals.
priority: 100
```

```bash
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "During an active exploit the security council may execute a withdrawal without three approvals." \
  100 0
```

Expected relation with Rule 1: `CONFLICT` in the emergency-withdrawal overlap.

Because priorities are equal, deterministic resolution is `UNRESOLVED`. In strict mode Rule 3 becomes `BLOCKED`.

```bash
genlayer call "$QUORUM_CONTRACT" relation_between --args "$RULE_A_ID" "$BLOCKED_RULE_ID"
genlayer call "$QUORUM_CONTRACT" blocking_reason --args "$BLOCKED_RULE_ID"
```

## Resolve without semantic reinterpretation

Governance can explicitly change the blocked Rule 3 priority:

```text
set_blocked_rule_priority(rule_3, 200)
```

```bash
genlayer write "$QUORUM_CONTRACT" set_blocked_rule_priority --args "$BLOCKED_RULE_ID" 200
```

The stored conflict edge is recomputed deterministically as `RIGHT_PREVAILS`.

Then:

```text
activate_blocked_rule(rule_3)
```

```bash
genlayer write "$QUORUM_CONTRACT" activate_blocked_rule --args "$BLOCKED_RULE_ID"
```

No LLM is asked to reinterpret Rule 3. The semantic graph is reused.

## Amendment

To change Rule 1 from three approvals to four approvals, do not edit Rule 1. Submit a new rule:

```text
A treasury withdrawal must not execute when fewer than four approvals are present.
supersedes_rule_id: rule_1
```

```bash
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than four approvals are present." \
  100 "$RULE_A_ID"
```

If the relation is a plausible replacement and the node has no unresolved blockers, Quorum activates it and marks Rule 1 `SUPERSEDED` atomically, preserving historical standard.

## Complete lifecycle

Use the returned amendment rule ID for the repeal, then restore the superseded original:

```bash
genlayer write "$QUORUM_CONTRACT" repeal_rule --args "$AMENDMENT_RULE_ID"
genlayer write "$QUORUM_CONTRACT" restore_superseded_rule --args "$RULE_A_ID"
```

## Read back the standard

```bash
genlayer call "$QUORUM_CONTRACT" get_rulebook           --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_standard           --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_standard_relations --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" standard_status        --args "$BOOK_ID"

STANDARD_HASH=$(genlayer call "$QUORUM_CONTRACT" current_standard_hash --args "$BOOK_ID" \
  | awk '/^Result:/{getline; print; exit}')
genlayer call "$QUORUM_CONTRACT" is_consistent_for --args "$BOOK_ID" "$STANDARD_HASH"
```

The full command sheet, including `repeal_rule` and `restore_superseded_rule`, is in [`DEPLOYMENT.md`](../DEPLOYMENT.md#runtime-smoke-sequence) and scripted in [`scripts/smoke.sh`](../scripts/smoke.sh).

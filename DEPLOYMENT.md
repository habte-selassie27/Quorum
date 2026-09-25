# Quorum Deployment

## Current repository status

The repository source below is deployed and finalized on GenLayer StudioNet as
the official deployment. The deployed source was read back from the explorer
and verified byte-identical to `contracts/quorum.py`.

| Field | Value |
|---|---|
| Source | `contracts/quorum.py` (sha256 `74b0ce915ff51fe7cfc685f1804caa33317109d178296ceac61cf8c001039f53`) |
| Network | GenLayer StudioNet |
| Deployment method | GenLayer Studio manual deployment |
| Deployer | `0x04e0353B7218b66D6803725ce7342E6e1225DB1b` |
| Deployment transaction | `0xf9ae9480ba78ee5252b7b3d8eb0267851551d411956f4a43457bf674f6ab01c2` |
| Contract address | `0x367094ed37C0b0C3fC33F378cFCa0b874f41F473` |
| Created | `2026-09-25T11:41:22+00:00` |
| Deployment receipt | `FINALIZED`, GenVM `SUCCESS`, consensus `Accepted` (`3 agree / 2 idle`, 5 validator slots) |
| Explorer | https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473 |
| Studio import | https://studio.genlayer.com/?import-contract=0x367094ed37C0b0C3fC33F378cFCa0b874f41F473 |

Sanitized record: [`proof/official-deployment.json`](proof/official-deployment.json).

Source identity can be re-verified from the public explorer transaction API:
base64-decode the `data.contract_code` field of the deploy transaction and
compare its sha256 with the value above.

The previous hardened deployment at `0x67a027446838296FcB3022B376c8ff3873a4566C`
(source commit `bd6682d81afa7063d6b595dcdab04d220aed8bbb`) is historical because
the contract source was renamed to Quorum after that deployment; it still holds
the complete lifecycle evidence recorded below. The deployment before that at
`0xf529EDf5291B7fB78f0ba3922b9162A593972020` is historical for the same reason.

## Requirements

- Node.js and npm
- GenLayer CLI
- a funded active account for the selected network

Current official CLI documentation lists direct deployment as:

```bash
genlayer deploy --contract <contractPath>
```

Quorum has no constructor arguments.

## Install CLI

```bash
npm install -g genlayer
genlayer --version
```

## Select StudioNet

```bash
genlayer network set studionet
genlayer config get network
genlayer account show
```

Use an existing active account if one is already configured. Do not commit private keys or passwords to this repository.

## Deploy

```bash
genlayer deploy --contract contracts/quorum.py
```

Record only real output:

```text
Network: studionet
Contract address: <finalized address>
Deployment transaction: <transaction hash>
Deployment status: <accepted/finalized>
CLI version: <version>
```

## Runtime smoke sequence

After deployment, use the Studio or CLI to execute the lifecycle in `examples/treasury_rulebook.md`.
The complete sequence is scripted in [`scripts/smoke.sh`](scripts/smoke.sh):

```bash
scripts/smoke.sh            # read-only: exercises all 11 view methods
scripts/smoke.sh --write    # full write lifecycle, then the views (spends fees)
```

### Setup

```bash
export QUORUM_CONTRACT="0x367094ed37C0b0C3fC33F378cFCa0b874f41F473"
BOOK_ID=1
RULE_A_ID=1
RULE_B_ID=2
BLOCKED_RULE_ID=3
AMENDMENT_RULE_ID=4
RELATION_ID=1

genlayer network set studionet
genlayer account use rabby
genlayer account unlock --account rabby

# wait for finalization, and capture the hash used for pinning
wait_tx() { genlayer receipt "$1" --status FINALIZED --retries 60 --interval 3000; }
std_hash() { genlayer call "$QUORUM_CONTRACT" current_standard_hash --args "$1" | awk '/^Result:/{getline; print; exit}'; }
```

### Write methods

The script waits for each transaction to finalize automatically. When running the commands manually, wait with `wait_tx <TRANSACTION_HASH>` before the next dependent write.

```bash
# 1. returns rulebook_id (first rulebook on a fresh contract is 1)
genlayer write "$QUORUM_CONTRACT" create_rulebook \
  --args "Treasury Constitution" \
  "Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury." \
  true

# 2. Rule A -> expect ACTIVE
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than three approvals are present." \
  100 0

# 3. Rule B -> expect ACTIVE
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "Withdrawals above 10000 USD require three approvals before execution." \
  100 0

# 4. Rule C -> equal-priority CONFLICT, expect BLOCKED (this is BLOCKED_RULE_ID)
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "During an active exploit the security council may execute a withdrawal without three approvals." \
  100 0

# 5-6. deterministic precedence, no LLM reinterpretation
genlayer write "$QUORUM_CONTRACT" set_blocked_rule_priority \
  --args "$BLOCKED_RULE_ID" 200

genlayer write "$QUORUM_CONTRACT" activate_blocked_rule \
  --args "$BLOCKED_RULE_ID"

# 7. amendment: 4th argument is supersedes_rule_id
genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than four approvals are present." \
  100 "$RULE_A_ID"

# lifecycle: repeal the replacement, then restore the superseded original
genlayer write "$QUORUM_CONTRACT" repeal_rule --args "$AMENDMENT_RULE_ID"
genlayer write "$QUORUM_CONTRACT" restore_superseded_rule --args "$RULE_A_ID"
```

`set_blocked_rule_priority` and `activate_blocked_rule` require a `BLOCKED` rule.
`restore_superseded_rule` requires a `SUPERSEDED` rule whose replacement is no longer active.

### Read methods

```bash
genlayer call "$QUORUM_CONTRACT" get_rulebook            --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_rule                --args "$RULE_A_ID"
genlayer call "$QUORUM_CONTRACT" get_relation            --args "$RELATION_ID"
genlayer call "$QUORUM_CONTRACT" relation_between        --args "$RULE_A_ID" "$BLOCKED_RULE_ID"
genlayer call "$QUORUM_CONTRACT" get_standard            --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_standard_relations  --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" standard_status         --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" blocking_reason         --args "$BLOCKED_RULE_ID"
genlayer call "$QUORUM_CONTRACT" is_consistent           --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" current_standard_hash   --args "$BOOK_ID"

# pin check using the hash just read
STANDARD_HASH=$(std_hash "$BOOK_ID")
genlayer call "$QUORUM_CONTRACT" is_consistent_for --args "$BOOK_ID" "$STANDARD_HASH"
```

Names were renamed from the earlier sheets: `RULE_GRAPH_CONTRACT` -> `QUORUM_CONTRACT`,
`get_rule_graph` -> `get_standard`, `get_rule_graph_relations` -> `get_standard_relations`,
`rule_graph_status` -> `standard_status`, `current_rule_graph_hash` -> `current_standard_hash`,
`CANON_HASH` -> `STANDARD_HASH`.

Minimum proof should include:

1. rulebook creation;
2. first active rule;
3. equal-priority conflicting rule blocked in strict mode;
4. relation edge showing `CONFLICT` + `UNRESOLVED`;
5. blocked-rule priority update;
6. same relation edge showing deterministic precedence;
7. blocked rule activation;
8. new standard hash;
9. successful `is_consistent_for` call using that exact hash.

## Lifecycle evidence (previous hardened deployment)

The previous hardened deployment at `0x67a027446838296FcB3022B376c8ff3873a4566C`
has a complete clean lifecycle on rulebook `1`: two CLEAR rules, a stored CONFLICT edge, equal-priority blocking, deterministic priority resolution on the same edge, activation without semantic re-analysis, and final `RESOLVED_CONFLICTS` standard state. The current official deployment at `0x367094ed37C0b0C3fC33F378cFCa0b874f41F473` has only its deployment transaction so far; run the smoke sequence below against it to produce equivalent evidence.

| Operation | Transaction | Observed result |
|---|---|---|
| Create final proof rulebook 1 | `0x9a7f171de158b3096b70b224ee70369e68740bc606bcfb7806a70d67bc2852e4` | Finalized; strict; rulebook 1 |
| Propose Rule A | `0x5925745612a28ebea221145467437dded0d8de736907a4b3398b7b2aa13b848f` | Finalized; CLEAR; ACTIVE; standard v1 |
| Propose equal-priority Rule B | `0x79ffc24bc6f70a2ca1b271851e245c5571586395d8b0e402a369de010b930340` | Finalized; CLEAR; `CONFLICT` / `UNRESOLVED`; BLOCKED |
| Set Rule B priority to 200 | `0x7b60cbeb65805a5c8a4a5c7820d672bb5bef222bb70af0633efdc5d1d9e71525` | Finalized; same relation `RIGHT_PREVAILS`; blocking reason empty |
| Activate Rule B | `0x8becc751189a7074526264ef92f770be35c9cd7e03e52fa518e4f9468701477d` | Finalized; Rule B ACTIVE; standard v2 |

## Historical live lifecycle

The following sequential transactions were finalized or observed committed
against the previous deployment. Rulebook `2` was the clean historical proof
rulebook; rulebook `1` also contains live exploratory writes but is not used for
the final proof state.

| Operation | Transaction | Observed result |
|---|---|---|
| Create proof rulebook | `0xbc95c28953b85e00447979bd0aa1b6a105f9c997c62b8a01988382bd0bb9d5e0` | Rulebook `2`, strict, standard v0, consistent |
| Propose rule 3 | `0xa4c252f40b98ead5a6bae2af60cf0493960f6ae2ae56094777f15fc8a6918c06` | Active; standard v1 `5202f13875fc753031ad2951be91637908a165ae537ddf391878f335aa968745` |
| Propose rule 4 | `0x83e4ce10d9e8c48c44305f974a61abff576767cd2e043b501cef2cdf4f299802` | Finalized; blocked; relation `CONFLICT` / `UNRESOLVED` |
| Set rule 4 priority | `0x4429817be6d9c0c348f8674e7dc395f17e65ec7f50636ae2242198450a268252` | Priority changed to `200`; same edge became `RIGHT_PREVAILS` |
| Activate rule 4 | `0xa99c6b7fbd4d251d755f067114a0a789bd8df56287a81b3d11b803ccdbdbb054` | Two active rules; `RESOLVED_CONFLICTS`; standard v2 `db9debd7e8fa063f9c824f6343263b40fedf12fa32dba1d0bda6881626aa9e30` |

Final relation readback: relation `2`, rule `3 -> 4`, kind `CONFLICT`, reason
`REQUIRE_VS_PERMIT_APPROVAL_BYPASS`, resolution `RIGHT_PREVAILS`. Final rulebook readback:
`active_count=2`, `blocked_count=0`, `relation_count=1`,
`resolved_conflicts=1`, `unresolved_conflicts=0`, `standard_status=RESOLVED_CONFLICTS`,
`consistent=true`. Exact `is_consistent_for` returned `true`; a zero hash returned
`false`.

Sanitized machine-readable artifacts are in [`proof/`](proof/): deployment,
rulebook, semantic rule, conflict, priority-update, activation, and final-state
records. They contain no private keys or credentials.

## Test before/after deployment

Local Direct Mode:

```bash
python -m pip install -r requirements-dev.txt
gltest tests/test_quorum.py -v -s
```

Offline repository preflight:

```bash
python scripts/preflight.py
```

Hosted smoke sequence (read-only by default):

```bash
scripts/smoke.sh            # all 11 view methods against QUORUM_CONTRACT
scripts/smoke.sh --write    # full 6-method write lifecycle, then the views
```

Hosted network integration can then be added using GenLayer Test once the finalized contract address is known.

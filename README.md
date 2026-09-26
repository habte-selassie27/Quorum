# Quorum

**A consensus-backed semantic consistency and deterministic precedence layer for natural-language rule systems on GenLayer.**

Quorum is a standalone Intelligent Contract primitive. It does not ship a frontend and it does not require a backend. The contract itself is the source of truth.

Natural-language constitutions, policies, agent mandates, protocol rules, operating procedures, and marketplace terms often fail before enforcement even begins: two individually reasonable rules can overlap, contradict each other, silently duplicate each other, or introduce an exception whose authority is unclear.

Quorum turns a rulebook into persistent shared state that other contracts can inspect and pin.

Instead of repeatedly asking an LLM, "is this policy okay?", Quorum maintains:

- immutable rule nodes;
- consensus-normalized semantics for each node;
- consensus-backed pairwise semantic relations;
- deterministic precedence for conflicting rules;
- strict and permissive standard modes;
- blocked-rule recovery without reinterpreting old semantics;
- explicit supersession and repeal lineage;
- standard versioning and a deterministic standard hash;
- a typed cross-contract interface for downstream consumers.

The result is not a one-shot AI verdict. It is a living, versioned rule graph whose usefulness increases as more rules are added.

Current official StudioNet deployment: [`0x367094ed37C0b0C3fC33F378cFCa0b874f41F473`](https://explorer-studio.genlayer.com/address/0x367094ed37C0b0C3fC33F378cFCa0b874f41F473)
([import into Studio](https://studio.genlayer.com/?import-contract=0x367094ed37C0b0C3fC33F378cFCa0b874f41F473)),
deploy tx `0xf9ae9480ba78ee5252b7b3d8eb0267851551d411956f4a43457bf674f6ab01c2`,
deploy source verified identical to `contracts/quorum.py`. The previous hardened
deployment `0x67a027446838296FcB3022B376c8ff3873a4566C` (commit `bd6682d...`)
retains the full lifecycle evidence. See the
[deployment and sanitized proof records](DEPLOYMENT.md).

## Why this primitive exists

Traditional smart contracts are excellent when rules are already formalized. They are less useful when the authoritative rules are written in natural language and two questions must be answered before deterministic execution can proceed:

1. What does each rule materially require, permit, or prohibit?
2. Can the active rules coexist, and if not, which rule has protocol-level precedence?

The first question is semantic and is handled through GenLayer consensus.

The second is split deliberately:

- **semantic conflict detection** is consensus-backed;
- **precedence resolution** is deterministic contract logic.

That separation is a core design invariant. Validators are never asked to invent authority.

## Example

Suppose a treasury constitution contains:

> A treasury withdrawal must not execute when fewer than three approvals are present.

Later, an emergency amendment says:

> During an active exploit the security council may execute a withdrawal without three approvals.

The semantic layer can establish that the two rules conflict in the emergency-withdrawal overlap.

Quorum does **not** ask an LLM which rule wins.

If both rules have equal priority, a strict rulebook blocks the new rule as an unresolved conflict.

If governance deliberately assigns the emergency rule a higher priority, deterministic state resolves the edge as `RIGHT_PREVAILS` and the standard can remain consistent.

That distinction prevents an AI model from silently manufacturing constitutional hierarchy.

## State model

### Rulebook

A rulebook stores owner, name/purpose, strict mode, revision, standard version, rule/relation IDs, counts, consistency, and a deterministic `standard_hash`.

### Rule

Each rule stores immutable source text/hash, normalized modality, actor, action, object, condition, exception, scope, semantic clarity, semantic hash, priority, lifecycle status, version metadata, supersession lineage, and relation IDs.

A rule must represent one atomic normative proposition. Multi-clause or materially unclear text fails closed to `AMBIGUOUS` and cannot enter active standard.

### Relation

Every live pair receives a persistent semantic edge:

- `UNRELATED`
- `COMPATIBLE`
- `REDUNDANT`
- `SPECIALIZES`
- `CONFLICT`
- `AMBIGUOUS`

Conflict edges also receive deterministic resolution:

- `LEFT_PREVAILS`
- `RIGHT_PREVAILS`
- `UNRESOLVED`

Relations store both semantic hashes so each edge is pinned to the exact interpretations compared.

## Consensus architecture

Quorum has exactly two explicit custom consensus boundaries.

### 1. Rule normalization

The leader proposes a bounded semantic representation of one natural-language rule. The validator does **not** merely compare JSON shape: it independently checks whether the candidate is faithful, materially complete, conservative, atomic, and free from invented conditions, exceptions, scope, or authority.

### 2. Pairwise relation analysis

For every live historical rule in the same rulebook, the leader proposes the semantic relationship between the old node and the candidate. Validators independently verify that relationship against both immutable rule texts and both semantic records.

A leader cannot safely hide a real conflict by returning `COMPATIBLE`, because validators re-evaluate whether both rules can jointly be satisfied in their material overlap.

Both boundaries use `gl.vm.run_nondet_unsafe` with explicit validator functions.

See [`docs/CONSENSUS.md`](docs/CONSENSUS.md).

## Deterministic protocol mechanics

Once semantic facts are accepted, Quorum uses deterministic state transitions for everything else.

### Priority

Priority is an explicit integer from `0` to `1000`. Larger values have stronger precedence.

If two active rules conflict:

- left priority > right priority -> `LEFT_PREVAILS`;
- right priority > left priority -> `RIGHT_PREVAILS`;
- equal priority -> `UNRESOLVED`.

The LLM never chooses the winner.

### Strict mode

In strict mode a candidate is blocked when its semantics are ambiguous, an active pairwise relation is ambiguous, a conflict has no deterministic precedence, or declared supersession is unrelated/ambiguous.

Blocked rules stay in history and in the graph but do not enter standard active state.

### Permissive mode

A permissive rulebook may admit a rule with unresolved conflict. The active standard then exposes `consistent = false` and the exact unresolved edges remain queryable. A resolved conflict is different: `consistent = true`, `has_conflicts = true`, and `standard_status = RESOLVED_CONFLICTS`.

### Blocked-rule recovery

A blocked rule can change **priority only**. Its text and semantic interpretation remain immutable. If the new priority resolves its conflicts, it can be activated without asking validators to reinterpret the rule.

### Supersession, repeal, restoration

Amendments are new immutable nodes. A declared replacement is semantically checked against its target before activation. Repeal never deletes history. A superseded rule can only be restored after its replacement becomes inactive and the graph shows it can safely re-enter standard. Superseded nodes remain eligible for future pairwise comparison, so later rules cannot create a restoration-time missing edge. Restoration also checks blocked relations, preventing a known unresolved edge from being bypassed.

## Standard hash

The `standard_hash` commits to active rules and active-active relation structure, including rule IDs, text hashes, semantic hashes, priorities, supersession targets, relation kinds, conflict subtypes, resolutions, and strict/permissive mode.

Downstream contracts can pin an exact coherent constitution:

```python
@gl.contract_interface
class IQuorum:
    class View:
        def is_consistent_for(self, rulebook_id: u256, expected_standard_hash: str) -> bool: ...
```

A consumer can fail closed if the rulebook changed or became inconsistent.

## Public methods

Writes:

- `create_rulebook(name, purpose, strict_mode=True)`
- `propose_rule(rulebook_id, text, priority=100, supersedes_rule_id=0)`
- `set_blocked_rule_priority(rule_id, priority)`
- `activate_blocked_rule(rule_id)`
- `repeal_rule(rule_id)`
- `restore_superseded_rule(rule_id)`

Views:

- `get_rulebook(rulebook_id)`
- `get_rule(rule_id)`
- `get_relation(relation_id)`
- `relation_between(left_rule_id, right_rule_id)`
- `get_standard(rulebook_id)`
- `get_standard_relations(rulebook_id)`
- `standard_status(rulebook_id)`
- `blocking_reason(rule_id)`
- `is_consistent(rulebook_id)`
- `is_consistent_for(rulebook_id, expected_standard_hash)`
- `current_standard_hash(rulebook_id)`

## Cross-contract use cases

Quorum can sit underneath DAO constitutions, treasury governance, autonomous-agent mandates, marketplace rulebooks, insurance policy stacks, procurement policies, protocol emergency procedures, compliance rule sets, and multi-party operating agreements.

See [`docs/INTEGRATION.md`](docs/INTEGRATION.md).

## Why this is not a thin LLM wrapper

The model cannot directly mutate arbitrary state and cannot choose precedence. The contract provides the protocol:

1. create a bounded rulebook;
2. freeze candidate text;
3. consensus-normalize the rule;
4. consensus-create pairwise semantic edges;
5. deterministic precedence resolution;
6. strict-mode standard gating;
7. persistent blocked/history nodes;
8. supersession and repeal lineage;
9. hashed standard state for consumers;
10. later rules compare against older active, blocked, and restorable superseded nodes.

The valuable output is the accumulated graph and standard state, not generated prose.

## Bounded cost

Pairwise semantic analysis is intentionally bounded to **24 rules per rulebook**. The maximum unique graph size is `24 * 23 / 2 = 276` edges, and adding the 24th node requires at most 23 new comparisons. The same global bound applies when restorable superseded nodes are retained for graph completeness. Large organizations should partition rules into coherent rulebooks instead of creating one unbounded policy graph.

## Security model

Key properties include untrusted-data prompt boundaries, bounded/standardized outputs, substantive validator review, fail-closed ambiguity, model-independent authority, immutable active priority, immutable semantic history, semantic-hash-pinned edges, strict blocked-rule admission, standard hash pinning, and retained repeal/supersession history.

See [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md).

## Repository layout

```text
contracts/quorum.py
tests/test_quorum.py
scripts/preflight.py
scripts/smoke.sh
docs/ARCHITECTURE.md
docs/CONSENSUS.md
docs/INTEGRATION.md
docs/THREAT_MODEL.md
docs/images/terminal/
examples/treasury_rulebook.md
SUBMISSION.md
DEPLOYMENT.md
```

There is intentionally no frontend directory.

## Testing

Offline preflight:

```bash
python scripts/preflight.py
```

Current repository preflight result at creation:

```text
Quorum offline preflight: 14/14 checks passed
```

GenLayer Direct Mode:

```bash
python -m pip install -r requirements-dev.txt
gltest tests/test_quorum.py -v -s
```

`tests/test_quorum.py` contains 49 Direct Mode scenarios covering independent validator derivation, symmetric semantic-state convergence, malicious disagreement, lifecycle, malformed outputs, prompt-injection behavior, multi-conflict precedence, blocked-rule graph enrichment, nested supersession/restoration safety, standard status/pinning, and the 24-rule bound.

Live StudioNet smoke test against the deployed contract:

```bash
export QUORUM_CONTRACT="0x367094ed37C0b0C3fC33F378cFCa0b874f41F473"
scripts/smoke.sh            # read-only: all 11 view methods
scripts/smoke.sh --write    # full write lifecycle, then the views (spends fees)
```

The individual `genlayer write` / `genlayer call` commands for all 6 write and 11 read methods are listed in [`DEPLOYMENT.md`](DEPLOYMENT.md#runtime-smoke-sequence).

## StudioNet terminal walkthrough

The captures below come from an actual StudioNet terminal session using the active Rabby account. The contract starts empty, so run the write sequence first; it creates rulebook `1` and rules `1`–`4`. Wait for `FINALIZED` after every write before starting the next dependent operation.

The full command sheet is in [`DEPLOYMENT.md`](DEPLOYMENT.md#runtime-smoke-sequence). The captures are retained in `docs/images/terminal/`.

Consensus is model-dependent. In this capture, Rule C was accepted as `ACTIVE` rather than `BLOCKED`, so the priority-update and activation writes returned execution errors. The readbacks still completed and showed a coherent standard. Use the Direct Mode suite for deterministic lifecycle assertions.

### Setup

```bash
cd /home/izzy/Music/Quorum
genlayer network set studionet
genlayer account use rabby
genlayer account unlock --account rabby
genlayer account show
export QUORUM_CONTRACT="0x367094ed37C0b0C3fC33F378cFCa0b874f41F473"
BOOK_ID=1
RULE_A_ID=1
RULE_B_ID=2
BLOCKED_RULE_ID=3
AMENDMENT_RULE_ID=4
RELATION_ID=1
wait_tx() { genlayer receipt "$1" --status FINALIZED --retries 60 --interval 3000; }
```

### Write sequence

Run each command, copy its printed `Write Transaction Hash`, set `TX_HASH` to that value without `<` or `>`, then run `wait_tx "$TX_HASH"` before continuing.

```bash
genlayer write "$QUORUM_CONTRACT" create_rulebook \
  --args "Treasury Constitution" \
  "Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury." \
  true

genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than three approvals are present." \
  100 0

genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "Withdrawals above 10000 USD require three approvals before execution." \
  100 0

genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "During an active exploit the security council may execute a withdrawal without three approvals." \
  100 0

genlayer write "$QUORUM_CONTRACT" set_blocked_rule_priority \
  --args "$BLOCKED_RULE_ID" 200

genlayer write "$QUORUM_CONTRACT" activate_blocked_rule \
  --args "$BLOCKED_RULE_ID"

genlayer write "$QUORUM_CONTRACT" propose_rule \
  --args "$BOOK_ID" \
  "A treasury withdrawal must not execute when fewer than four approvals are present." \
  100 "$RULE_A_ID"

genlayer write "$QUORUM_CONTRACT" repeal_rule \
  --args "$AMENDMENT_RULE_ID"

genlayer write "$QUORUM_CONTRACT" restore_superseded_rule \
  --args "$RULE_A_ID"
```

### Read sequence

```bash
genlayer call "$QUORUM_CONTRACT" get_rulebook --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_rule --args "$RULE_A_ID"
genlayer call "$QUORUM_CONTRACT" get_relation --args "$RELATION_ID"
genlayer call "$QUORUM_CONTRACT" relation_between --args "$RULE_A_ID" "$BLOCKED_RULE_ID"
genlayer call "$QUORUM_CONTRACT" get_standard --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" get_standard_relations --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" standard_status --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" blocking_reason --args "$BLOCKED_RULE_ID"
genlayer call "$QUORUM_CONTRACT" is_consistent --args "$BOOK_ID"
genlayer call "$QUORUM_CONTRACT" current_standard_hash --args "$BOOK_ID"

STANDARD_HASH="$(genlayer call "$QUORUM_CONTRACT" current_standard_hash \
  --args "$BOOK_ID" | awk '/^Result:/{getline; print; exit}')"
printf '%s\n' "$STANDARD_HASH"
genlayer call "$QUORUM_CONTRACT" is_consistent_for \
  --args "$BOOK_ID" "$STANDARD_HASH"
```

### Selected captures

![StudioNet network selection](docs/images/terminal/2026-09-26-05-54-57.png)

![Rulebook creation and Rabby-signed write](docs/images/terminal/2026-09-26-06-11-38.png)

![Final standard pin verification](docs/images/terminal/2026-09-26-06-35-20.png)

<details>
<summary>Full terminal capture gallery (38 screenshots)</summary>

### Setup captures

![Network selection](docs/images/terminal/2026-09-26-05-54-57.png)

![Rabby account selection](docs/images/terminal/2026-09-26-05-55-10.png)

![Rabby unlock](docs/images/terminal/2026-09-26-05-55-25.png)

![Contract address export](docs/images/terminal/2026-09-26-05-55-37.png)

![IDs and receipt helper](docs/images/terminal/2026-09-26-06-11-11.png)

### Write captures

![Create rulebook command](docs/images/terminal/2026-09-26-06-11-38.png)

![Create rulebook receipt](docs/images/terminal/2026-09-26-06-11-50.png)

![Create rulebook receipt continuation](docs/images/terminal/2026-09-26-06-13-48.png)

![Rule A write](docs/images/terminal/2026-09-26-06-13-56.png)

![Rule B write](docs/images/terminal/2026-09-26-06-15-55.png)

![Rule B receipt continuation](docs/images/terminal/2026-09-26-06-16-02.png)

![Rule C write](docs/images/terminal/2026-09-26-06-18-53.png)

![Rule C receipt continuation](docs/images/terminal/2026-09-26-06-19-00.png)

![Rule status readback](docs/images/terminal/2026-09-26-06-19-29.png)

![Blocking reason readback](docs/images/terminal/2026-09-26-06-19-52.png)

![Priority update attempt](docs/images/terminal/2026-09-26-06-20-45.png)

![Priority update receipt continuation](docs/images/terminal/2026-09-26-06-20-53.png)

![Activation attempt](docs/images/terminal/2026-09-26-06-21-34.png)

![Activation receipt continuation](docs/images/terminal/2026-09-26-06-21-40.png)

![Amendment write](docs/images/terminal/2026-09-26-06-25-58.png)

![Amendment receipt continuation](docs/images/terminal/2026-09-26-06-26-06.png)

![Repeal attempt](docs/images/terminal/2026-09-26-06-26-36.png)

![Repeal receipt continuation](docs/images/terminal/2026-09-26-06-26-42.png)

![Restore attempt](docs/images/terminal/2026-09-26-06-27-12.png)

![Restore receipt continuation](docs/images/terminal/2026-09-26-06-27-24.png)

### Read captures

![Rulebook readback](docs/images/terminal/2026-09-26-06-28-28.png)

![Rule readback](docs/images/terminal/2026-09-26-06-28-48.png)

![Relation readback](docs/images/terminal/2026-09-26-06-29-06.png)

![Relation between rules](docs/images/terminal/2026-09-26-06-29-18.png)

![Standard rules](docs/images/terminal/2026-09-26-06-30-19.png)

![Standard relations](docs/images/terminal/2026-09-26-06-30-46.png)

![Standard status](docs/images/terminal/2026-09-26-06-31-18.png)

![Blocking reason](docs/images/terminal/2026-09-26-06-32-46.png)

![Consistency check](docs/images/terminal/2026-09-26-06-33-14.png)

![Current standard hash](docs/images/terminal/2026-09-26-06-33-41.png)

![Hash capture command](docs/images/terminal/2026-09-26-06-34-26.png)

![Captured hash output](docs/images/terminal/2026-09-26-06-34-45.png)

![Exact standard pin](docs/images/terminal/2026-09-26-06-35-20.png)

</details>

## Deployment

Quorum has no constructor arguments.

```bash
npm install -g genlayer
genlayer network set studionet
genlayer account show
genlayer deploy --contract contracts/quorum.py
```

See [`DEPLOYMENT.md`](DEPLOYMENT.md) for the verification sequence. A live address is only recorded after actual finalization.

## GenLayer references

- https://docs.genlayer.com/developers/intelligent-contracts/introduction
- https://docs.genlayer.com/developers/intelligent-contracts/equivalence-principle
- https://docs.genlayer.com/developers/intelligent-contracts/storage
- https://docs.genlayer.com/developers/intelligent-contracts/deploying/cli-deployment
- https://docs.genlayer.com/api-references/genlayer-test

## License

MIT

# Quorum Threat Model

## Protected assets

Quorum protects the integrity of immutable rule text, normalized semantic meaning, the pairwise conflict graph, explicit precedence, lifecycle history, standard consistency state, and downstream `standard_hash` pins.

## Threat: anchoring on a leader candidate

Consequence: a validator may anchor on a plausible leader classification instead of independently deriving the material answer.

Mitigation: normalization validators independently derive semantics from the original purpose and rule text; relation validators independently classify both original rules and accepted semantic records. Semantic-state disagreement rejects the leader proposal in either direction. Equivalence compares stable protocol facts rather than explanatory prose.

Residual limitation: semantic judgment remains model-mediated, and bounded equivalence still cannot mathematically prove natural-language meaning.

## Threat: malicious leader changes rule meaning

Example: source text prohibits an action but the leader returns `PERMIT`.

Mitigation: validators independently derive semantics from the original immutable text, then compare stable facts to the leader result. Direct Mode tests include malicious-leader and disagreement cases.

## Threat: leader hides a real conflict

Example: two rules cannot jointly be satisfied but the leader returns `COMPATIBLE`.

Mitigation: pairwise relation edges have their own independent derivation prompt. Validators must independently classify both rules and agree on the authoritative relation kind. Conflict subtype, overlap, and reason code remain explanatory metadata only.

## Threat: prompt injection in rule text or rulebook purpose

Consequence: a leader treats quoted policy data as instructions and returns a false normalization or relation.

Mitigation: prompts label purpose and rule text as untrusted data; validators receive the original data and independently verify substance. Behavioral tests cover normalization injection, relation injection, authority claims, and output-format imitation.

Residual limitation: consensus quality still depends on validator availability and model capability; no prompt boundary proves semantic truth mathematically.

## Threat: malformed model output

Consequence: non-dict, missing-field, unknown-enum, oversized, or malformed relation output could corrupt standard state.

Mitigation: standardization maps malformed semantics to `AMBIGUOUS`, rejects oversized semantic fields, and maps invalid relation subtypes to an ambiguous edge. Strict mode blocks these states; validators reject invalid shapes.

Residual limitation: permissive rulebooks can intentionally retain ambiguous draft state, so consumers must use structured status and fail closed.

## Threat: model invents hierarchy

Mitigation: relation prompts are explicitly forbidden from using priority. Precedence is computed deterministically from stored priority and declared supersession.

## Threat: ambiguous prose enters strict standard

Mitigation: non-atomic or semantically incomplete rules fail closed to `AMBIGUOUS`, which blocks activation. Ambiguous pairwise relations also block admission in strict mode.

## Threat: governance rewrites history

Mitigation: active rule text and semantic interpretation are immutable. Priority can change only while a rule is blocked. Amendments create new rule nodes and explicit supersession lineage.

## Threat: later activation skips newer rules

Mitigation: every newly proposed live node is compared with active, blocked, and superseded historical nodes. A blocked or restorable rule therefore accumulates relations with rules created after it. Restoration checks blocked edges too.

## Threat: superseded restoration stale graph

Consequence: an old rule is restored after a newer rule exists without an edge to that newer rule.

Mitigation: superseded nodes remain in the bounded comparison set, and restoration requires complete relation coverage. Missing or unresolved restoration edges fail closed.

Residual limitation: historical repealed rules are excluded because Quorum has no repeal-restoration operation.

## Threat: unrelated rule falsely declared a replacement

Mitigation: supersession is not accepted blindly. Quorum checks the semantic edge between replacement and target. `UNRELATED` or `AMBIGUOUS` replacement relations block activation.

## Threat: unresolved standard consumed as authoritative

Mitigation: consumers can call `is_consistent` or `is_consistent_for`, then inspect `standard_status` and `get_standard_relations`. `RESOLVED_CONFLICTS` is explicitly distinct from `COHERENT`; `UNRESOLVED` and `AMBIGUOUS` remain fail-closed states.

## Threat: model-generated metadata controls authority

Consequence: a reason string, overlap description, or prose claim such as “priority 1000” changes precedence.

Mitigation: metadata is explanatory only. Authority uses bounded stored priority and supersession fields; relation kind, lifecycle, and resolution are bounded protocol facts. Conflict subtype is retained for human-readable context but does not affect standard admission, precedence, lifecycle, or hashing.

Residual limitation: explanatory metadata can still mislead human readers if they ignore the bounded fields.

## Threat: state explosion / denial of service

Pairwise comparison is bounded by `MAX_RULES_PER_BOOK = 24`, for at most 276 unique edges and at most 23 comparisons for the 24th proposal. The owner controls proposals, preventing arbitrary third-party graph spam.

## Threat: hidden mutation through priority

Priority changes are allowed only while a rule is blocked. Once active, priority is immutable. A different authority level must be represented as a new node or explicit governance transition.

## Threat: supersession cycle

Consequence: lineage becomes cyclic and restoration precedence becomes incoherent.

Mitigation: a supersession target must be active, while a superseded node is not eligible as a new target. New amendments create forward-only lineage and cannot mutate existing edges.

Residual limitation: this safety relies on the lifecycle invariant remaining intact if future methods are added.

## Threat: event/runtime failure

Consequence: a non-authoritative notification could make an otherwise valid graph write fail.

Mitigation: relation storage is authoritative and relation event emission is intentionally absent after StudioNet rejected that event path. State reads and proof artifacts use persisted storage and receipts.

## Threat: stale relation after semantic mutation

There is no semantic mutation path. Relation edges store both endpoint semantic hashes. New semantics require a new node and new edges.

## Non-goals

Quorum does not decide whether a real-world action complied with a rule, move funds, execute governance proposals, infer external legal authority, prove submitted text is legally authoritative, or replace legal review. Those concerns belong to consuming applications or other primitives.

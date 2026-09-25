# Sanitized live proof

These JSON files are sanitized extracts of observed GenLayer CLI receipts and
state reads. Files named `raw-*` contain raw public RPC responses; files named
`*-summary` contain accurately labeled sanitized CLI summaries.

They intentionally omit validator private keys, credentials, and machine-local
configuration. The authoritative on-chain identifiers are the transaction
hashes, contract address, rulebook/rule/relation IDs, and final state fields.

`official-deployment.json` is the current official deployment of this
repository's source: `0x367094ed37C0b0C3fC33F378cFCa0b874f41F473` on StudioNet,
deploy tx `0xf9ae9480...f6ab01c2`, deployed source verified byte-identical to
`contracts/quorum.py` (sha256 `74b0ce915ff51fe7cfc685f1804caa33317109d178296ceac61cf8c001039f53`).

The `final-*` files are lifecycle evidence for commit
`bd6682d81afa7063d6b595dcdab04d220aed8bbb` at the previous hardened deployment
`0x67a027446838296FcB3022B376c8ff3873a4566C`, which predates the Quorum rename
and therefore does not match the current source.
The older lifecycle JSON files are retained as historical evidence from the
superseded deployment and are marked accordingly.

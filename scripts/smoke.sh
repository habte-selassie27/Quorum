#!/usr/bin/env bash
set -euo pipefail

QUORUM_CONTRACT="${QUORUM_CONTRACT:-0x367094ed37C0b0C3fC33F378cFCa0b874f41F473}"
BOOK_ID="${BOOK_ID:-1}"
RULE_A_ID="${RULE_A_ID:-${RULE_ID:-1}}"
RULE_B_ID="${RULE_B_ID:-2}"
BLOCKED_RULE_ID="${BLOCKED_RULE_ID:-3}"
AMENDMENT_RULE_ID="${AMENDMENT_RULE_ID:-4}"
RELATION_ID="${RELATION_ID:-}"
RETRIES="${RETRIES:-60}"
INTERVAL="${INTERVAL:-3000}"
SMOKE_ACCOUNT="${SMOKE_ACCOUNT:-rabby}"
MODE="${1:-read}"

RULE_A="A treasury withdrawal must not execute when fewer than three approvals are present."
RULE_B="Withdrawals above 10000 USD require three approvals before execution."
RULE_C="During an active exploit the security council may execute a withdrawal without three approvals."
RULE_AMENDMENT="A treasury withdrawal must not execute when fewer than four approvals are present."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
umask 077

WRITE_COUNT=0
READS_PASSED=0
READS_FAILED=0
LAST_TX_HASH=""
LAST_RESULT=""

usage() {
  printf '%s\n' \
    "Usage:" \
    "  scripts/smoke.sh                 read-only: all 11 view methods" \
    "  scripts/smoke.sh --write         all 6 write methods, then all views" \
    "  scripts/smoke.sh --help          show this help" \
    "" \
    "Environment:" \
    "  QUORUM_CONTRACT  deployed contract address" \
    "  RETRIES          receipt polling attempts (default: 60)" \
    "  INTERVAL         receipt polling interval in milliseconds (default: 3000)" \
    "  SMOKE_ACCOUNT    active unlocked account name (default: rabby)" \
    "  RELATION_ID      relation ID for get_relation; discovered when omitted" \
    "" \
    "Write mode creates a new rulebook and spends network fees. Configure and unlock" \
    "the Rabby account before running it; never put a private key in this script."
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v genlayer >/dev/null 2>&1 || fail "genlayer is required"
}

require_id() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "$name must be a non-negative integer, got: $value"
}

extract_tx_hash() {
  awk '
    /Write Transaction Hash:/ {
      if (match($0, /0x[0-9a-fA-F]{64}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
      if (getline > 0 && match($0, /0x[0-9a-fA-F]{64}/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  ' "$1"
}

extract_return() {
  awk '
    /result: \{ status: ['"'"']return['"'"']/ {
      if (match($0, /readable: ['"'"'][^'"'"']*['"'"']/)) {
        print substr($0, RSTART + 11, RLENGTH - 12)
        exit
      }
    }
  ' "$1"
}

wait_finalized() {
  local tx_hash="$1"
  local receipt_file="$2"

  if ! genlayer receipt "$tx_hash" --status FINALIZED --retries "$RETRIES" --interval "$INTERVAL" >"$receipt_file" 2>&1; then
    printf 'finalization failed for %s\n' "$tx_hash" >&2
    return 1
  fi
  if ! grep -q "status_name: 'FINALIZED'" "$receipt_file"; then
    printf 'transaction did not finalize: %s\n' "$tx_hash" >&2
    return 1
  fi
  if ! grep -q "execution_result: 'SUCCESS'" "$receipt_file"; then
    printf 'transaction execution was not successful: %s\n' "$tx_hash" >&2
    return 1
  fi
}

write_and_wait() {
  local method="$1"
  shift
  local write_file="$TMP_DIR/write-$WRITE_COUNT.log"
  local receipt_file="$TMP_DIR/receipt-$WRITE_COUNT.log"
  local tx_hash

  WRITE_COUNT=$((WRITE_COUNT + 1))
  printf 'write: %s\n' "$method"
  if ! genlayer write "$QUORUM_CONTRACT" "$method" "$@" >"$write_file" 2>&1; then
    printf 'write failed: %s\n' "$method" >&2
    awk 'NR <= 20 { print }' "$write_file" >&2
    return 1
  fi

  tx_hash="$(extract_tx_hash "$write_file")"
  [[ "$tx_hash" =~ ^0x[0-9a-fA-F]{64}$ ]] || {
    printf 'could not determine transaction hash for %s\n' "$method" >&2
    return 1
  }
  printf '  transaction: %s\n' "$tx_hash"
  wait_finalized "$tx_hash" "$receipt_file"

  LAST_TX_HASH="$tx_hash"
  LAST_RESULT="$(extract_return "$receipt_file")"
  if [[ -n "$LAST_RESULT" ]]; then
    printf '  return: %s\n' "$LAST_RESULT"
  fi
}

require_returned_id() {
  local method="$1"
  [[ "$LAST_RESULT" =~ ^[0-9]+$ ]] || fail "$method did not return a usable numeric ID"
}

call_method() {
  local method="$1"
  shift
  genlayer call "$QUORUM_CONTRACT" "$method" "$@"
}

std_hash() {
  local output
  if ! output="$(call_method current_standard_hash --args "$BOOK_ID" 2>&1)"; then
    return 1
  fi
  awk '/^Result:/ { getline; gsub(/\r/, ""); print; exit }' <<< "$output"
}

discover_relation_id() {
  local output
  if ! output="$(call_method get_standard_relations --args "$BOOK_ID" 2>&1)"; then
    return 1
  fi
  awk '
    /relation_id:[[:space:]]*[0-9]+/ {
      if (match($0, /[0-9]+/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  ' <<< "$output"
}

run_read() {
  local method="$1"
  shift
  printf 'read: %s\n' "$method"
  if call_method "$method" "$@"; then
    READS_PASSED=$((READS_PASSED + 1))
  else
    printf '  read failed: %s\n' "$method" >&2
    READS_FAILED=$((READS_FAILED + 1))
  fi
}

run_write_lifecycle() {
  write_and_wait create_rulebook \
    --args "Treasury Constitution" \
    "Rules governing treasury withdrawals, emergency authority, approvals, and execution constraints for a protocol treasury." \
    true
  BOOK_ID="$LAST_RESULT"
  require_returned_id create_rulebook
  require_id BOOK_ID "$BOOK_ID"
  printf '  rulebook: %s\n' "$BOOK_ID"

  write_and_wait propose_rule --args "$BOOK_ID" "$RULE_A" 100 0
  RULE_A_ID="$LAST_RESULT"
  require_returned_id propose_rule
  require_id RULE_A_ID "$RULE_A_ID"

  write_and_wait propose_rule --args "$BOOK_ID" "$RULE_B" 100 0
  RULE_B_ID="$LAST_RESULT"
  require_returned_id propose_rule
  require_id RULE_B_ID "$RULE_B_ID"

  write_and_wait propose_rule --args "$BOOK_ID" "$RULE_C" 100 0
  BLOCKED_RULE_ID="$LAST_RESULT"
  require_returned_id propose_rule
  require_id BLOCKED_RULE_ID "$BLOCKED_RULE_ID"

  write_and_wait set_blocked_rule_priority --args "$BLOCKED_RULE_ID" 200
  write_and_wait activate_blocked_rule --args "$BLOCKED_RULE_ID"

  write_and_wait propose_rule --args "$BOOK_ID" "$RULE_AMENDMENT" 100 "$RULE_A_ID"
  AMENDMENT_RULE_ID="$LAST_RESULT"
  require_returned_id propose_rule
  require_id AMENDMENT_RULE_ID "$AMENDMENT_RULE_ID"

  write_and_wait repeal_rule --args "$AMENDMENT_RULE_ID"
  write_and_wait restore_superseded_rule --args "$RULE_A_ID"
}

run_reads() {
  local hash

  if [[ -z "$RELATION_ID" ]]; then
    RELATION_ID="$(discover_relation_id || true)"
  fi
  require_id RELATION_ID "$RELATION_ID"
  require_id BOOK_ID "$BOOK_ID"
  require_id RULE_A_ID "$RULE_A_ID"
  require_id BLOCKED_RULE_ID "$BLOCKED_RULE_ID"

  run_read get_rulebook --args "$BOOK_ID"
  run_read get_rule --args "$RULE_A_ID"
  run_read get_relation --args "$RELATION_ID"
  run_read relation_between --args "$RULE_A_ID" "$BLOCKED_RULE_ID"
  run_read get_standard --args "$BOOK_ID"
  run_read get_standard_relations --args "$BOOK_ID"
  run_read standard_status --args "$BOOK_ID"
  run_read blocking_reason --args "$BLOCKED_RULE_ID"
  run_read is_consistent --args "$BOOK_ID"
  run_read current_standard_hash --args "$BOOK_ID"

  hash="$(std_hash || true)"
  if [[ -n "$hash" ]]; then
    run_read is_consistent_for --args "$BOOK_ID" "$hash"
  else
    printf 'read failed: is_consistent_for (no standard hash)\n' >&2
    READS_FAILED=$((READS_FAILED + 1))
  fi

  printf '\nreads passed: %d, failed: %d\n' "$READS_PASSED" "$READS_FAILED"
  [[ "$READS_FAILED" -eq 0 ]] || return 1
}

case "$MODE" in
  --help|-h)
    usage
    exit 0
    ;;
  read|--read)
    require_command
    require_id BOOK_ID "$BOOK_ID"
    require_id RULE_A_ID "$RULE_A_ID"
    require_id BLOCKED_RULE_ID "$BLOCKED_RULE_ID"
    printf 'target: %s\n' "$QUORUM_CONTRACT"
    run_reads
    ;;
  --write)
    require_command
    require_id RETRIES "$RETRIES"
    require_id INTERVAL "$INTERVAL"
    [[ "$QUORUM_CONTRACT" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "QUORUM_CONTRACT is not a valid address"
    network_output="$(genlayer config get network 2>&1)" || fail "could not read the GenLayer network"
    network="$(awk -F= '/^network=/{print $2; exit}' <<< "$network_output")"
    [[ "$network" == "studionet" ]] || fail "write mode requires network=studionet (found: ${network:-unknown})"
    account_output="$(genlayer account show 2>&1)" || fail "could not read the active GenLayer account"
    [[ "$account_output" == *"name: '$SMOKE_ACCOUNT'"* ]] || fail "active account must be $SMOKE_ACCOUNT"
    [[ "$account_output" == *"status: 'unlocked'"* ]] || fail "$SMOKE_ACCOUNT must be unlocked"
    [[ "$account_output" == *"active: true"* ]] || fail "$SMOKE_ACCOUNT must be the active account"
    printf 'target: %s\n' "$QUORUM_CONTRACT"
    printf 'wallet: %s is active and unlocked; writes will spend network fees\n' "$SMOKE_ACCOUNT"
    run_write_lifecycle
    run_reads
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_ID="${SIMULATOR_ID:-27DD0203-B1F5-4429-9E0C-A82D2905C336}"
BUNDLE_ID="${BUNDLE_ID:-com.kair.kair}"
OUTPUT_DIR="${1:-$ROOT/Contracts/runtime-replay-artifacts}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
WAIT_SECONDS="${WAIT_SECONDS:-60}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"

echo "Booting simulator ${SIMULATOR_ID}..."
xcrun simctl boot "${SIMULATOR_ID}" >/dev/null 2>&1 || true

echo "Stopping existing ${BUNDLE_ID} instance if needed..."
xcrun simctl terminate "${SIMULATOR_ID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true

START_TIME="$("${PYTHON_BIN}" - <<'PY'
import time
print(time.time())
PY
)"

echo "Launching ${BUNDLE_ID} on simulator ${SIMULATOR_ID} with runtime scenario matrix..."
SIMCTL_CHILD_KAIR_RUNTIME_SCENARIO_MATRIX=1 \
SIMCTL_CHILD_KAIR_RUNTIME_RESET_REPLAY=1 \
xcrun simctl launch "${SIMULATOR_ID}" "${BUNDLE_ID}" >/dev/null

DATA_CONTAINER="$(xcrun simctl get_app_container "${SIMULATOR_ID}" "${BUNDLE_ID}" data)"
ARTIFACT_DIR="${DATA_CONTAINER}/Library/Application Support/kAir/ReplayArtifacts"
SESSION_DIR="${DATA_CONTAINER}/Library/Application Support/kAir/ReplaySessions"
STATUS_FILE="${ARTIFACT_DIR}/runtime_scenario_matrix_status.json"
REPORT_FILE="${ARTIFACT_DIR}/runtime_scenario_matrix_report.json"

echo "Waiting for runtime scenario matrix to complete..."
"${PYTHON_BIN}" - "$STATUS_FILE" "$WAIT_SECONDS" "$POLL_INTERVAL" "$START_TIME" <<'PY'
import json
import sys
import time
from pathlib import Path

status_path = Path(sys.argv[1])
deadline = time.time() + int(sys.argv[2])
poll = float(sys.argv[3])
started_after = float(sys.argv[4])

while time.time() < deadline:
    if status_path.exists():
        if status_path.stat().st_mtime < started_after:
            time.sleep(poll)
            continue
        status = json.loads(status_path.read_text(encoding="utf-8"))
        phase = status.get("phase")
        if phase == "completed":
            print(json.dumps(status, ensure_ascii=False))
            raise SystemExit(0)
        if phase == "failed":
            print(json.dumps(status, ensure_ascii=False), file=sys.stderr)
            raise SystemExit(1)
    time.sleep(poll)

print(f"Timed out waiting for {status_path}", file=sys.stderr)
raise SystemExit(1)
PY

if [[ ! -d "${ARTIFACT_DIR}" ]]; then
  echo "Runtime replay artifact directory not found: ${ARTIFACT_DIR}" >&2
  exit 1
fi
if [[ ! -d "${SESSION_DIR}" ]]; then
  echo "Runtime replay session directory not found: ${SESSION_DIR}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
cp "${ARTIFACT_DIR}/matching_kernel_baseline.json" "${OUTPUT_DIR}/"
cp "${ARTIFACT_DIR}/runtime_replay_corpus.json" "${OUTPUT_DIR}/"
cp "${ARTIFACT_DIR}/runtime_residual_ledger.json" "${OUTPUT_DIR}/"
cp "${ARTIFACT_DIR}/runtime_scenario_matrix_report.json" "${OUTPUT_DIR}/"
cp "${ARTIFACT_DIR}/runtime_scenario_matrix_status.json" "${OUTPUT_DIR}/"
rm -rf "${OUTPUT_DIR}/ReplaySessions"
mkdir -p "${OUTPUT_DIR}/ReplaySessions"
cp "${SESSION_DIR}"/replay_session_*.json "${OUTPUT_DIR}/ReplaySessions/"

SESSION_COUNT=$(find "${OUTPUT_DIR}/ReplaySessions" -type f -name 'replay_session_*.json' | wc -l | tr -d ' ')
echo "Exported runtime replay artifacts to ${OUTPUT_DIR}"
echo "Persisted replay sessions: ${SESSION_COUNT}"
echo "Scenario report: ${OUTPUT_DIR}/runtime_scenario_matrix_report.json"

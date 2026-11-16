#!/bin/sh
# Run tests/run.do with a local Stata, a throwaway config folder, and the mock
# Cloud server, as scripts/jhpce-test.sh does on the cluster.
# Usage: scripts/local-test.sh [path to the Stata binary]
# Prints the summary. The full log stays at run.log.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
stata=${1:-$(ls /Applications/Stata*/Stata*.app/Contents/MacOS/stata-* 2>/dev/null | head -n 1)}
[ -n "$stata" ] || { echo "No Stata found. Pass the path to the Stata binary." >&2; exit 1; }
config=$(mktemp -d)
export FW_CONFIG_HOME="$config" FW_TEST_MOCK_PORT=${FW_TEST_MOCK_PORT:-18765}
export FW_TEST_MOCK_LOG="$config/requests.jsonl"
cd "$here"
python3 tests/fixtures/mock_cloud.py "$FW_TEST_MOCK_PORT" "$FW_TEST_MOCK_LOG" 2>/dev/null & mock=$!
trap 'kill $mock 2>/dev/null; rm -rf "$config"' EXIT
sleep 1
rm -f run.log
"$stata" -b do tests/run.do
echo "token-leaks: $(grep -c fw_test_user_token run.log || true)"
grep -E "^(PASS|FAIL|SKIP)|passed:|failed:|skipped:" run.log | grep -v "^PASS"

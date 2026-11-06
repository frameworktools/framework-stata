#!/bin/sh
# Copy this checkout to JHPCE and run tests/run.do on a compute node.
# Usage: scripts/jhpce-test.sh [shell commands to run before Stata]
# Prints the end of run.log. The full log stays at ~/$FW_JHPCE_DIR/run.log.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
remote=${FW_JHPCE_DIR:-fw-dev/framework-stata}
pre=${1:-export PATH=\$HOME/bin:\$PATH FW_TEST_PYTHON=\$(readlink -f \$HOME/.local/share/uv/python/cpython-3.11-linux-x86_64-gnu/bin/python3.11) FW_TEST_PYTHONPATH=\$HOME/fw-dev/venv/lib/python3.11/site-packages}
ssh -o BatchMode=yes jhpce "mkdir -p $remote"
rsync -a --delete --exclude .git --exclude run.log "$here/" "jhpce:$remote/"
# The compute node prints the summary: the login node's NFS cache can lag.
ssh -o BatchMode=yes jhpce "cd $remote && rm -f run.log; srun --exclude=compute-119 --mem=4G --time=00:20:00 bash -lc 'module load stata/17 >/dev/null 2>&1; export FW_CONFIG_HOME=\$(mktemp -d); $pre; export FW_TEST_MOCK_PORT=18765 FW_TEST_MOCK_LOG=\$FW_CONFIG_HOME/requests.jsonl; python3 tests/fixtures/mock_cloud.py \$FW_TEST_MOCK_PORT \$FW_TEST_MOCK_LOG & mock=\$!; sleep 1; stata -b do tests/run.do; kill \$mock; echo token-leaks: \$(grep -c fw_test_user_token run.log); grep -E \"^(PASS|FAIL|SKIP)|passed:|failed:|skipped:|TESTS|Framework for Stata tests|token-leaks\" run.log'"

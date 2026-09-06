#!/bin/bash

# Script to run the AudioControl integration test suite
# Usage:
#   ./run-test.sh                    - Run all integration tests
#   ./run-test.sh test_name          - Run a specific test by name
#   ./run-test.sh test1 test2 test3  - Run multiple specific tests by name
#
# Examples:
#   ./run-test.sh test_server_startup
#   ./run-test.sh test_server_startup test_players_endpoint

set -euo pipefail

# Ensure we're in the project root directory
cd "$(dirname "$0")"

# Pre-test cleanup
echo "[CLEANUP] Cleaning up any existing audiocontrol processes..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    taskkill //F //IM audiocontrol.exe 2>/dev/null || true
else
    # Linux/Unix
    pkill -KILL -f audiocontrol 2>/dev/null || true
fi

echo "[WAIT] Waiting for process cleanup..."
sleep 1

# Determine pytest invocation
PYTEST_ARGS=()
if [ $# -eq 0 ]; then
    echo "[TEST] Running all AudioControl integration tests"
    echo "================================================="
else
    echo "[TEST] Running selected AudioControl integration tests: $*"
    echo "================================================================"
    for test_name in "$@"; do
        PYTEST_ARGS+=("-k" "$test_name")
    done
fi

# Build the binary first
echo "[BUILD] Building AudioControl binary..."
cargo build

# Run Python integration tests
echo "[TEST] Running integration tests via pytest..."
cd integration_test
if ! python3 -m pytest -v --tb=short "${PYTEST_ARGS[@]}"; then
    TEST_EXIT_CODE=1
else
    TEST_EXIT_CODE=0
fi

cd ..

# Post-test cleanup
echo ""
echo "[CLEANUP] Post-test cleanup..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    taskkill //F //IM audiocontrol.exe 2>/dev/null || true
else
    pkill -KILL -f audiocontrol 2>/dev/null || true
fi

# Clean up test artifacts
rm -f test_config_*.json
rm -rf test_cache_*
rm -f /tmp/test_librespot_event_* /tmp/test_raat_metadata_* /tmp/test_raat_control_*

echo "[CLEANUP] Cleanup complete"
echo ""

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "[PASS] Integration tests passed!"
else
    echo "[FAIL] Some integration tests failed (exit code: $TEST_EXIT_CODE)"
fi

echo "=============================================="

exit $TEST_EXIT_CODE

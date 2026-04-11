#!/usr/bin/env bash
# =============================================================================
# run_gpu_tests.sh — Full GPU pipeline test: .mlir -> MSL -> .air -> .metallib
# =============================================================================
#
# Tests the complete Enigma pipeline on macOS with Metal:
#   Phase 1: Compile all GPU test kernels through the full pipeline
#   Phase 2: Run vector_add end-to-end on the actual GPU via enigma-runner
#
# Usage:
#   ./test/run_gpu_tests.sh
#
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
TRANSLATE="$BUILD/tools/enigma-translate/enigma-translate"
RUNNER="$BUILD/tools/enigma-runner/enigma-runner"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
ERRORS=""

run_test() {
    local name="$1"; local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        printf "  ${GREEN}PASS${NC}  %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %s\n" "$name"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - $name"
    fi
}

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Prerequisites ===${NC}\n"
if [ ! -x "$TRANSLATE" ]; then
    echo "  enigma-translate not found. Run: ninja -C build"; exit 1
fi
if ! command -v xcrun &> /dev/null; then
    echo "  xcrun not found. Install Xcode Command Line Tools."; exit 1
fi
if ! xcrun --find metal &> /dev/null 2>&1; then
    echo "  Metal compiler not found. Install Xcode."; exit 1
fi
printf "  ${GREEN}OK${NC}  All tools available\n"

# ---------------------------------------------------------------------------
# Phase 1: Full pipeline — .mlir -> .metal -> .air -> .metallib
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Phase 1: Full Pipeline (mlir -> metal -> air -> metallib) ===${NC}\n"

for f in "$ROOT"/test/gpu/*.mlir; do
    base=$(basename "$f" .mlir)
    msl="$TMPDIR/${base}.metal"
    air="$TMPDIR/${base}.air"
    lib="$TMPDIR/${base}.metallib"

    # Emit MSL
    if ! "$TRANSLATE" --enigma-to-msl "$f" > "$msl" 2>/dev/null; then
        printf "  ${RED}FAIL${NC}  %s (MSL emission)\n" "$base"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - $base (emission)"
        continue
    fi

    # Compile .metal -> .air
    if ! xcrun metal -c "$msl" -o "$air" 2>/dev/null; then
        printf "  ${RED}FAIL${NC}  %s (xcrun metal)\n" "$base"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - $base (metal compile)"
        # Show the error for debugging
        xcrun metal -c "$msl" -o "$air" 2>&1 | head -3 | sed 's/^/         /'
        continue
    fi

    # Link .air -> .metallib
    if ! xcrun metallib "$air" -o "$lib" 2>/dev/null; then
        printf "  ${RED}FAIL${NC}  %s (xcrun metallib)\n" "$base"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - $base (metallib link)"
        continue
    fi

    printf "  ${GREEN}PASS${NC}  %s\n" "$base"
    PASS=$((PASS + 1))
done

# ---------------------------------------------------------------------------
# Phase 2: GPU execution — run vector_add on actual hardware
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Phase 2: GPU Execution (Metal hardware) ===${NC}\n"

if [ ! -x "$RUNNER" ]; then
    printf "  ${YELLOW}SKIP${NC}  enigma-runner not built\n"
    SKIP=$((SKIP + 1))
else
    # vector_add — the canonical end-to-end test
    lib="$TMPDIR/test_vector_add.metallib"
    if [ -f "$lib" ]; then
        printf "  Running vector_add on GPU...\n"
        OUTPUT=$("$RUNNER" "$lib" vector_add 2>&1)
        echo "$OUTPUT" | sed 's/^/    /'
        if echo "$OUTPUT" | grep -q "PASSED"; then
            printf "  ${GREEN}PASS${NC}  gpu/vector_add (end-to-end on Metal)\n"
            PASS=$((PASS + 1))
        else
            printf "  ${RED}FAIL${NC}  gpu/vector_add (GPU execution)\n"
            FAIL=$((FAIL + 1))
            ERRORS="$ERRORS\n  - gpu/vector_add (execution)"
        fi
    else
        printf "  ${YELLOW}SKIP${NC}  vector_add.metallib not available\n"
        SKIP=$((SKIP + 1))
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Summary ===${NC}\n"
TOTAL=$((PASS + FAIL + SKIP))
printf "  Total: %d  |  ${GREEN}Pass: %d${NC}  |  ${RED}Fail: %d${NC}  |  ${YELLOW}Skip: %d${NC}\n" \
    "$TOTAL" "$PASS" "$FAIL" "$SKIP"

if [ $FAIL -gt 0 ]; then
    printf "\n${RED}Failed tests:${NC}$ERRORS\n"
    exit 1
else
    printf "\n${GREEN}All GPU tests passed!${NC}\n"
    exit 0
fi

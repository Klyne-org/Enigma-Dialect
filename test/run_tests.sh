#!/usr/bin/env bash
# =============================================================================
# run_tests.sh — Comprehensive test runner for Enigma Dialect
# =============================================================================
#
# Usage:
#   ./test/run_tests.sh              # Run all tests
#   ./test/run_tests.sh --lit-only   # Only run lit FileCheck tests
#   ./test/run_tests.sh --emit-only  # Only run MSL emission + xcrun validation
#   ./test/run_tests.sh --gpu        # Also run GPU tests (requires Metal GPU)
#
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
TRANSLATE="$BUILD/tools/enigma-translate/enigma-translate"
OPT="$BUILD/tools/enigma-opt/enigma-opt"
RUNNER="$BUILD/tools/enigma-runner/enigma-runner"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
SKIP=0
ERRORS=""

MODE="${1:-all}"

# ---------------------------------------------------------------------------
# Helper: run a single test and track results
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        printf "  ${GREEN}PASS${NC}  %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %s\n" "$name"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - $name"
    fi
}

skip_test() {
    local name="$1"
    local reason="$2"
    printf "  ${YELLOW}SKIP${NC}  %s (%s)\n" "$name" "$reason"
    SKIP=$((SKIP + 1))
}

# ---------------------------------------------------------------------------
# Phase 0: Build check
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Phase 0: Build Check ===${NC}\n"
if [ ! -x "$TRANSLATE" ]; then
    echo "  enigma-translate not found at $TRANSLATE"
    echo "  Run: ninja -C build"
    exit 1
fi
if [ ! -x "$OPT" ]; then
    echo "  enigma-opt not found at $OPT"
    echo "  Run: ninja -C build"
    exit 1
fi
printf "  ${GREEN}OK${NC}  Build artifacts found\n"

# ---------------------------------------------------------------------------
# Phase 1: Dialect roundtrip tests (parse -> print -> parse)
# ---------------------------------------------------------------------------
if [ "$MODE" != "--emit-only" ]; then
    echo ""
    printf "${CYAN}=== Phase 1: Dialect Roundtrip ===${NC}\n"
    for f in "$ROOT"/test/Dialect/Enigma/*.mlir; do
        name="roundtrip/$(basename "$f")"
        run_test "$name" "'$OPT' '$f' | '$OPT'"
    done
fi

# ---------------------------------------------------------------------------
# Phase 2: MSL Emission tests (Enigma IR -> MSL text)
# ---------------------------------------------------------------------------
if [ "$MODE" != "--lit-only" ]; then
    echo ""
    printf "${CYAN}=== Phase 2: MSL Emission ===${NC}\n"
    for f in "$ROOT"/test/Target/MSL/*.mlir; do
        name="emit/$(basename "$f")"
        run_test "$name" "'$TRANSLATE' --enigma-to-msl '$f'"
    done
fi

# ---------------------------------------------------------------------------
# Phase 3: FileCheck validation (lit tests without needing lit installed)
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Phase 3: FileCheck Validation ===${NC}\n"
FILECHECK=""
# Try to find FileCheck
for candidate in \
    "$(command -v FileCheck 2>/dev/null || true)" \
    "/opt/homebrew/Cellar/llvm/22.1.2/bin/FileCheck" \
    "/opt/homebrew/opt/llvm/bin/FileCheck" \
    "/usr/local/opt/llvm/bin/FileCheck"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        FILECHECK="$candidate"
        break
    fi
done

if [ -z "$FILECHECK" ]; then
    echo "  FileCheck not found — skipping FileCheck validation"
    echo "  Install LLVM or set PATH to include FileCheck"
    SKIP=$((SKIP + 1))
else
    for f in "$ROOT"/test/Target/MSL/*.mlir; do
        name="check/$(basename "$f")"
        run_test "$name" "'$TRANSLATE' --enigma-to-msl '$f' | '$FILECHECK' '$f'"
    done

    for f in "$ROOT"/test/Dialect/Enigma/*.mlir; do
        name="check/$(basename "$f")"
        run_test "$name" "'$OPT' '$f' | '$OPT' | '$FILECHECK' '$f'"
    done
fi

# ---------------------------------------------------------------------------
# Phase 4: MSL compilation validation (xcrun metal)
# ---------------------------------------------------------------------------
echo ""
printf "${CYAN}=== Phase 4: MSL Compilation (xcrun metal) ===${NC}\n"
if command -v xcrun &> /dev/null && xcrun --find metal &> /dev/null 2>&1; then
    TMPDIR_MSL=$(mktemp -d)
    trap "rm -rf $TMPDIR_MSL" EXIT

    # Tests that use texture ops modeled as memref cannot compile with xcrun
    # until the dialect has proper !enigma.texture types. Skip them.
    XCRUN_SKIP_LIST="texture_ops texture_sample"

    for f in "$ROOT"/test/Target/MSL/*.mlir; do
        base="$(basename "$f" .mlir)"
        name="xcrun/$base.mlir"
        msl_file="$TMPDIR_MSL/${base}.metal"
        air_file="$TMPDIR_MSL/${base}.air"

        # Skip known-incompatible tests
        if echo "$XCRUN_SKIP_LIST" | grep -qw "$base"; then
            skip_test "$name" "texture type not yet supported in MSL"
            continue
        fi

        # Emit MSL
        if ! "$TRANSLATE" --enigma-to-msl "$f" > "$msl_file" 2>/dev/null; then
            skip_test "$name" "emission failed"
            continue
        fi

        # Compile with xcrun metal
        run_test "$name" "xcrun metal -c '$msl_file' -o '$air_file' 2>&1"
    done
else
    echo "  xcrun metal not available — skipping MSL compilation"
    echo "  (This is expected on non-macOS or without Xcode)"
    SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# Phase 5: GPU runtime tests (optional, requires Metal GPU)
# ---------------------------------------------------------------------------
if [ "$MODE" = "--gpu" ]; then
    echo ""
    printf "${CYAN}=== Phase 5: GPU Runtime Tests ===${NC}\n"
    if bash "$ROOT/test/gpu/run-gpu-tests.sh"; then
        printf "  ${GREEN}PASS${NC}  gpu suite\n"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  gpu suite\n"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  - gpu suite"
    fi
elif [ "$MODE" = "all" ]; then
    echo ""
    printf "${CYAN}=== Phase 5: GPU Runtime Tests ===${NC}\n"
    echo "  Skipped (pass --gpu to enable, requires Metal GPU)"
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
    printf "\n${GREEN}All tests passed!${NC}\n"
    exit 0
fi

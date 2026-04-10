#!/bin/bash
# =============================================================================
# run-gpu-tests.sh — Full Enigma pipeline: MLIR → MSL → metallib → GPU → verify
#
# Usage:
#   cd Enigma-Dialect
#   bash test/gpu/run-gpu-tests.sh
#
# What it does:
#   1. Translates each test .mlir to MSL text
#   2. Compiles MSL with xcrun metal → .air
#   3. Links .air files into one .metallib
#   4. Builds the GPU test runner
#   5. Runs every kernel on the actual GPU and verifies outputs
# =============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/build"
TRANSLATE="$BUILD/tools/enigma-translate/enigma-translate"
GPU_DIR="$ROOT/test/gpu"
TMP="$BUILD/gpu-test-tmp"

rm -rf "$TMP"
mkdir -p "$TMP"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          Enigma Dialect — Full GPU Test Suite             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ─── Step 0: Check prerequisites ────────────────────────────────
echo "▶ Step 0: Checking prerequisites..."
if [ ! -f "$TRANSLATE" ]; then
  echo "  ERROR: enigma-translate not found at $TRANSLATE"
  echo "  Run: ninja -C $BUILD"
  exit 1
fi
if ! command -v xcrun &>/dev/null; then
  echo "  ERROR: xcrun not found (need Xcode Command Line Tools)"
  exit 1
fi
echo "  OK"
echo ""

# ─── Step 1: MLIR → MSL ─────────────────────────────────────────
echo "▶ Step 1: Translating MLIR → MSL..."
MLIR_FILES=(
  test_vector_add.mlir
  test_scale_constant.mlir
  test_math_sqrt.mlir
  test_threadgroup_copy.mlir
  test_atomic_histogram.mlir
  test_saxpy.mlir
  test_negate.mlir
  test_clamp.mlir
  test_select.mlir
  test_iclamp.mlir
  test_for_loop.mlir
  test_isnan_check.mlir
  test_imin_imax.mlir
)

for f in "${MLIR_FILES[@]}"; do
  src="$GPU_DIR/$f"
  msl="$TMP/${f%.mlir}.metal"
  if [ ! -f "$src" ]; then
    echo "  SKIP: $f (not found)"
    continue
  fi
  "$TRANSLATE" --enigma-to-msl "$src" > "$msl" 2>&1
  echo "  $f → $(basename $msl)"
done
echo ""

# ─── Step 2: MSL → .air (compile each) ──────────────────────────
echo "▶ Step 2: Compiling MSL → AIR with xcrun metal..."
FAIL=0
for metal in "$TMP"/*.metal; do
  air="${metal%.metal}.air"
  name="$(basename "$metal")"
  if xcrun metal -c "$metal" -o "$air" 2>"$TMP/metal_err.txt"; then
    echo "  $name → $(basename $air)  ✓"
  else
    echo "  $name  ✗ COMPILE ERROR:"
    cat "$TMP/metal_err.txt" | head -10 | sed 's/^/    /'
    FAIL=1
  fi
done
if [ $FAIL -ne 0 ]; then
  echo ""
  echo "Some MSL files failed to compile. Fix errors above before continuing."
  exit 1
fi
echo ""

# ─── Step 3: Link .air → .metallib ──────────────────────────────
echo "▶ Step 3: Linking AIR → metallib..."
AIR_FILES=("$TMP"/*.air)
xcrun metallib "${AIR_FILES[@]}" -o "$TMP/test_kernels.metallib"
echo "  → $TMP/test_kernels.metallib  ($(wc -c < "$TMP/test_kernels.metallib" | tr -d ' ') bytes)"
echo ""

# ─── Step 4: Build GPU test runner ──────────────────────────────
echo "▶ Step 4: Building GPU test runner..."
RUNNER_SRC="$GPU_DIR/gpu-test-runner.mm"
RUNNER_BIN="$TMP/gpu-test-runner"
clang++ -std=c++17 -fobjc-arc \
  -framework Metal -framework Foundation \
  "$RUNNER_SRC" -o "$RUNNER_BIN" 2>&1
echo "  → $RUNNER_BIN"
echo ""

# ─── Step 5: Run on GPU ─────────────────────────────────────────
echo "▶ Step 5: Running kernels on GPU..."
echo ""
"$RUNNER_BIN" "$TMP/test_kernels.metallib" all
RESULT=$?
echo ""

# ─── Step 6: Show generated MSL for review ──────────────────────
echo "▶ Step 6: Generated MSL code for review:"
echo ""
for metal in "$TMP"/*.metal; do
  echo "┌──────────────────────────────────────────"
  echo "│ $(basename "$metal")"
  echo "└──────────────────────────────────────────"
  cat "$metal"
  echo ""
done

# ─── Summary ────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
if [ $RESULT -eq 0 ]; then
  echo "  ALL GPU TESTS PASSED"
else
  echo "  SOME GPU TESTS FAILED (exit code $RESULT)"
fi
echo "═══════════════════════════════════════════════════════════"
exit $RESULT

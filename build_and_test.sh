#!/usr/bin/env bash
# Build the Enigma Dialect project and run its test suite.
#
# Usage:
#   ./build_and_test.sh                 # configure (if needed), build, run all tests
#   ./build_and_test.sh --clean         # wipe build/ before configuring
#   ./build_and_test.sh --gpu           # also run GPU runtime tests
#   ./build_and_test.sh --lit-only      # only run lit FileCheck tests
#   ./build_and_test.sh --emit-only     # only run MSL emission tests
#
# Requires a prebuilt MLIR/LLVM. On macOS:
#   brew install llvm ninja cmake

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"

CLEAN=0
TEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=1 ;;
        --gpu|--lit-only|--emit-only) TEST_ARGS+=("$arg") ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# Locate MLIR/LLVM CMake packages if the user hasn't already.
if [ -z "${MLIR_DIR:-}" ] && command -v brew >/dev/null 2>&1; then
    LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || true)"
    if [ -n "$LLVM_PREFIX" ] && [ -d "$LLVM_PREFIX/lib/cmake/mlir" ]; then
        export MLIR_DIR="$LLVM_PREFIX/lib/cmake/mlir"
        export LLVM_DIR="$LLVM_PREFIX/lib/cmake/llvm"
        export PATH="$LLVM_PREFIX/bin:$PATH"
    fi
fi

if [ "$CLEAN" -eq 1 ]; then
    echo "==> Cleaning $BUILD"
    rm -rf "$BUILD"
fi

GENERATOR="Unix Makefiles"
BUILD_CMD=(make -C "$BUILD" "-j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)")
if command -v ninja >/dev/null 2>&1; then
    GENERATOR="Ninja"
    BUILD_CMD=(ninja -C "$BUILD")
fi

if [ ! -f "$BUILD/CMakeCache.txt" ]; then
    echo "==> Configuring ($GENERATOR)"
    cmake -S "$ROOT" -B "$BUILD" -G "$GENERATOR"
fi

echo "==> Building"
"${BUILD_CMD[@]}"

echo "==> Running tests"
bash "$ROOT/test/run_tests.sh" "${TEST_ARGS[@]+"${TEST_ARGS[@]}"}"

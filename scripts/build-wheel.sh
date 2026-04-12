#!/usr/bin/env bash
# Build a self-contained Enigma dialect wheel for macOS arm64, cpython-3.12.
#
# Usage:
#   source ~/.local/enigma-llvm/activate.sh
#   ./scripts/build-wheel.sh
#
# Output: dist/enigma_dialect-<ver>-cp312-cp312-macosx_*_arm64.whl
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -z "${MLIR_DIR:-}" ]]; then
  echo "error: MLIR_DIR is not set. source ~/.local/enigma-llvm/activate.sh first." >&2
  exit 1
fi

python3 -c "import build, scikit_build_core" 2>/dev/null || \
  python3 -m pip install --quiet build scikit-build-core

rm -rf dist build-wheel
# Pin to Apple clang to avoid homebrew-llvm header mismatches during
# scikit-build-core's configure step.
export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"
python3 -m build --wheel --no-isolation

WHL=$(ls dist/enigma_dialect-*.whl | head -1)
echo
echo "Built wheel: $WHL"

# --- Post-process: rewrite install names in bundled dylibs so the wheel is
# --- portable (no dependency on ~/.local/enigma-llvm paths on the user box).
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
python3 -m wheel unpack -d "$TMP" "$WHL"
UNPACKED=$(ls -d "$TMP"/enigma_dialect-*/ | head -1)
PKG_DIR="${UNPACKED}mlir/_mlir_libs"

fix_dylib_refs() {
  local f="$1"
  # Rewrite absolute homebrew zstd path to @loader_path reference.
  for dep in $(otool -L "$f" | awk 'NR>1 {print $1}'); do
    case "$dep" in
      /opt/homebrew/*libzstd*|/usr/local/*libzstd*)
        install_name_tool -change "$dep" "@loader_path/$(basename "$dep")" "$f" ;;
    esac
  done
  # libLLVM is already referenced via @rpath which is set to @loader_path
  # on the extension modules; nothing to change there.
  codesign --force --sign - "$f" 2>/dev/null || true
}

for f in "$PKG_DIR"/*.dylib "$PKG_DIR"/*.so; do
  [[ -e "$f" ]] || continue
  fix_dylib_refs "$f"
done

# Ensure the extension modules can find @rpath-referenced libLLVM/CAPI dylibs
# sitting alongside them. add_mlir_python_common_capi_library already sets the
# rpath to @loader_path, but verify for libLLVM which we added manually.
for ext in "$PKG_DIR"/_mlir*.so; do
  [[ -e "$ext" ]] || continue
  if ! otool -l "$ext" | grep -q '@loader_path'; then
    install_name_tool -add_rpath '@loader_path' "$ext" 2>/dev/null || true
  fi
done

# Repack wheel
rm "$WHL"
python3 -m wheel pack -d dist "$UNPACKED"
NEW_WHL=$(ls dist/enigma_dialect-*.whl | head -1)

echo
echo "Repacked self-contained wheel: $NEW_WHL"
echo "Install with: pip install $NEW_WHL"

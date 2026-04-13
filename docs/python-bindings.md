# Python Bindings

The Enigma dialect ships optional Python bindings so downstream projects
(notably `Enigma-DSL`) can construct MLIR IR programmatically instead of
emitting textual MSL.

---

## For users — install the prebuilt wheel (no build required)

If you just want to *use* the bindings, skip the entire "Prerequisites /
Building" section below. Grab the prebuilt wheel from the project's
GitHub releases and install it into any Python 3.12 venv on an
Apple-silicon Mac:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install https://github.com/Klyne-Research/Enigma-Dialect/releases/download/v0.1.0/enigma_dialect-0.1.0-cp312-cp312-macosx_15_0_arm64.whl
```

That's it — no LLVM, no CMake, no env vars. Verify:

```python
from mlir import ir
from mlir.dialects import enigma

with ir.Context() as ctx, ir.Location.unknown():
    enigma.register_dialect(ctx)
    print("ok")
```

**Compatibility**: macOS arm64 (Apple silicon), CPython 3.12 only. The
wheel bundles `libLLVM.dylib` and `libzstd.1.dylib` internally, so it
works on any machine in that matrix without additional setup.

Jump to [Example: building a thread-position op](#example-building-a-thread-position-op)
to see usage.

---

## For maintainers — building from source

## Prerequisites

The bindings require an LLVM/MLIR built from source with
`-DMLIR_ENABLE_BINDINGS_PYTHON=ON`. Homebrew's `llvm` formula does **not**
ship these; the pre-built artifact lives at `~/.local/enigma-llvm/`.

Activate it before building or using the bindings:

```bash
source ~/.local/enigma-llvm/activate.sh
```

That script sets `MLIR_DIR`, `LLVM_DIR`, `PATH`, and the virtualenv used to
build the bindings.

## Building

```bash
source ~/.local/enigma-llvm/activate.sh
cmake -S . -B build -G Ninja \
  -DENIGMA_ENABLE_PYTHON_BINDINGS=ON \
  -DCMAKE_BUILD_TYPE=Release
ninja -C build EnigmaPythonModules
```

Artifacts land in `build/python/python_packages/mlir_enigma/`. The
directory contents make up a standard MLIR Python package (`ir.py`,
`passmanager.py`, `dialects/`, `_mlir_libs/`), with the Enigma dialect
bundled alongside the core MLIR dialects.

A `mlir -> mlir_enigma` symlink is created in the parent so that
`import mlir` resolves to this package.

## Using the bindings

Point `PYTHONPATH` at the parent directory of the generated package, then
import as usual:

```bash
export PYTHONPATH="$(pwd)/build/python/python_packages:$PYTHONPATH"
```

```python
from mlir import ir
from mlir.dialects import enigma

with ir.Context() as ctx, ir.Location.unknown():
    enigma.register_dialect(ctx)
    module = ir.Module.create()
    # ... build ops here
```

`register_dialect(ctx, load=True)` registers *and* loads the dialect on
the context. Pass `load=False` if you only want it registered.

Every op defined in `include/enigma/Dialect/Enigma/IR/*.td` is exposed as
a Python builder class on the `enigma` module — 156 in total. Class names
follow TableGen's convention: `enigma.thread_position_in_grid` becomes
`enigma.ThreadPositionInGridOp`, `enigma.kernel` becomes `enigma.KernelOp`,
etc. See `build/python/python_packages/mlir_enigma/dialects/_enigma_ops_gen.py`
for the full list and each builder's signature.

## Example: building a thread-position op

```python
from mlir import ir
from mlir.dialects import enigma

with ir.Context() as ctx, ir.Location.unknown():
    enigma.register_dialect(ctx)
    module = ir.Module.create()

    with ir.InsertionPoint(module.body):
        i32 = ir.IntegerType.get_signless(32)
        dim_x = ir.IntegerAttr.get(i32, 0)  # Enigma_Dimension: x=0, y=1, z=2
        enigma.ThreadPositionInGridOp(dimension=dim_x)

    module.operation.verify()
    print(module)
```

Output:

```mlir
module {
  %0 = enigma.thread_position_in_grid x
}
```

## Attribute construction cheat sheet

TableGen-generated builders are strict about attribute types. Common
patterns:

| `.td` type        | Python construction                                                 |
|-------------------|---------------------------------------------------------------------|
| `I32Attr`         | `ir.IntegerAttr.get(ir.IntegerType.get_signless(32), value)`        |
| `StrAttr`         | `ir.StringAttr.get("value")`                                        |
| `I32EnumAttr`     | `ir.IntegerAttr.get(ir.IntegerType.get_signless(32), enum_value)`   |
| `F32Attr`         | `ir.FloatAttr.get(ir.F32Type.get(), value)`                         |

For region-carrying ops (`enigma.kernel`, `enigma.vertex`, `enigma.fragment`),
populate the body with `ir.InsertionPoint` the same way you would for
`func.FuncOp`.

## Using from Enigma-DSL

The DSL imports these bindings without duplicating any C++/TableGen work:

```python
# enigma_dsl/compiler/mlir_emitter.py
from mlir import ir
from mlir.dialects import func, memref, arith
from mlir.dialects import enigma   # ← this repo's bindings
```

The DSL's top-level package name (e.g. `enigma_dsl`) is independent of the
`mlir.dialects.enigma` submodule, so there is no import-time collision.

During DSL development, set `PYTHONPATH` to the build directory above.
For wheel distribution, the DSL's `scikit-build-core` config copies
`build/python/python_packages/mlir_enigma/` into the wheel alongside the
required `.dylib` files.

## Building a wheel for distribution

Produce a self-contained macOS arm64 / cp312 wheel:

```bash
source ~/.local/enigma-llvm/activate.sh
./scripts/build-wheel.sh
```

Output: `dist/enigma_dialect-<ver>-cp312-cp312-macosx_*_arm64.whl`
(~90 MB, includes bundled `libLLVM.dylib` + `libzstd.1.dylib`).

Verify the wheel by installing it into a clean venv:

```bash
python3.12 -m venv /tmp/wheel-check
source /tmp/wheel-check/bin/activate
pip install dist/enigma_dialect-*.whl
python /path/to/Enigma-Dialect/test_bindings_smoke.py
```

To share: attach the `.whl` to a GitHub release. Users install with
`pip install <release-URL>` — see the "For users" section above.

## Smoke test

A self-contained smoke test lives at `test_bindings_smoke.py` in the repo
root. Run it after any rebuild:

```bash
source ~/.local/enigma-llvm/activate.sh
export PYTHONPATH="$(pwd)/build/python/python_packages:$PYTHONPATH"
python3 test_bindings_smoke.py
```

Expected output:

```
[PASS] dialect registered + empty module verifies
[PASS] 156 op builder classes exposed
[PASS] built + verified enigma.thread_position_in_grid op
module {
  %0 = enigma.thread_position_in_grid x
}

All smoke tests passed.
```

## Troubleshooting

- **`ImportError: cannot import name 'enigma' from 'mlir.dialects'`** —
  `PYTHONPATH` points at the wrong directory. It must point at the
  *parent* of `mlir_enigma/` (i.e. `build/python/python_packages`), not at
  `mlir_enigma/` itself.
- **`Could not find include file 'mlir/Bindings/Python/Attributes.td'`** —
  recent MLIR dropped that shim. The TableGen wrapper at
  `python/mlir_enigma/dialects/EnigmaOps.td` no longer includes it; just
  re-run CMake if you upgrade LLVM and hit this.
- **`Variable not defined: 'AnyVectorOfNonZeroRank'`** — your LLVM is
  older than the constraint; the repo uses `AnyVector` instead.

# Enigma-Dialect

A production-grade MLIR dialect for Apple Metal GPU, lowering to MSL
(Metal Shading Language) and `.metallib`.

This repository is the **base** of the project: just enough infrastructure
to round-trip a vector-add kernel from `.mlir` → `.metal` → `.metallib` →
GPU. Everything is deliberately small, well-commented, and set up so that
adding new features is a tight edit → build → test loop.

## Documentation

- [docs/project-structure.md](docs/project-structure.md) — full planned
  directory layout, layering rules, and build order
- Every source file in `include/` and `lib/` has an extended header
  comment explaining WHAT it is, WHY it exists, and HOW TO EXTEND it.
  Start there when adding new ops, types, passes, or translations.

## Current surface area

**Dialect ops** (in [include/enigma/Dialect/Enigma/IR/EnigmaOps.td](include/enigma/Dialect/Enigma/IR/EnigmaOps.td)):

| Op                                   | Summary                                         |
| ------------------------------------ | ----------------------------------------------- |
| `enigma.kernel`                      | Metal compute kernel function (with body)       |
| `enigma.return`                      | Void terminator for a kernel                    |
| `enigma.thread_position_in_grid`     | Global thread id (per dimension)                |
| `enigma.threadgroup_position_in_grid`| Block id (per dimension)                        |
| `enigma.thread_position_in_threadgroup`| Local thread id (per dimension)               |
| `enigma.threads_per_threadgroup`     | Block dim (per dimension)                       |
| `enigma.threadgroup_barrier`         | `threadgroup_barrier(mem_flags::...)` equivalent|

**Tools**:

- `enigma-opt` — MLIR optimizer driver for the `enigma` dialect
- `enigma-translate` — runs `--enigma-to-msl` to emit MSL source
- `enigma-runner` — macOS-only host runner that loads a `.metallib`, runs
  the kernel on GPU, and prints results (gated by `ENIGMA_ENABLE_METAL_RUNTIME`)

**Tests**: lit + FileCheck, invoked via `ninja check-enigma`.

## Building

> If you just want to **use** the Enigma DSL on Apple Silicon, don't build
> this from source — `pip install enigma-dsl` ships a wheel that already
> contains the dialect, libLLVM, and libMLIRPythonCAPI. Build from source
> only if you are hacking on the dialect itself.

You need a **prebuilt LLVM + MLIR** on the system, configured with the
MLIR Python bindings (LLVM 22.x onward uses nanobind, which this dialect
relies on via `NanobindAdaptors.h`). Apple's stock Homebrew `llvm`
formula is **not** sufficient — it doesn't ship the MLIR Python
bindings, and it tracks the LLVM major version Homebrew has settled on,
not the one this dialect targets.

The supported path is to build LLVM 22.x in-tree under
`~/.local/enigma-llvm/` using the helper script:

```bash
brew install cmake ninja
bash scripts/build_llvm.sh         # ~30-90 min first time, isolated build
source ~/.local/enigma-llvm/activate.sh   # puts MLIR_DIR / LLVM_DIR on shell
```

`build_llvm.sh` produces a generic arm64 build that works on M1 through
M5 (no `-march=native`, no CPU-specific tuning), with
`CMAKE_OSX_DEPLOYMENT_TARGET=14.0` so the resulting libraries link
against the macOS 14 SDK floor — they run on **macOS 14, 15, and every
newer version**. The published Enigma DSL wheels themselves are built
twice (with `MACOSX_DEPLOYMENT_TARGET=14.0` and `=15.0`) so `pip` can
pick the most specific wheel for the host.

If you already built LLVM elsewhere, set `MLIR_DIR` and `LLVM_DIR` to
the matching subdirectories of your build tree (they contain
`MLIRConfig.cmake` and `LLVMConfig.cmake` respectively) **before**
invoking CMake — `activate.sh` is one way to do that, but exporting the
two vars by hand works equally well.

Then, from the project root:

```bash
cmake -S . -B build -G Ninja
ninja -C build
ninja -C build check-enigma    # runs the lit regression suite
```

### Building the Python wheel

This dialect ships as a Python wheel as part of the `enigma-dsl` PyPI
release. The wheel pipeline lives in the parent
[`Enigma-DSL`](../Enigma-DSL) repo — its `build_all.sh` drives this
project's `scripts/build-wheel.sh` once per Python ABI, fixes Mach-O
rpaths so the bundled dylibs load from `@loader_path`, then merges the
output with the pure-Python DSL. See
[`Enigma-DSL/README.md`](../Enigma-DSL/README.md) for the full
two-stage build flow.

## Running the end-to-end demo

The full pipeline for a compute kernel is four steps:

```bash
# 1. MLIR -> MSL source
./build/bin/enigma-translate --enigma-to-msl \
    test/Target/MSL/vector_add.mlir \
    -o /tmp/vector_add.metal

# 2. MSL source -> AIR (Metal's intermediate)
xcrun -sdk macosx metal -c /tmp/vector_add.metal -o /tmp/vector_add.air

# 3. AIR -> metallib
xcrun -sdk macosx metallib /tmp/vector_add.air -o /tmp/vector_add.metallib

# 4. Run on the GPU
./build/bin/enigma-runner /tmp/vector_add.metallib vector_add
```

If step 4 prints `PASSED (0 / 1024 mismatches)`, the whole pipeline is
green.

## Layout

```
Enigma-Dialect/
├── CMakeLists.txt                     # root — finds MLIR, wires subdirs
├── docs/project-structure.md          # planned full structure + rules
├── include/enigma/
│   ├── Dialect/Enigma/IR/              # dialect .td + headers (tablegen)
│   ├── Target/MSL/TranslateToMSL.h    # public emitter API
│   └── InitAll.h                      # single registration entry point
├── lib/
│   ├── Dialect/Enigma/IR/             # dialect C++ implementation
│   ├── Target/MSL/                    # MSL emitter (visitor)
│   ├── InitAll.cpp                    # implements InitAll.h
│   └── CMakeLists.txt
├── tools/
│   ├── enigma-opt/                    # the opt driver
│   ├── enigma-translate/              # the translate driver
│   └── enigma-runner/                 # macOS-only GPU launcher
└── test/
    ├── CMakeLists.txt                 # check-enigma target
    ├── lit.cfg.py / lit.site.cfg.py.in
    ├── Dialect/Enigma/roundtrip.mlir  # dialect parse/print test
    └── Target/MSL/vector_add.mlir     # MSL emission test
```

## Where to go from here

The base is complete. The next vertical slices, in recommended order, are
listed at the bottom of
[EnigmaOps.td](include/enigma/Dialect/Enigma/IR/EnigmaOps.td) and
[MSLEmitter.cpp](lib/Target/MSL/MSLEmitter.cpp):

1. Address-space aware memrefs (`device`/`constant`/`threadgroup`/`thread`)
2. Threadgroup memory allocation + real reductions
3. Simdgroup reduction ops (`simd_sum`, `simd_max`, …)
4. Atomics with memory-order enum
5. Custom dialect types for textures + samplers
6. Argument buffer type + packing
7. Vertex/fragment graphics stages
8. `GPUToEnigma` conversion pass from upstream `gpu` dialect
9. Refactor the MSL emitter behind an `MSLEmittable` OpInterface
10. Python bindings → Python DSL

Each one follows the same loop:

> hand-write the MSL you want → design the op in `.td` → add emitter case
> → lit test → `xcrun metal` as oracle → commit.

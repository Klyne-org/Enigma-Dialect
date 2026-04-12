# Enigma Dialect — Project Structure

A production-scale MLIR dialect for Metal GPU, lowering to MSL (Metal Shading
Language) and `.metallib`. This document is the canonical layout reference.
Every directory has one clear responsibility — a new contributor should be
able to guess where any file lives.

## Top-level tree

```
Enigma-Dialect/
│
├── CMakeLists.txt                  # root: find MLIR, options, add_subdirectory
├── LICENSE
├── README.md
├── CONTRIBUTING.md
├── .clang-format / .clang-tidy
├── .github/workflows/              # CI: linux-build, macos-build+metal, lint
│
├── cmake/
│   ├── EnigmaConfig.cmake.in       # exported package config
│   ├── AddEnigma.cmake             # add_enigma_dialect_library() etc. helpers
│   ├── FindMetal.cmake             # locates Metal.framework, metal compiler
│   └── modules/                    # sanitizers, ccache, warnings
│
├── docs/
│   ├── project-structure.md        # this file
│   ├── design/
│   │   ├── 00-overview.md
│   │   ├── 01-dialect-rationale.md
│   │   ├── 02-lowering-pipeline.md
│   │   ├── 03-msl-mapping.md       # Enigma op ↔ MSL construct table
│   │   ├── 04-argument-buffers.md
│   │   └── 05-runtime-abi.md
│   ├── tutorials/
│   ├── ops/                        # auto-generated from .td via mlir-tblgen
│   └── adr/                        # Architecture Decision Records
│
├── include/enigma/                 # === PUBLIC HEADERS ===
│   │
│   ├── InitAll.h                   # registerAllDialects/Passes/Translations
│   ├── Support/
│   │   ├── LLVM.h                  # using-decls for llvm types
│   │   ├── Debug.h
│   │   └── Diagnostics.h
│   │
│   ├── Dialect/
│   │   └── Enigma/
│   │       ├── IR/
│   │       │   ├── EnigmaDialect.td
│   │       │   ├── EnigmaDialect.h
│   │       │   ├── EnigmaBase.td           # shared TableGen defs
│   │       │   ├── EnigmaTypes.td / .h
│   │       │   ├── EnigmaAttrs.td / .h
│   │       │   ├── EnigmaEnums.td / .h
│   │       │   ├── EnigmaInterfaces.td / .h
│   │       │   ├── EnigmaDeviceOps.td      # kernel-side ops
│   │       │   ├── EnigmaHostOps.td        # command-buffer/encoder ops
│   │       │   ├── EnigmaMemoryOps.td      # buffers, textures, arg buffers
│   │       │   ├── EnigmaSyncOps.td        # barriers, fences, events
│   │       │   ├── EnigmaOps.h             # umbrella include
│   │       │   └── CMakeLists.txt          # mlir_tablegen calls
│   │       │
│   │       ├── Transforms/
│   │       │   ├── Passes.td
│   │       │   ├── Passes.h
│   │       │   ├── Patterns.h
│   │       │   └── Utils.h
│   │       │
│   │       └── Analysis/
│   │           ├── MemoryAccessAnalysis.h
│   │           └── KernelResourceAnalysis.h
│   │
│   ├── Conversion/
│   │   ├── Passes.td                       # all conversion passes in one file
│   │   ├── Passes.h
│   │   ├── GPUToEnigma/                    # upstream gpu → enigma
│   │   ├── EnigmaToLLVM/                   # host-side runtime calls
│   │   ├── MemRefToEnigma/
│   │   └── VectorToEnigma/
│   │
│   ├── Target/
│   │   ├── MSL/
│   │   │   ├── TranslateToMSL.h            # public entry
│   │   │   ├── MSLEmitterOptions.h
│   │   │   └── MSLDialectMapping.h
│   │   └── MetalLib/
│   │       └── BuildMetalLib.h             # drives `xcrun metal`
│   │
│   ├── Runtime/                            # C API for the host shim
│   │   ├── EnigmaRuntime.h
│   │   └── EnigmaRuntimeTypes.h
│   │
│   └── CAPI/                               # stable C API (for Python/FFI)
│       ├── Dialects.h
│       ├── Passes.h
│       └── Translation.h
│
├── lib/                            # === IMPLEMENTATION (mirrors include/) ===
│   │
│   ├── InitAll.cpp
│   ├── Support/
│   │
│   ├── Dialect/Enigma/
│   │   ├── IR/
│   │   │   ├── EnigmaDialect.cpp
│   │   │   ├── EnigmaOps.cpp
│   │   │   ├── EnigmaTypes.cpp
│   │   │   ├── EnigmaAttrs.cpp
│   │   │   ├── EnigmaInterfaces.cpp
│   │   │   ├── EnigmaCanonicalization.cpp  # or inline as .td patterns
│   │   │   └── CMakeLists.txt
│   │   │
│   │   ├── Transforms/
│   │   │   ├── KernelOutlining.cpp
│   │   │   ├── ResourceBindingAssignment.cpp
│   │   │   ├── ArgumentBufferPacking.cpp
│   │   │   ├── BarrierHoisting.cpp
│   │   │   ├── DeadKernelElimination.cpp
│   │   │   ├── PassDetail.h
│   │   │   └── CMakeLists.txt
│   │   │
│   │   └── Analysis/
│   │
│   ├── Conversion/
│   │   ├── GPUToEnigma/
│   │   │   ├── GPUToEnigmaPass.cpp
│   │   │   ├── ConvertLaunch.cpp
│   │   │   ├── ConvertMemory.cpp
│   │   │   └── CMakeLists.txt
│   │   ├── EnigmaToLLVM/
│   │   ├── MemRefToEnigma/
│   │   └── VectorToEnigma/
│   │
│   ├── Target/
│   │   ├── MSL/
│   │   │   ├── MSLEmitter.cpp              # the visitor
│   │   │   ├── MSLTypePrinter.cpp
│   │   │   ├── MSLExpressionPrinter.cpp
│   │   │   ├── MSLIntrinsicMapping.cpp     # Enigma ops → MSL builtins
│   │   │   ├── MSLPreamble.cpp             # headers, using-decls
│   │   │   ├── TranslateRegistration.cpp
│   │   │   └── CMakeLists.txt
│   │   └── MetalLib/
│   │       ├── BuildMetalLib.cpp           # invokes `xcrun metal`, `metallib`
│   │       └── CMakeLists.txt
│   │
│   ├── Runtime/                            # host-side C++ shim
│   │   ├── EnigmaRuntime.mm                # Objective-C++ for Metal API
│   │   ├── CommandQueue.mm
│   │   ├── BufferPool.mm
│   │   ├── PipelineCache.mm
│   │   └── CMakeLists.txt                  # only built if ENIGMA_ENABLE_METAL
│   │
│   └── CAPI/
│       ├── Dialects.cpp
│       ├── Passes.cpp
│       └── Translation.cpp
│
├── tools/
│   ├── enigma-opt/                 # dialect + passes driver
│   │   ├── enigma-opt.cpp
│   │   └── CMakeLists.txt
│   ├── enigma-translate/           # registers MSL target
│   │   ├── enigma-translate.cpp
│   │   └── CMakeLists.txt
│   ├── enigma-runner/              # loads .metallib, launches kernels (mac-only)
│   │   ├── enigma-runner.mm
│   │   └── CMakeLists.txt
│   └── enigma-lsp-server/          # optional: MLIR LSP for .mlir files
│
├── python/                         # optional but worth it for big projects
│   ├── CMakeLists.txt
│   ├── EnigmaExtension.cpp         # pybind11/nanobind glue
│   └── enigma/
│       ├── __init__.py
│       ├── dialects/enigma.py      # generated by mlir tblgen-pybind
│       └── passes.py
│
├── test/                           # === LIT TESTS ===
│   ├── CMakeLists.txt
│   ├── lit.cfg.py
│   ├── lit.site.cfg.py.in
│   ├── Dialect/Enigma/
│   │   ├── ops.mlir
│   │   ├── invalid.mlir
│   │   ├── canonicalize.mlir
│   │   └── roundtrip.mlir
│   ├── Transforms/
│   │   ├── kernel-outlining.mlir
│   │   ├── argument-buffer-packing.mlir
│   │   └── barrier-hoisting.mlir
│   ├── Conversion/
│   │   ├── GPUToEnigma/
│   │   ├── EnigmaToLLVM/
│   │   └── MemRefToEnigma/
│   ├── Target/MSL/
│   │   ├── basic-kernel.mlir       # CHECK against emitted MSL text
│   │   ├── atomics.mlir
│   │   ├── textures.mlir
│   │   └── argument-buffers.mlir
│   └── CAPI/
│
├── unittests/                      # === GTEST ===
│   ├── CMakeLists.txt
│   ├── IR/
│   ├── Analysis/
│   ├── Target/MSL/
│   │   └── EmitterTest.cpp         # unit-level: build ops, emit, diff string
│   └── Runtime/
│
├── integration_test/               # === END-TO-END, mac+Metal only ===
│   ├── CMakeLists.txt              # gated by ENIGMA_ENABLE_METAL_TESTS
│   ├── lit.cfg.py
│   ├── vector-add/
│   │   ├── vector_add.mlir
│   │   ├── host.cpp
│   │   └── expected.txt
│   ├── matmul/
│   ├── reduction/
│   └── textures/
│
├── benchmark/                      # perf tracking
│   ├── CMakeLists.txt
│   ├── microbench/                 # google-benchmark, per-op
│   └── kernels/                    # real workloads vs hand-written MSL
│
├── examples/                       # user-facing, documented
│   ├── 01-hello-kernel/
│   ├── 02-reduction/
│   └── 03-custom-pipeline/
│
└── third_party/                    # pinned, vendored or submodule'd
    ├── spirv-cross/                # optional: reference MSL path
    └── metal-cpp/                  # Apple's C++ headers (if used)
```

## The four rules that keep a project this size sane

1. **`include/` and `lib/` mirror each other exactly.** If you create
   `lib/Dialect/Enigma/Transforms/Foo.cpp`, the only header it may expose
   publicly goes in `include/enigma/Dialect/Enigma/Transforms/`. Private
   headers sit next to the `.cpp`.

2. **Layering is one-directional.** `Dialect → Analysis → Transforms →
   Conversion → Target`. No back-edges. `Target/MSL` may depend on
   `Dialect/Enigma/IR` but the IR must never know MSL exists. Enforce this by
   CMake link targets, not by convention.

3. **One dialect concern per `.td` file**, not one giant `EnigmaOps.td`.
   Splitting device / host / memory / sync ops makes TableGen rebuilds fast
   and diffs readable.

4. **Every buildable artifact has its own CMakeLists.txt.** Never reach up
   into a parent dir's CMake. `add_mlir_dialect_library`,
   `add_mlir_conversion_library`, `add_mlir_translation_library` each live
   beside the source they build. Root CMake only does `find_package` +
   `add_subdirectory`.

## Cross-cutting pieces that are easy to forget

- **`lib/InitAll.cpp`** is the single registration point. Every new
  pass / dialect / translation gets one line here. Tools (`enigma-opt`,
  Python bindings, embedded use) all call into it. Without this you drift
  into "works in opt but not in translate" bugs.
- **A stable `CAPI/`** layer from day one, even if you don't ship Python
  bindings yet. It's the seam that lets you embed Enigma in other tools
  (Swift, Rust, a game engine) without exposing C++ ABI.
- **`docs/adr/`** — Architecture Decision Records. One markdown file per
  decision, numbered, immutable. "Why did we model argument buffers as a
  type and not an attribute?" will come up in 6 months.

## Translation story (Enigma → MSL)

Keep MSL emission isolated under `lib/Target/MSL/`:

- **`MSLEmitter.cpp`** — a visitor-style walker over Enigma IR that prints
  MSL text into a `raw_ostream`. Model it on MLIR's `mlir-translate`
  `CppEmitter` / `SPIRVTarget`.
- **`TranslateRegistration.cpp`** — registers `enigma-to-msl` with
  `mlir::TranslateFromMLIRRegistration` so `enigma-translate --enigma-to-msl`
  just works.
- Optionally keep a second path for **SPIR-V → MSL via `spirv-cross`** behind
  the same interface as a reference oracle while you build your own emitter.

Two translation modes worth supporting from day one:

1. Kernel-only MSL source (text) — for JIT and for unit tests (diffable).
2. Metal-ready `.metallib` via `xcrun metal` / `metallib` — driven from the
   same emitter, just a separate tool target.

## Build order — what to implement in what order

Each step is shippable on its own. That's the real test of the structure:
you should never need to move files to add a feature.

1. Root CMake + `include/enigma/Support` + empty `InitAll` + `enigma-opt`
   that builds and runs `--help`.
2. `Dialect/Enigma/IR` with 2–3 trivial ops, lit round-trip tests.
3. `Target/MSL` emitter skeleton + `enigma-translate` + one lit test that
   emits `kernel void foo() {}`.
4. `GPUToEnigma` conversion for `gpu.launch_func`. Now you have a pipeline:
   `gpu.mlir → enigma-opt → enigma-translate → .metal`.
5. Runtime shim + `enigma-runner` + first integration test (`vector-add`).
6. Everything else — argument buffers, textures, atomics, analyses,
   benchmarks — slots into the structure without reorganization.

## Opinions worth keeping

- **Don't fork upstream `gpu`** — depend on it. Enigma should sit either
  *above* `gpu` (high-level Metal-specific ops) or *below* it (post
  `gpu-kernel-outlining` lowering target). Pick one and document it in
  `docs/design/01-dialect-rationale.md` before writing ops.
- **Version the IR.** Add a dialect attribute `enigma.version = "0.1"` and
  reject loads from newer versions. Cheap now, painful to retrofit.
- **Separate host and device ops** into different `.td` files. Metal's host
  API (command buffers, encoders, argument buffers) and MSL's device-side
  model are genuinely different domains.
- **Argument buffers are first-class in Metal** — model them as a real
  type/attribute early.
- **CI matrix**: linux-clang (build + lit, no metal), macos-arm64 (build +
  lit + integration), macos-x86 (build + lit). Cache the LLVM/MLIR build —
  it dominates CI time.
- **Gate Metal-specific code** behind `ENIGMA_ENABLE_METAL_BACKEND` so
  non-mac contributors can still build and test the pure-IR parts.

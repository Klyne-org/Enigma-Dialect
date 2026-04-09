# Enigma Dialect — Implementation Notes & Contributor Guide

This document is the living record of what the project **currently is**, how
the pieces fit together, and the exact procedure to follow when adding new
features. Read this once before you write code. Update it whenever the
architecture changes in a way the file comments don't cover.

For the broader planned layout and roadmap, see
[project-structure.md](project-structure.md). This file is specifically about
the base that has been built and proven to work end-to-end on an Apple M4.

---

## 1. What exists right now

### 1.1 Verified pipeline

```
   .mlir (enigma dialect)
        │
        │   enigma-opt              (round-trip, future passes)
        │   enigma-translate --enigma-to-msl
        ▼
   .metal (Metal Shading Language text)
        │
        │   xcrun metal -c
        ▼
   .air
        │
        │   xcrun metallib
        ▼
   .metallib
        │
        │   enigma-runner           (loads, dispatches, verifies)
        ▼
   Runs on Apple GPU
```

Every arrow above has been exercised on a real Apple M4 device with
`vector_add`. If any arrow breaks in the future, the commit that broke it is
the regression — fix the root cause rather than routing around it.

### 1.2 Dialect surface area

Defined in [include/enigma/Dialect/Enigma/IR/EnigmaOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaOps.td):

| Op                                       | Operands / Attrs         | Result   | Purpose                                                  |
| ---------------------------------------- | ------------------------ | -------- | -------------------------------------------------------- |
| `enigma.kernel`                          | `sym_name`, `function_type`, body region | —        | Compute kernel function; `IsolatedFromAbove`             |
| `enigma.return`                          | —                        | —        | Void terminator for a kernel                             |
| `enigma.thread_position_in_grid`         | `dimension: x\|y\|z`     | `index`  | Global thread id                                         |
| `enigma.threadgroup_position_in_grid`    | `dimension: x\|y\|z`     | `index`  | Block id                                                 |
| `enigma.thread_position_in_threadgroup`  | `dimension: x\|y\|z`     | `index`  | Local thread id within threadgroup                       |
| `enigma.threads_per_threadgroup`         | `dimension: x\|y\|z`     | `index`  | Block dimension                                          |
| `enigma.threadgroup_barrier`             | `mem_flags: i32`         | —        | `threadgroup_barrier(mem_flags::...)` equivalent         |

### 1.3 Ops from upstream dialects that the emitter handles

These appear inside `enigma.kernel` bodies and are lowered directly to MSL by
[lib/Target/MSL/MSLEmitter.cpp](../lib/Target/MSL/MSLEmitter.cpp):

- `memref.load`, `memref.store`
- `arith.addf`, `arith.subf`, `arith.mulf`
- `arith.addi`, `arith.muli`
- `arith.constant`

Anything else that appears in a kernel body is emitted as a
`// UNHANDLED: <opname>` comment. The MSL file will fail to compile under
`xcrun metal` — that's by design. It turns missing emitter support into a
loud, early error rather than a silent miscompile.

### 1.4 Binaries

| Binary             | Source                                                       | What it does                              |
| ------------------ | ------------------------------------------------------------ | ------------------------------------------ |
| `enigma-opt`       | [tools/enigma-opt/enigma-opt.cpp](../tools/enigma-opt/enigma-opt.cpp)             | MLIR optimizer driver (parse, pass, print) |
| `enigma-translate` | [tools/enigma-translate/enigma-translate.cpp](../tools/enigma-translate/enigma-translate.cpp) | Runs registered translation directions    |
| `enigma-runner`    | [tools/enigma-runner/enigma-runner.mm](../tools/enigma-runner/enigma-runner.mm)     | Loads `.metallib`, dispatches on GPU       |

All three flow through `enigma::registerAllEnigmaDialects/Passes/Translations`
in [lib/InitAll.cpp](../lib/InitAll.cpp). That is the **single place** every
tool goes through to know about dialects, passes, and translations. Never
register anything directly inside a tool's `main()`.

### 1.5 Directory layout (what actually exists on disk today)

```
Enigma-Dialect/
├── CMakeLists.txt                       # root — finds MLIR, wires subdirs
├── README.md                            # quick start
├── .gitignore
├── docs/
│   ├── project-structure.md             # full planned layout
│   └── implementation.md                # this file
├── include/enigma/
│   ├── InitAll.h                        # single registration entry point
│   ├── Dialect/Enigma/IR/
│   │   ├── EnigmaDialect.td             # dialect declaration
│   │   ├── EnigmaOps.td                 # op catalogue
│   │   ├── EnigmaDialect.h              # public header
│   │   └── CMakeLists.txt               # tablegen invocation
│   └── Target/MSL/
│       └── TranslateToMSL.h             # public translation API
├── lib/
│   ├── InitAll.cpp
│   ├── CMakeLists.txt                   # EnigmaInitAll library
│   ├── Dialect/Enigma/IR/
│   │   ├── EnigmaDialect.cpp            # dialect impl + KernelOp parser/printer
│   │   └── CMakeLists.txt
│   └── Target/MSL/
│       ├── MSLEmitter.cpp               # the visitor
│       └── CMakeLists.txt
├── tools/
│   ├── enigma-opt/     { .cpp, CMakeLists.txt }
│   ├── enigma-translate/{ .cpp, CMakeLists.txt }
│   └── enigma-runner/  { .mm,  CMakeLists.txt }   # macOS-only
└── test/
    ├── CMakeLists.txt                   # check-enigma target
    ├── lit.cfg.py
    ├── lit.site.cfg.py.in
    ├── Dialect/Enigma/roundtrip.mlir    # parse/print symmetry
    └── Target/MSL/vector_add.mlir       # end-to-end MSL emission
```

---

## 2. How the build works (important mental model)

### 2.1 TableGen is code generation at build time

Every op in [EnigmaOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaOps.td) is
a declarative description that `mlir-tblgen` turns into C++ at build time.
You never write op parser/printer/verifier boilerplate by hand — you describe
the op in ~20 lines of TableGen and get ~300 lines of C++ for free.

The generated files land in the **build directory**, not the source tree:

```
build/include/enigma/Dialect/Enigma/IR/
├── EnigmaDialect.h.inc      # generated dialect class decl
├── EnigmaDialect.cpp.inc    # generated dialect class impl
├── EnigmaOps.h.inc          # one C++ class per op (decls)
├── EnigmaOps.cpp.inc        # parsers, printers, verifiers
├── EnigmaOpsEnums.h.inc     # enum types declared in .td
└── EnigmaOpsEnums.cpp.inc
```

The hand-written header [EnigmaDialect.h](../include/enigma/Dialect/Enigma/IR/EnigmaDialect.h)
includes these `.inc` files. That is why both `include/` and
`${CMAKE_BINARY_DIR}/include` are on the include path.

### 2.2 Library layering (do not violate this)

```
     tools (enigma-opt, enigma-translate, enigma-runner)
                │
                ▼
          EnigmaInitAll                    ← single registration hub
           │         │
           ▼         ▼
   EnigmaDialect   EnigmaTargetMSL
        │               │
        └───────┬───────┘
                ▼
            MLIR + LLVM
```

Rules:

- `EnigmaDialect` must not depend on `EnigmaTargetMSL`. The IR never knows
  anything about its emission targets.
- `EnigmaTargetMSL` may depend on `EnigmaDialect`. The emitter has to know
  about ops.
- `EnigmaInitAll` is the only library that depends on both. It exists
  specifically to expose one entry point per concern to tools.
- Tools depend only on `EnigmaInitAll` (plus upstream MLIR libs). If a tool
  has to pull in `EnigmaDialect` directly to "fix a missing symbol", the
  real fix is almost always to add something to `InitAll.cpp`.

### 2.3 Two gotchas hit during first build (pinned here so they never come back)

These are fixed in the repo but worth knowing so the next LLVM upgrade
doesn't surprise you.

**1. Tablegen needs `-dialect=enigma` on dialect-def generation.**
When `EnigmaOps.td` transitively includes builtin/enum/sideeffect `.td`
files, `mlir-tblgen` sees multiple dialects in scope and refuses to guess.
Fixed in [include/enigma/Dialect/Enigma/IR/CMakeLists.txt](../include/enigma/Dialect/Enigma/IR/CMakeLists.txt#L46-L53).

**2. Generated op headers require modern MLIR includes.**
MLIR ≥ 20 generates `readProperties` / `writeProperties` methods that
reference `DialectBytecodeReader`/`Writer`. Those live in
`mlir/Bytecode/BytecodeOpInterface.h`. The hand-written dialect header
includes it explicitly. Fixed in
[include/enigma/Dialect/Enigma/IR/EnigmaDialect.h](../include/enigma/Dialect/Enigma/IR/EnigmaDialect.h#L28-L38).

---

## 3. How to build and run (reproducible, verified on Apple M4)

### 3.1 Prerequisites

```bash
brew install llvm ninja cmake
```

### 3.2 Configure

```bash
MLIR_DIR=/opt/homebrew/opt/llvm/lib/cmake/mlir \
LLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm \
  cmake -S . -B build -G Ninja
```

Run this once, or whenever you change a `CMakeLists.txt`.

### 3.3 Build

```bash
ninja -C build enigma-opt enigma-translate enigma-runner
```

Fast rebuilds: just re-run `ninja -C build`. Ninja only rebuilds what changed.

### 3.4 Run the full end-to-end demo

```bash
# Dialect round-trip (sanity check)
./build/tools/enigma-opt/enigma-opt test/Dialect/Enigma/roundtrip.mlir

# MLIR → MSL text
./build/tools/enigma-translate/enigma-translate --enigma-to-msl \
  test/Target/MSL/vector_add.mlir -o /tmp/enigma_vector_add.metal

# Inspect the emitted MSL
cat /tmp/enigma_vector_add.metal

# MSL → metallib
xcrun -sdk macosx metal    -c /tmp/enigma_vector_add.metal -o /tmp/enigma_vector_add.air
xcrun -sdk macosx metallib    /tmp/enigma_vector_add.air   -o /tmp/enigma_vector_add.metallib

# Run on the GPU
./build/tools/enigma-runner/enigma-runner /tmp/enigma_vector_add.metallib vector_add
```

Expected last line:

```
enigma-runner: PASSED (0 / 1024 mismatches)
```

If you see that, the whole pipeline is green.

---

## 4. The procedure for adding a new op

This is the standard loop. Every new op follows it. After two or three
iterations it becomes muscle memory.

### Step 1 — hand-write the MSL you want

Open a scratch file, e.g. `/tmp/scratch.metal`, and type the MSL by hand.
Compile it with `xcrun metal -c /tmp/scratch.metal -o /tmp/scratch.air`.
If it doesn't compile, you don't understand the feature well enough to
design an op for it. **Do not skip this step.**

### Step 2 — design the MLIR form

In a scratch `.mlir`, write how you want users to express the feature in
Enigma. Focus on readability and on composing cleanly with existing ops.
Sketch 2–3 variants. Pick the one that feels most natural when read out
loud.

### Step 3 — add the TableGen definition

Open [include/enigma/Dialect/Enigma/IR/EnigmaOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaOps.td).
Add a `def` block for your op:

```tablegen
def Enigma_FooOp : Enigma_Op<"foo", [Pure]> {
  let summary = "one-line description";
  let description = [{
    Longer description, including an MLIR example.
  }];
  let arguments = (ins AnyInteger:$lhs, AnyInteger:$rhs);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}
```

Guidelines:
- Use `Pure` for ops with no side effects (most pure computation).
- Use `Terminator` for new block-ending ops.
- Prefer `assemblyFormat` strings over custom parsers. Only go custom when
  you must, like `enigma.kernel`.
- One concern per op. If the description has "and", split it.

### Step 4 — (only if the op has a custom parser/printer or verifier)

Add `hasCustomAssemblyFormat = 1;` or `hasVerifier = 1;` to the `.td`, then
implement `FooOp::parse`, `FooOp::print`, or `FooOp::verify` in
[lib/Dialect/Enigma/IR/EnigmaDialect.cpp](../lib/Dialect/Enigma/IR/EnigmaDialect.cpp).
Model on `KernelOp::parse/print`.

### Step 5 — add the emitter case

Open [lib/Target/MSL/MSLEmitter.cpp](../lib/Target/MSL/MSLEmitter.cpp). In
`emitOp`, add:

```cpp
if (auto foo = dyn_cast<FooOp>(op))
  return emitFoo(foo);
```

Then add a private `emitFoo(FooOp op)` method that prints the MSL text
corresponding to the op. Model on `emitLoad`, `emitBinOp`, etc.

### Step 6 — add a round-trip test

Open [test/Dialect/Enigma/roundtrip.mlir](../test/Dialect/Enigma/roundtrip.mlir).
Add a `// CHECK:` line and an IR snippet that uses your new op. Run:

```bash
./build/tools/enigma-opt/enigma-opt test/Dialect/Enigma/roundtrip.mlir
```

Visually confirm the output matches what you expect. Refine the CHECK
lines until the pattern is right.

### Step 7 — add an MSL emission test

Open [test/Target/MSL/vector_add.mlir](../test/Target/MSL/vector_add.mlir) or
create a new `test/Target/MSL/foo.mlir`. Add `// RUN:` and `// CHECK:`
lines, then run:

```bash
./build/tools/enigma-translate/enigma-translate --enigma-to-msl test/Target/MSL/foo.mlir
```

Paste the interesting emitted lines as `// CHECK:` lines, using wildcards
(`v{{[0-9]+}}`) for SSA value names.

### Step 8 — compile the emitted MSL with xcrun metal (the oracle step)

```bash
./build/tools/enigma-translate/enigma-translate --enigma-to-msl \
  test/Target/MSL/foo.mlir -o /tmp/foo.metal
xcrun -sdk macosx metal -c /tmp/foo.metal -o /tmp/foo.air
```

If `xcrun metal` errors, **your emitter is wrong**. Fix the emitter, not
the expected output. This is the most important step in the whole loop:
`xcrun metal` is the ground truth for what valid MSL looks like.

### Step 9 — (optional but recommended) run it on the GPU

If the op is user-visible in a compute kernel, add a small `.mlir` that
uses it alongside vector_add, compile to `.metallib`, and run under
`enigma-runner`. This catches semantic bugs the compiler alone cannot.

### Step 10 — commit

One op per commit. Commit message should say:
- what the op is
- what MSL it maps to
- what test proves it works

---

## 5. The procedure for adding a pass

Passes don't exist yet — when you write the first one, follow this.

### Step 1 — create the pass directory structure

```
include/enigma/Dialect/Enigma/Transforms/
├── Passes.td           # declarative pass registration
├── Passes.h            # C++ pass declarations
└── CMakeLists.txt      # tablegen for -gen-pass-decls

lib/Dialect/Enigma/Transforms/
├── YourFirstPass.cpp
└── CMakeLists.txt      # add_mlir_dialect_library or add_mlir_pass_library
```

### Step 2 — declare the pass in `Passes.td`

```tablegen
def EnigmaYourFirstPass : Pass<"enigma-your-first", "::mlir::ModuleOp"> {
  let summary = "one-liner";
  let description = [{ longer }];
  let constructor = "enigma::createYourFirstPass()";
}
```

### Step 3 — implement the pass

In `YourFirstPass.cpp`, implement a class deriving from
`PassWrapper<YourFirstPass, OperationPass<ModuleOp>>`, override
`runOnOperation`, and provide a `createYourFirstPass()` factory.

### Step 4 — register it

Add `registerEnigmaYourFirstPass()` (or similar) to
[lib/InitAll.cpp](../lib/InitAll.cpp) in `registerAllEnigmaPasses()`.

### Step 5 — test it

```
test/Transforms/your-first.mlir
```

```
// RUN: enigma-opt --enigma-your-first %s | FileCheck %s
```

### Step 6 — link

Add `add_subdirectory(include/enigma/Dialect/Enigma/Transforms)` and
`add_subdirectory(lib/Dialect/Enigma/Transforms)` to the root
`CMakeLists.txt`.

---

## 6. Suggested next features, in recommended order

Each one is a self-contained vertical slice. Do **one at a time**. Get it
green end-to-end (dialect → emitter → xcrun metal → enigma-runner if
applicable) before starting the next.

### 6.1 Address-space aware memrefs

**Why this first.** Every real Metal kernel cares about address spaces.
Without this you can't model `threadgroup` memory, `constant` buffers, or
`thread`-local pointers. It unlocks almost every other feature.

**What to do.**
1. Add `EnigmaAddressSpaceAttr` in a new `EnigmaAttrs.td` split out of
   `EnigmaOps.td`. Enum cases: `device`, `constant`, `threadgroup`, `thread`.
2. Use it as the memory-space attribute on memrefs:
   `memref<1024xf32, #enigma.addrspace<threadgroup>>`.
3. In the emitter, read the memref's memory space and emit the correct MSL
   qualifier (`device`, `constant`, `threadgroup`, `thread`).
4. Test: a kernel that allocates a `threadgroup` buffer and does a simple
   write+barrier+read. The emitted MSL must compile under `xcrun metal`.

**Watch-outs.**
- Memory-space attributes in upstream MLIR are notoriously finicky — read
  `mlir::MemRefType::get` carefully.
- Make sure `enigma-opt` round-trips the attribute syntax symmetrically.

### 6.2 Proper `mem_flags` enum for `threadgroup_barrier`

**Why.** Current `mem_flags` is an untyped `i32`. Users have no idea what
values mean. The fix is tiny and teaches you the enum-attr pattern.

**What to do.**
1. Define `Enigma_BarrierMemFlags` as an `I32EnumAttr` with cases `none`,
   `device`, `threadgroup`, `texture`.
2. Swap `I32Attr:$mem_flags` for the new enum in `EnigmaThreadgroupBarrierOp`.
3. Emitter reads the enum, emits `mem_flags::mem_<whatever>`.
4. Update the round-trip test to use the new spelling.

### 6.3 Threadgroup memory allocation op

**Why.** Reductions, scans, and tiled convolutions all need threadgroup
scratch. Depends on 6.1 (address spaces).

**What to do.**
1. Add `enigma.threadgroup_alloc` returning a
   `memref<NxT, #enigma.addrspace<threadgroup>>`.
2. In MSL the equivalent is `threadgroup float scratch[64];` declared
   inside the kernel body.
3. Emitter must hoist the declaration to the top of the kernel body
   (MSL requires it) even though the IR op may live lower.
4. Test: a 1D reduction kernel (sum of a buffer).

### 6.4 Simdgroup reduction ops

**Why.** Most non-trivial Metal kernels use `simd_sum` / `simd_max` /
`simd_broadcast`. They map 1:1 to MSL builtins, so emitter work is tiny
and you get massive leverage.

**What to do.**
1. Add `enigma.simd_sum`, `simd_max`, `simd_min`, `simd_broadcast`,
   `simd_shuffle`, `simd_prefix_inclusive_sum`.
2. Each takes one value, returns one value (same type).
3. Emitter emits `metal::simd_sum(v)` etc.
4. Test: a per-simdgroup reduction.

### 6.5 Atomics

**Why.** Histograms, prefix-sum spillover, synchronization primitives.

**What to do.**
1. Add `enigma.atomic_fetch_add`, `atomic_compare_exchange_weak`, etc.
2. Add an `Enigma_MemoryOrder` enum attribute.
3. Emitter emits the `atomic_fetch_add_explicit(...)` family.
4. Test: atomic histogram.

### 6.6 Refactor the emitter behind an `MSLEmittable` OpInterface

**Why.** Once you hit ~15 ops the `dyn_cast` chain in
[MSLEmitter.cpp](../lib/Target/MSL/MSLEmitter.cpp) becomes unmanageable.
The OpInterface refactor is mechanical and high-leverage.

**What to do.**
1. Declare `MSLEmittable` as an `OpInterface` in a new
   `include/enigma/Interfaces/MSLEmittable.td`.
2. The interface has one method: `void emitMSL(MSLEmitter &emitter)`.
3. Add the trait to every existing op (`Enigma_Op<"foo", [Pure, MSLEmittable]>`).
4. Move each `emitXxx` method out of `MSLEmitter` onto its op class via
   `extraClassDeclaration` + implementation in `EnigmaDialect.cpp`.
5. `emitOp` becomes `if (auto e = dyn_cast<MSLEmittable>(&op)) e.emitMSL(*this);`

After this refactor, adding a new op no longer touches the emitter file.

### 6.7 Textures and samplers (first custom dialect types)

**Why.** Most graphics and ML kernels need textures. This is where custom
dialect types first appear, which unlocks a whole category of features.

**What to do.**
1. Define `!enigma.texture2d<ElemType, access::sample>` as a dialect type
   in a new `EnigmaTypes.td`.
2. Flip `useDefaultTypePrinterParser = 1;` in the dialect def.
3. Add `enigma.texture_sample`, `texture_read`, `texture_write`,
   `texture_gather`.
4. Test: an image blur kernel.

### 6.8 Argument buffers

**Why.** Metal's idiomatic way to bind ≥ 8 resources. Required for any
realistic graphics pipeline.

### 6.9 GPU dialect interop

**Why.** Lets upstream `gpu`-producing pipelines (including linalg
lowerings) target Metal for free.

**What to do.**
1. Add a `GPUToEnigma` conversion pass under
   `lib/Conversion/GPUToEnigma/`.
2. Map `gpu.thread_id x` → `enigma.thread_position_in_grid x`, etc.
3. Map `gpu.launch_func` to an `enigma.kernel` outlining + a host-side
   dispatch op (introduces host ops, which is its own design session).

### 6.10 Python bindings

**Why.** Unlocks Python DSLs on top of the dialect. See
[project-structure.md §"Python DSL"](project-structure.md) for the full
three-layer design (bindings → runtime wrapper → DSL).

**What to do.**
1. Add a `python/` directory with `declare_mlir_dialect_python_bindings`
   pointing at the `.td`.
2. Expose `enigma::translateToMSL` via a tiny nanobind wrapper.
3. The DSL itself (the `@enigma.kernel` decorator layer) is a separate
   project.

---

## 7. Things to watch out for

### 7.1 Don't add features, refactor, or clean up beyond what a single slice needs

The base is small and readable on purpose. Every addition should justify
its existence. A bug fix doesn't need surrounding code cleaned up.
A simple feature doesn't need extra configurability.

### 7.2 Don't let the MSL emitter drift from `xcrun metal`'s opinions

The emitter has one job: produce MSL that compiles. If `xcrun metal`
rejects something, the emitter is wrong, not the compiler. Always
compile emitted MSL with `xcrun metal` as the final validation step
for any op change.

### 7.3 Every new op needs both tests

- Round-trip test in `test/Dialect/Enigma/` — proves parser/printer
  symmetry.
- MSL emission test in `test/Target/MSL/` — proves the emitter does the
  right thing.

A feature without both tests is not landed.

### 7.4 Version drift is real

MLIR's C++ API is not stable across versions. When you upgrade LLVM,
expect to fix 1–3 small build breaks. Pin them in the source with a
comment like `// MLIR 20+: needs mlir/Bytecode/BytecodeOpInterface.h`
so the next upgrade can find the same pattern.

### 7.5 Never check in the `build/` directory

`.gitignore` already handles this, but double-check after every
`ninja` run before `git add`.

---

## 8. Quick reference — common commands

```bash
# Configure (first time / after CMakeLists change)
MLIR_DIR=/opt/homebrew/opt/llvm/lib/cmake/mlir \
LLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm \
  cmake -S . -B build -G Ninja

# Incremental build
ninja -C build

# Build specific target
ninja -C build enigma-opt
ninja -C build enigma-translate
ninja -C build enigma-runner

# Round-trip the dialect
./build/tools/enigma-opt/enigma-opt test/Dialect/Enigma/roundtrip.mlir

# Emit MSL
./build/tools/enigma-translate/enigma-translate --enigma-to-msl \
  test/Target/MSL/vector_add.mlir

# Full end-to-end
./build/tools/enigma-translate/enigma-translate --enigma-to-msl \
  test/Target/MSL/vector_add.mlir -o /tmp/enigma_vector_add.metal
xcrun -sdk macosx metal -c /tmp/enigma_vector_add.metal -o /tmp/enigma_vector_add.air
xcrun -sdk macosx metallib /tmp/enigma_vector_add.air   -o /tmp/enigma_vector_add.metallib
./build/tools/enigma-runner/enigma-runner /tmp/enigma_vector_add.metallib vector_add

# Clean rebuild from scratch
rm -rf build && <re-run the configure command>
```

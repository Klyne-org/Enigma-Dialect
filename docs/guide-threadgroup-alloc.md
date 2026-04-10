# How to Add `enigma.threadgroup_alloc`

A step-by-step guide. No prior MLIR experience needed beyond what you've
already seen in the codebase.

---

## What is threadgroup memory?

On a GPU, threads are grouped into **threadgroups** (Apple's word for
"blocks"). All threads in a threadgroup can share a small, fast chunk of
memory called **threadgroup memory**. Think of it like a shared scratchpad.

In Metal Shading Language (MSL), you declare it like this:

```metal
kernel void reduce(device float* input [[buffer(0)]],
                   device float* output [[buffer(1)]],
                   uint tid [[thread_position_in_threadgroup]],
                   uint gid [[thread_position_in_grid]]) {
    // This line allocates 256 floats of shared memory
    threadgroup float scratch[256];

    scratch[tid] = input[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // ... now all threads can read each other's values from scratch ...
}
```

Your job: make this expressible in Enigma IR, so the emitter can spit out
that `threadgroup float scratch[256];` line.

---

## What the MLIR should look like

Before you write any code, decide what the `.mlir` syntax should be.
Here's a good target:

```mlir
enigma.kernel @reduce(%input: memref<?xf32>, %output: memref<?xf32>) {
    %scratch = enigma.threadgroup_alloc : memref<256xf32, 2>
    //                                    ^^^^^^^^^^^^^^^^
    //                                    fixed-size, address space 2 = threadgroup

    %tid = enigma.thread_position_in_threadgroup x
    %gid = enigma.thread_position_in_grid x
    %val = memref.load %input[%gid] : memref<?xf32>
    memref.store %val, %scratch[%tid] : memref<256xf32, 2>
    enigma.threadgroup_barrier 2
    // ... reduction logic ...
    enigma.return
}
```

Key decisions already made:
- The op takes **no inputs** (the size comes from the result type)
- The op returns a **memref with a static shape** (e.g. `memref<256xf32, 2>`)
- Memory space **must be 2** (threadgroup) — anything else is a bug

---

## Step 1: Define the op in the `.td` file

Open `include/enigma/Dialect/Enigma/IR/EnigmaOps.td`.

Find the section with `enigma.threadgroup_barrier` (around line 240-ish).
Add your new op **right after it**, before the `NEXT STEPS` comment block.

Here's what to paste:

```tablegen
def Enigma_ThreadgroupAllocOp : Enigma_Op<"threadgroup_alloc", []> {
  let summary = "Allocate threadgroup-shared memory";

  let description = [{
    Allocates a fixed-size block of threadgroup memory. The result type
    must be a statically-shaped memref in address space 2 (threadgroup).

    Example:
    ```mlir
    %buf = enigma.threadgroup_alloc : memref<256xf32, 2>
    ```
  }];

  // No inputs — the shape comes entirely from the result type.
  let arguments = (ins);

  // Returns a memref. "AnyMemRef" means MLIR won't constrain the shape
  // or element type at the tablegen level. We'll add a verifier to check
  // that the memory space is 2.
  let results = (outs AnyMemRef:$result);

  // The assembly format: just print the result type after a colon.
  // `attr-dict` is required by MLIR (it prints any extra attributes).
  let assemblyFormat = "attr-dict `:` type($result)";

  // We want a custom verifier to reject non-threadgroup memory spaces.
  let hasVerifier = 1;
}
```

### What each piece means

| Line | What it does |
|------|-------------|
| `Enigma_Op<"threadgroup_alloc", []>` | Creates `enigma.threadgroup_alloc`. The `[]` means no traits. |
| `let arguments = (ins)` | No operands — nothing goes in. |
| `let results = (outs AnyMemRef:$result)` | One output: a memref. |
| `let assemblyFormat = ...` | Tells tablegen how to parse/print. You don't need custom C++. |
| `let hasVerifier = 1` | Tells tablegen you'll write a `verify()` method in C++. |

---

## Step 2: Write the verifier

Open `lib/Dialect/Enigma/IR/EnigmaDialect.cpp`.

Add this method **after** the `KernelOp::parse` function (at the bottom of
the file):

```cpp
//===----------------------------------------------------------------------===//
// enigma.threadgroup_alloc — verifier
//===----------------------------------------------------------------------===//

LogicalResult ThreadgroupAllocOp::verify() {
  auto memrefType = cast<MemRefType>(getResult().getType());

  // Check 1: must be in address space 2 (threadgroup).
  unsigned memSpace = 0;
  if (auto ms = memrefType.getMemorySpace()) {
    if (auto intAttr = dyn_cast<IntegerAttr>(ms))
      memSpace = intAttr.getInt();
  }
  if (memSpace != 2) {
    return emitOpError("result must be in address space 2 (threadgroup), "
                       "but got address space ")
           << memSpace;
  }

  // Check 2: must have a static (known) shape. You can't allocate a
  // dynamically-sized threadgroup buffer — the size must be known at
  // compile time.
  if (!memrefType.hasStaticShape()) {
    return emitOpError("result must have a static shape — threadgroup "
                       "memory size must be known at compile time");
  }

  return success();
}
```

### What this does

When someone writes bad IR like:

```mlir
%bad = enigma.threadgroup_alloc : memref<256xf32>       // wrong: no address space
%bad = enigma.threadgroup_alloc : memref<256xf32, 0>    // wrong: device, not threadgroup
%bad = enigma.threadgroup_alloc : memref<?xf32, 2>      // wrong: dynamic shape (the ?)
```

The verifier catches it and prints a helpful error instead of silently
generating broken MSL.

---

## Step 3: Add the emitter case

Open `lib/Target/MSL/MSLEmitter.cpp`.

### 3a. Add to the dispatch chain

Find the `emitOp` function (the big `if/else if` chain). Add a new case
**after** the `ThreadgroupBarrierOp` case:

```cpp
    if (auto alloc = dyn_cast<ThreadgroupAllocOp>(op))
      return emitThreadgroupAlloc(alloc);
```

### 3b. Write the emission method

Add this new method alongside the other `emit*` methods (after
`emitThreadgroupBarrier` is a good spot):

```cpp
  void emitThreadgroupAlloc(ThreadgroupAllocOp op) {
    auto memrefType = cast<MemRefType>(op.getResult().getType());
    llvm::StringRef elem = getTypeString(memrefType.getElementType());

    // Get the total number of elements. For memref<256xf32, 2> this is 256.
    int64_t numElements = 1;
    for (int64_t dim : memrefType.getShape())
      numElements *= dim;

    // Emit: threadgroup float scratch[256];
    os << "    threadgroup " << elem << " "
       << getName(op.getResult())
       << "[" << numElements << "];\n";
  }
```

This turns `%buf = enigma.threadgroup_alloc : memref<256xf32, 2>` into:

```metal
    threadgroup float v3[256];
```

---

## Step 4: Rebuild

```bash
ninja -C build
```

If you get errors:
- **"unknown type name ThreadgroupAllocOp"** — you probably forgot to
  rebuild after changing the `.td` file, or there's a typo in the op name.
- **"verify() not found"** — make sure you added `let hasVerifier = 1;`
  in the `.td` and spelled the method `ThreadgroupAllocOp::verify()` exactly.

---

## Step 5: Test by hand first

Before writing proper tests, just try it:

Create a file `/tmp/tg_test.mlir`:

```mlir
module {
  enigma.kernel @tg_test(%input: memref<?xf32>, %output: memref<?xf32>) {
    %scratch = enigma.threadgroup_alloc : memref<256xf32, 2>
    %tid = enigma.thread_position_in_threadgroup x
    %gid = enigma.thread_position_in_grid x
    %val = memref.load %input[%gid] : memref<?xf32>
    memref.store %val, %scratch[%tid] : memref<256xf32, 2>
    enigma.threadgroup_barrier 2
    enigma.return
  }
}
```

Run these one at a time:

```bash
# Does it parse?
./build/tools/enigma-opt/enigma-opt /tmp/tg_test.mlir

# Does it round-trip? (parse -> print -> parse -> print)
./build/tools/enigma-opt/enigma-opt /tmp/tg_test.mlir | ./build/tools/enigma-opt/enigma-opt

# Does the MSL look right?
./build/tools/enigma-translate/enigma-translate --enigma-to-msl /tmp/tg_test.mlir

# Does the MSL actually compile? (THE ORACLE)
./build/tools/enigma-translate/enigma-translate --enigma-to-msl /tmp/tg_test.mlir \
  | xcrun -sdk macosx metal -c -x metal - -o /dev/null
```

If all four pass, you're good. If `xcrun metal` rejects the MSL, look at
the emitter output and compare it to what valid MSL should look like.

Also test that the verifier catches bad input:

```bash
# This should print an error (wrong address space):
echo 'module { enigma.kernel @bad(%a: memref<?xf32>) { %x = enigma.threadgroup_alloc : memref<256xf32, 0> enigma.return } }' \
  | ./build/tools/enigma-opt/enigma-opt
```

You should see something like:
```
error: 'enigma.threadgroup_alloc' op result must be in address space 2 (threadgroup), but got address space 0
```

---

## Step 6: Write the lit tests

### 6a. Round-trip test

Add to `test/Dialect/Enigma/roundtrip.mlir` (at the bottom):

```mlir
// CHECK-LABEL: enigma.kernel @threadgroup_alloc_test
enigma.kernel @threadgroup_alloc_test(%input: memref<?xf32>) {
  // CHECK: enigma.threadgroup_alloc : memref<256xf32, 2>
  %buf = enigma.threadgroup_alloc : memref<256xf32, 2>
  %tid = enigma.thread_position_in_threadgroup x
  %val = memref.load %input[%tid] : memref<?xf32>
  memref.store %val, %buf[%tid] : memref<256xf32, 2>
  enigma.threadgroup_barrier 2
  enigma.return
}
```

### 6b. MSL emission test

Create `test/Target/MSL/threadgroup_alloc.mlir`:

```mlir
// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void tg_alloc_demo(
// CHECK:         device float* v0 [[buffer(0)]],
// CHECK:         uint _tid [[thread_position_in_grid]]
// CHECK:       ) {

// The threadgroup allocation line:
// CHECK:         threadgroup float v{{[0-9]+}}[256];

// CHECK:       }

module {
  enigma.kernel @tg_alloc_demo(%input: memref<?xf32>) {
    %scratch = enigma.threadgroup_alloc : memref<256xf32, 2>
    %tid = enigma.thread_position_in_grid x
    %val = memref.load %input[%tid] : memref<?xf32>
    memref.store %val, %scratch[%tid] : memref<256xf32, 2>
    enigma.threadgroup_barrier 2
    enigma.return
  }
}
```

### 6c. Verifier rejection test (optional but good practice)

Create `test/Dialect/Enigma/threadgroup_alloc_verify.mlir`:

```mlir
// RUN: enigma-opt %s -verify-diagnostics

module {
  enigma.kernel @bad_addr_space(%a: memref<?xf32>) {
    // expected-error @+1 {{result must be in address space 2 (threadgroup)}}
    %x = enigma.threadgroup_alloc : memref<256xf32, 0>
    enigma.return
  }
}
```

This tests that your verifier correctly rejects wrong address spaces.

---

## Step 7: Run all the tests

```bash
ninja -C build

# Run your new tests individually:
./build/tools/enigma-opt/enigma-opt test/Dialect/Enigma/roundtrip.mlir | ./build/tools/enigma-opt/enigma-opt
./build/tools/enigma-translate/enigma-translate --enigma-to-msl test/Target/MSL/threadgroup_alloc.mlir

# Oracle check:
./build/tools/enigma-translate/enigma-translate --enigma-to-msl test/Target/MSL/threadgroup_alloc.mlir \
  | xcrun -sdk macosx metal -c -x metal - -o /dev/null
```

If everything passes with zero errors, you're done. Commit it.

---

## Recap: files you'll touch

| File | What to do |
|------|-----------|
| `include/enigma/Dialect/Enigma/IR/EnigmaOps.td` | Add the `Enigma_ThreadgroupAllocOp` def |
| `lib/Dialect/Enigma/IR/EnigmaDialect.cpp` | Add the `ThreadgroupAllocOp::verify()` method |
| `lib/Target/MSL/MSLEmitter.cpp` | Add dispatch case + `emitThreadgroupAlloc()` method |
| `test/Dialect/Enigma/roundtrip.mlir` | Add round-trip CHECK block |
| `test/Target/MSL/threadgroup_alloc.mlir` | New file — MSL emission test |
| `test/Dialect/Enigma/threadgroup_alloc_verify.mlir` | New file — verifier rejection test |

---

## Common mistakes to watch for

1. **Forgetting `let hasVerifier = 1`** in the `.td` — your `verify()` method
   will never get called and bad IR will silently pass through.

2. **Wrong address space number** — remember: 0=device, 1=constant,
   **2=threadgroup**, 3=thread. It's easy to mix these up.

3. **Forgetting to add the dispatch case in `emitOp`** — your op will
   parse and round-trip fine but emit `// UNHANDLED: enigma.threadgroup_alloc`
   in the MSL output instead of actual code.

4. **Not running `xcrun metal`** — the emitted MSL might look right to your
   eyes but have a syntax error. Always run the oracle.

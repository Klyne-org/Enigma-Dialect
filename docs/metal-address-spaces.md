# Metal Address Spaces in Enigma

Metal GPUs partition memory into four address spaces, each with different
visibility, mutability, and performance characteristics. Enigma encodes
these as integer memory space values on `memref` types.

---

## The four address spaces

| Value | MSL qualifier   | Scope                        | Read/Write | Allocated by   |
|-------|-----------------|------------------------------|------------|----------------|
| 0     | `device`        | All threads on the GPU       | Read/Write | Host (MTLBuffer) |
| 1     | `constant`      | All threads on the GPU       | Read-only  | Host (MTLBuffer) |
| 2     | `threadgroup`   | Threads in one threadgroup   | Read/Write | Kernel (on-chip) |
| 3     | `thread`        | Single thread only           | Read/Write | Compiler (stack) |

### Address space 0 — `device`

Global GPU memory. The host allocates an `MTLBuffer`, fills it with data,
and passes it to the kernel via `setBuffer:offset:atIndex:`. In Enigma IR
this is the default — a bare `memref<?xf32>` has address space 0.

```mlir
// device buffer passed from host
enigma.kernel @example(%buf: memref<?xf32>) { ... }
```

```metal
kernel void example(device float* buf [[buffer(0)]]) { ... }
```

You **cannot** allocate device memory inside a kernel. It must come from
the host.

### Address space 1 — `constant`

Identical to device memory in terms of visibility, but **read-only** and
optimized for broadcast access patterns (all threads reading the same
value). The GPU hardware can cache constant data more aggressively.

```mlir
enigma.kernel @example(%weights: memref<?xf32, 1>) { ... }
```

```metal
kernel void example(constant float* weights [[buffer(0)]]) { ... }
```

You **cannot** allocate or write to constant memory inside a kernel.

### Address space 2 — `threadgroup`

Fast on-chip memory shared by all threads within a single threadgroup
(Apple's term for a CUDA "block"). On Apple GPUs this is backed by
**tile memory**, which has much lower latency than device memory.

This is the only address space that can be allocated inside a kernel body:

```mlir
%scratch = enigma.threadgroup_alloc : memref<256xf32, 2>
```

```metal
threadgroup float scratch[256];
```

Key properties:
- **Shared**: all threads in the threadgroup see the same data
- **Requires synchronization**: use `threadgroup_barrier` after writes
  before other threads read
- **Fixed size**: the allocation size must be known at compile time
- **Scoped lifetime**: exists only for the duration of the threadgroup's
  execution

This is essential for reductions, prefix scans, convolution tiling, and
any algorithm where threads need to cooperate.

### Address space 3 — `thread`

Private to a single thread. This is what local variables in MSL use by
default. Rarely specified explicitly, but needed when passing a pointer
to a stack variable.

```metal
thread float local_val = 0.0;
```

Thread memory is **invisible** to other threads — writes by one thread
can never be read by another.

---

## Why `enigma.threadgroup_alloc` enforces address space 2

The `threadgroup_alloc` op only makes sense with address space 2. Using
any other value is a bug:

| Space | What goes wrong |
|-------|----------------|
| 0 (`device`) | **Illegal MSL.** Device memory is host-allocated. `device float scratch[256];` inside a kernel is a compile error. |
| 1 (`constant`) | **Illegal MSL.** Constant memory is host-allocated and read-only. Cannot be declared or written inside a kernel. |
| 2 (`threadgroup`) | Correct. Shared, writable, kernel-allocated. |
| 3 (`thread`) | **Wrong semantics.** Compiles, but each thread gets a private copy. A reduction writing `scratch[tid]` and reading `scratch[other_tid]` silently reads garbage — other threads' writes are invisible. This is a correctness bug that produces no compiler error. |

The verifier in `ThreadgroupAllocOp::verify()` rejects anything other
than address space 2 to prevent both compile-time and silent runtime
failures.

---

## How the emitter maps address spaces to MSL

The MSL emitter reads the integer memory space from the `memref` type and
produces the corresponding MSL qualifier:

| memref type              | Emitted MSL parameter            |
|--------------------------|----------------------------------|
| `memref<?xf32>`          | `device float* v0 [[buffer(N)]]` |
| `memref<?xf32, 1>`       | `constant float* v0 [[buffer(N)]]` |
| `memref<256xf32, 2>`     | `threadgroup float v0[256];` (local declaration, not a parameter) |

Address space 2 is special: it does not appear in the kernel signature.
Instead, the emitter produces a local `threadgroup` variable declaration
inside the kernel body.

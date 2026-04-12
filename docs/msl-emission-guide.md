# MSL Emission Guide

How the Enigma dialect MLIR lowers to Metal Shading Language text via `enigma-translate --enigma-to-msl`.

## Architecture

```
MLIR Input (.mlir)
       |
       v
  enigma-translate
       |
       v
  MSLEmitter (lib/Target/MSL/)
       |
       v
  MSL Source (.metal)
       |
       v
  xcrun metal -c  (Apple Metal compiler)
       |
       v
  .metallib  (GPU binary)
```

## Emitter Module Map

| File | Handles |
|------|---------|
| `MSLEmitterCore.cpp` | Dispatch loop, kernel/vertex/fragment signatures, name management, type mapping, builtin scanning, registration |
| `MSLEmitterThread.cpp` | `enigma.thread_position_in_grid`, all 12 indexing builtins, `vertex_id`, `instance_id` |
| `MSLEmitterSync.cpp` | `enigma.threadgroup_barrier`, `enigma.simdgroup_barrier`, `enigma.threadgroup_alloc` |
| `MSLEmitterSimd.cpp` | All `enigma.simd_*` ops (reductions, scans, shuffles, broadcast) |
| `MSLEmitterAtomic.cpp` | All `enigma.atomic_*` ops (load, store, exchange, CAS, fetch-and-modify) |
| `MSLEmitterMath.cpp` | All `enigma.*` math built-ins (24 unary, 7 binary, 4 ternary) with precision support |
| `MSLEmitterInt.cpp` | Integer intrinsics: `popcount`, `clz`, `ctz`, `reverse_bits`, `extract_bits`, `insert_bits`, `add_sat`, etc. |
| `MSLEmitterGeom.cpp` | Geometric functions: `dot`, `cross`, `length`, `distance`, `normalize`, `reflect`, `refract`, `faceforward` |
| `MSLEmitterTexture.cpp` | Texture `read`/`write`/`sample` + dimension queries |
| `MSLEmitterCast.cpp` | `metal_cast` (static_cast), `as_type` (reinterpret) |
| `MSLEmitterUpstream.cpp` | `arith.*` (binops, constants, casts), `memref.load`/`store`, vertex/fragment returns |

## How Kernel Signature Emission Works

1. **Pre-scan**: Walk the kernel body collecting all `Enigma_ThreadIndexOp` uses into `usedBuiltins`.
2. **Emit function args**: Each `memref` kernel argument becomes `<addr_space> <elem>* vN [[buffer(N)]]`.
3. **Emit builtin params**: For each entry in `usedBuiltins`, emit `uint3 _name [[builtin_name]]` (or `uint` for flat builtins).
4. **Emit body**: Walk ops top-down, dispatching each through `emitOp()`.

## How Thread Index Plumbing Works

MSL requires thread-position builtins as `[[...]]` kernel parameters, not function calls. The emitter:

1. Scans the body for all `enigma.thread_position_in_grid` (and similar) ops.
2. Injects `uint3 _tpg [[thread_position_in_grid]]` into the kernel signature.
3. Replaces `%id = enigma.thread_position_in_grid x` with `uint vN = _tpg.x;`.

This means builtins that are never used in a kernel are never emitted in its signature — keeping the MSL clean.

## How to Add a New Op

1. **Define the op** in the appropriate `include/.../Enigma*.td` file.
2. **Add dispatch** in `MSLEmitterCore.cpp::emitOp()`.
3. **Implement emission** in the appropriate `MSLEmitter*.cpp` file.
4. **Add a roundtrip test** in `test/Dialect/Enigma/roundtrip.mlir`.
5. **Add an MSL emission test** in `test/Target/MSL/*.mlir`.
6. **Rebuild**: `ninja -C build && ninja -C build check-enigma`.

## Type Mapping Rules

| MLIR Type | MSL Type |
|-----------|----------|
| `f16` | `half` |
| `f32` | `float` |
| `bf16` | `bfloat` |
| `i1` | `bool` |
| `i8` | `char` |
| `i16` | `short` |
| `i32` | `int` |
| `i64` | `long` |
| `index` | `uint` |
| `vector<Nxf32>` | `floatN` |
| `vector<Nxf16>` | `halfN` |
| `vector<Nxi32>` | `intN` |

## Address Space Mapping

| memref memory space | MSL qualifier | Typical use |
|-------------------|--------------|-------------|
| 0 (default) | `device` | Read/write GPU buffers |
| 1 | `constant` | Read-only lookup tables, weights |
| 2 | `threadgroup` | Shared scratch within threadgroup |
| 3 | `thread` | Per-thread private (rare — locals are thread by default) |

## Math Precision Prefixes

When the `precision` attribute is set on math ops:

| Precision | MSL Prefix | Trade-off |
|-----------|-----------|-----------|
| `default_precision` | *(none)* | Metal default (implementation-defined) |
| `fast` | `fast::` | Max throughput, reduced accuracy |
| `precise` | `precise::` | IEEE-754 compliant, slower |

Example: `enigma.sin %x {precision = fast} : f32` emits `fast::sin(v0)`.

## Atomic Emission Pattern

All atomics follow the pattern:
```
atomic_*_explicit(
    (device atomic_<type>*)&buffer[index],
    value,
    memory_order_*
)
```

The `(device atomic_<type>*)&` cast is necessary because Metal atomics operate on `atomic_*` types, but our buffers are plain typed pointers.

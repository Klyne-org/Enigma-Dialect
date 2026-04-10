# Enigma Dialect Reference

Complete reference for the Enigma MLIR dialect — a 1:1 mapping of Apple Metal Shading Language (MSL) constructs into MLIR.

## Table of Contents

- [Enums](#enums)
- [Function Entry Points](#function-entry-points)
- [Thread Indexing Builtins](#thread-indexing-builtins)
- [Synchronization & Threadgroup Memory](#synchronization--threadgroup-memory)
- [SIMD Group Operations](#simd-group-operations)
- [Atomic Operations](#atomic-operations)
- [Math Built-ins (Float)](#math-built-ins-float)
- [Integer Intrinsics](#integer-intrinsics)
- [Geometric / Vector Operations](#geometric--vector-operations)
- [Texture Operations](#texture-operations)
- [Cast Operations](#cast-operations)
- [Relational / Select / Integer Min-Max-Clamp](#relational--select--integer-min-max-clamp)
- [Quad Group Operations](#quad-group-operations)
- [Function Constants](#function-constants)
- [Control Flow (via SCF Dialect)](#control-flow-via-scf-dialect)
- [Pack / Unpack Operations](#pack--unpack-operations)
- [Matrix Operations](#matrix-operations)
- [Comparison Emission (arith dialect)](#comparison-emission-arith-dialect)
- [Module Layout](#module-layout)

---

## Enums

### AddressSpace
Metal's four memory address spaces, encoded as memref memory space integers.

| Value | Name | MSL Qualifier | Description |
|-------|------|--------------|-------------|
| 0 | `device` | `device` | GPU-wide read/write (default) |
| 1 | `constant` | `constant` | Read-only, broadcast-optimized |
| 2 | `threadgroup` | `threadgroup` | Shared within threadgroup (tile memory) |
| 3 | `thread` | `thread` | Private per-thread (stack) |

Usage: `memref<?xf32>` = device, `memref<?xf32, 1>` = constant, `memref<256xf32, 2>` = threadgroup.

### Dimension
Axis selector for thread-position builtins.

| Value | Name |
|-------|------|
| 0 | `x` |
| 1 | `y` |
| 2 | `z` |

### MemFlags
Barrier memory flags controlling which memory writes become visible.

| Value | Name | MSL |
|-------|------|-----|
| 0 | `mem_none` | `mem_flags::mem_none` |
| 1 | `mem_device` | `mem_flags::mem_device` |
| 2 | `mem_threadgroup` | `mem_flags::mem_threadgroup` |
| 3 | `mem_device_and_threadgroup` | `mem_flags::mem_device_and_threadgroup` |
| 4 | `mem_texture` | `mem_flags::mem_texture` |

### MemoryOrder
Atomic operation memory ordering.

| Value | Name | MSL |
|-------|------|-----|
| 0 | `relaxed` | `memory_order_relaxed` |
| 1 | `acquire` | `memory_order_acquire` |
| 2 | `release` | `memory_order_release` |
| 3 | `acq_rel` | `memory_order_acq_rel` |

### MathPrecision
Controls accuracy vs throughput for GPU math built-ins.

| Value | Name | MSL Prefix |
|-------|------|-----------|
| 0 | `default_precision` | *(none)* |
| 1 | `fast` | `fast::` |
| 2 | `precise` | `precise::` |

### TextureAccess / SamplerFilter / SamplerAddress
See [Texture Operations](#texture-operations) section.

---

## Function Entry Points

### `enigma.kernel`
Compute kernel entry point. Maps to `kernel void name(...)` in MSL.

```mlir
enigma.kernel @name(%arg0: type0, ...) {
  // body
  enigma.return
}
```

### `enigma.vertex`
Vertex shader entry point. Maps to `vertex RetType name(...)` in MSL.

```mlir
enigma.vertex @name(%arg0: type0, ...) -> RetType {
  // body
  enigma.vertex_return %result : RetType
}
```

### `enigma.fragment`
Fragment shader entry point. Maps to `fragment RetType name(...)` in MSL.

```mlir
enigma.fragment @name(%arg0: type0, ...) -> RetType {
  // body
  enigma.fragment_return %result : RetType
}
```

### `enigma.return` / `enigma.vertex_return` / `enigma.fragment_return`
Terminators for the above entry points.

---

## Thread Indexing Builtins

All thread-index ops are `Pure`, take a `Dimension` attribute (`x`/`y`/`z`), and return `index`. The MSL emitter injects the corresponding `[[...]]` parameter into the kernel signature.

| Op | MSL Builtin | Description |
|----|-------------|-------------|
| `enigma.thread_position_in_grid` | `[[thread_position_in_grid]]` | Global thread id |
| `enigma.threadgroup_position_in_grid` | `[[threadgroup_position_in_grid]]` | Threadgroup (block) id |
| `enigma.thread_position_in_threadgroup` | `[[thread_position_in_threadgroup]]` | Local thread id within threadgroup |
| `enigma.threads_per_threadgroup` | `[[threads_per_threadgroup]]` | Threadgroup dimensions |
| `enigma.thread_index_in_threadgroup` | `[[thread_index_in_threadgroup]]` | Flat local thread index |
| `enigma.threadgroups_per_grid` | `[[threadgroups_per_grid]]` | Number of threadgroups |
| `enigma.threads_per_grid` | `[[threads_per_grid]]` | Total grid threads |
| `enigma.grid_size` | `[[grid_size]]` | Grid dimensions |
| `enigma.simdgroup_index_in_threadgroup` | `[[simdgroup_index_in_threadgroup]]` | SIMD group index |
| `enigma.thread_index_in_simdgroup` | `[[thread_index_in_simdgroup]]` | Lane index within SIMD group |
| `enigma.threads_per_simdgroup` | `[[threads_per_simdgroup]]` | Lanes per SIMD group (usually 32) |
| `enigma.simdgroups_per_threadgroup` | `[[simdgroups_per_threadgroup]]` | SIMD groups per threadgroup |

Vertex/Fragment-specific:

| Op | MSL Builtin | Description |
|----|-------------|-------------|
| `enigma.vertex_id` | `[[vertex_id]]` | Current vertex index |
| `enigma.instance_id` | `[[instance_id]]` | Current instance index |

```mlir
%gid = enigma.thread_position_in_grid x       // uint3 _tpg.x
%lid = enigma.thread_position_in_threadgroup y // uint3 _tpt.y
%vid = enigma.vertex_id                        // uint _vid
```

---

## Synchronization & Threadgroup Memory

### `enigma.threadgroup_barrier`
Synchronize all threads in a threadgroup.

```mlir
enigma.threadgroup_barrier mem_threadgroup
```
MSL: `threadgroup_barrier(mem_flags::mem_threadgroup);`

### `enigma.simdgroup_barrier`
Synchronize threads within a SIMD group only.

```mlir
enigma.simdgroup_barrier mem_device
```
MSL: `simdgroup_barrier(mem_flags::mem_device);`

### `enigma.threadgroup_alloc`
Allocate shared memory in threadgroup address space.

```mlir
%shared = enigma.threadgroup_alloc : memref<256xf32, 2>
```
MSL: `threadgroup float shared[256];`

---

## SIMD Group Operations

SIMD (Single Instruction, Multiple Data) operations execute across all lanes of a SIMD group (32 threads on Apple GPUs).

### Reductions
Reduce a value across all SIMD lanes:

```mlir
%sum  = enigma.simd_sum %val : f32       // simd_sum(val)
%prod = enigma.simd_product %val : f32   // simd_product(val)
%min  = enigma.simd_min %val : f32       // simd_min(val)
%max  = enigma.simd_max %val : f32       // simd_max(val)
```

### Bitwise Reductions (integer only)
```mlir
%and = enigma.simd_and %val : i32  // simd_and(val)
%or  = enigma.simd_or %val : i32   // simd_or(val)
%xor = enigma.simd_xor %val : i32  // simd_xor(val)
```

### Prefix Scans
```mlir
%pxs = enigma.simd_prefix_exclusive_sum %val : f32     // simd_prefix_exclusive_sum(val)
%pis = enigma.simd_prefix_inclusive_sum %val : f32     // simd_prefix_inclusive_sum(val)
%pxp = enigma.simd_prefix_exclusive_product %val : f32 // simd_prefix_exclusive_product(val)
%pip = enigma.simd_prefix_inclusive_product %val : f32 // simd_prefix_inclusive_product(val)
```

### Shuffles
Exchange data between SIMD lanes without shared memory:

```mlir
%v = enigma.simd_shuffle %val, %lane : f32           // simd_shuffle(val, lane)
%v = enigma.simd_shuffle_up %val, %delta : f32       // simd_shuffle_up(val, delta)
%v = enigma.simd_shuffle_down %val, %delta : f32     // simd_shuffle_down(val, delta)
%v = enigma.simd_shuffle_xor %val, %mask : f32       // simd_shuffle_xor(val, mask)
%v = enigma.simd_broadcast %val, %lane : f32         // simd_broadcast(val, lane)
```

---

## Atomic Operations

All atomics operate on device or threadgroup memory and require a memory ordering attribute.

### Load / Store
```mlir
%val = enigma.atomic_load %buf[%i] relaxed : memref<?xi32> -> i32
enigma.atomic_store %val, %buf[%i] release : i32, memref<?xi32>
```

### Exchange / Compare-Exchange
```mlir
%old = enigma.atomic_exchange %buf[%i], %new relaxed : memref<?xi32>, i32
%ok  = enigma.atomic_compare_exchange_weak %buf[%i], %expected, %desired acq_rel relaxed
           : memref<?xi32>, i32
```

### Fetch-and-Modify (RMW)
All return the *old* value before modification:

| Op | MSL Function |
|----|-------------|
| `enigma.atomic_fetch_add` | `atomic_fetch_add_explicit` |
| `enigma.atomic_fetch_sub` | `atomic_fetch_sub_explicit` |
| `enigma.atomic_fetch_min` | `atomic_fetch_min_explicit` |
| `enigma.atomic_fetch_max` | `atomic_fetch_max_explicit` |
| `enigma.atomic_fetch_and` | `atomic_fetch_and_explicit` |
| `enigma.atomic_fetch_or`  | `atomic_fetch_or_explicit` |
| `enigma.atomic_fetch_xor` | `atomic_fetch_xor_explicit` |

```mlir
%old = enigma.atomic_fetch_add %buf[%i], %val relaxed : memref<?xi32>, i32
```

---

## Math Built-ins (Float)

GPU-optimized math from `<metal_math>`. All support an optional `precision` attribute.

### Unary: `f(x) -> y`

| Op | MSL | Description |
|----|-----|-------------|
| `enigma.abs` | `abs(x)` | Absolute value |
| `enigma.ceil` | `ceil(x)` | Ceiling |
| `enigma.floor` | `floor(x)` | Floor |
| `enigma.round` | `rint(x)` | Round to nearest even |
| `enigma.trunc` | `trunc(x)` | Truncate toward zero |
| `enigma.sign` | `sign(x)` | Sign (-1/0/+1) |
| `enigma.saturate` | `saturate(x)` | Clamp to [0,1] |
| `enigma.fract` | `fract(x)` | Fractional part |
| `enigma.sqrt` | `sqrt(x)` | Square root |
| `enigma.rsqrt` | `rsqrt(x)` | 1/sqrt(x) |
| `enigma.exp` | `exp(x)` | e^x |
| `enigma.exp2` | `exp2(x)` | 2^x |
| `enigma.log` | `log(x)` | ln(x) |
| `enigma.log2` | `log2(x)` | log2(x) |
| `enigma.log10` | `log10(x)` | log10(x) |
| `enigma.sin` | `sin(x)` | Sine |
| `enigma.cos` | `cos(x)` | Cosine |
| `enigma.tan` | `tan(x)` | Tangent |
| `enigma.asin` | `asin(x)` | Arc sine |
| `enigma.acos` | `acos(x)` | Arc cosine |
| `enigma.atan` | `atan(x)` | Arc tangent |
| `enigma.sinh` | `sinh(x)` | Hyperbolic sine |
| `enigma.cosh` | `cosh(x)` | Hyperbolic cosine |
| `enigma.tanh` | `tanh(x)` | Hyperbolic tangent |

```mlir
%r = enigma.sin %v : f32                     // sin(v)       (default precision)
%r = enigma.sin %v {precision = fast} : f32  // fast::sin(v) (fast precision)
```

### Binary: `f(x, y) -> z`

| Op | MSL | Description |
|----|-----|-------------|
| `enigma.fmin` | `fmin(x,y)` | Float minimum |
| `enigma.fmax` | `fmax(x,y)` | Float maximum |
| `enigma.pow` | `pow(x,y)` | x^y |
| `enigma.fmod` | `fmod(x,y)` | Float modulus |
| `enigma.atan2` | `atan2(y,x)` | Two-arg arctangent |
| `enigma.step` | `step(edge,x)` | Step function |
| `enigma.copysign` | `copysign(x,y)` | Copy sign |

### Ternary: `f(a, b, c) -> d`

| Op | MSL | Description |
|----|-----|-------------|
| `enigma.clamp` | `clamp(x,lo,hi)` | Clamp to range |
| `enigma.fma` | `fma(a,b,c)` | Fused multiply-add |
| `enigma.mix` | `mix(a,b,t)` | Linear interpolation |
| `enigma.smoothstep` | `smoothstep(lo,hi,x)` | Hermite interpolation |

---

## Integer Intrinsics

### Unary
| Op | MSL | Description |
|----|-----|-------------|
| `enigma.popcount` | `popcount(x)` | Number of set bits |
| `enigma.clz` | `clz(x)` | Count leading zeros |
| `enigma.ctz` | `ctz(x)` | Count trailing zeros |
| `enigma.reverse_bits` | `reverse_bits(x)` | Reverse bit order |

### Binary
| Op | MSL | Description |
|----|-----|-------------|
| `enigma.abs_diff` | `abs_diff(a,b)` | \|a - b\| |
| `enigma.add_sat` | `add_sat(a,b)` | Saturating add |
| `enigma.sub_sat` | `sub_sat(a,b)` | Saturating subtract |
| `enigma.mul_hi` | `mul_hi(a,b)` | High bits of multiply |
| `enigma.rotate` | `rotate(a,b)` | Rotate left |

### Bit Manipulation
```mlir
%r = enigma.extract_bits %v 4 8 : i32           // extract_bits(v, 4, 8)
%r = enigma.insert_bits %base, %ins 4 8 : i32   // insert_bits(base, ins, 4, 8)
```

### Ternary
```mlir
%r = enigma.mad_sat %a, %b, %c : i32  // mad_sat(a, b, c) — clamp(a*b+c)
```

---

## Geometric / Vector Operations

Operate on MLIR `vector<Nxf32>` types.

| Op | Signature | MSL | Description |
|----|-----------|-----|-------------|
| `enigma.dot` | `vec, vec -> scalar` | `dot(a,b)` | Dot product |
| `enigma.cross` | `vec3, vec3 -> vec3` | `cross(a,b)` | Cross product |
| `enigma.length` | `vec -> scalar` | `length(v)` | Euclidean length |
| `enigma.distance` | `vec, vec -> scalar` | `distance(a,b)` | Distance |
| `enigma.normalize` | `vec -> vec` | `normalize(v)` | Unit vector |
| `enigma.reflect` | `vec, vec -> vec` | `reflect(I,N)` | Reflection |
| `enigma.refract` | `vec, vec, scalar -> vec` | `refract(I,N,eta)` | Refraction |
| `enigma.faceforward` | `vec, vec, vec -> vec` | `faceforward(N,I,Nref)` | Orient normal |

```mlir
%d = enigma.dot %a, %b : vector<3xf32> -> f32
%n = enigma.normalize %v : vector<3xf32>
%r = enigma.refract %inc, %normal, %eta : vector<3xf32>, f32
```

---

## Texture Operations

Textures are currently modeled using `memref` with coordinates as `index` values. A future version will add custom `!enigma.texture` types.

### `enigma.texture_read`
Read texel at integer coordinates.
```mlir
%val = enigma.texture_read %tex[%x, %y] : memref<?x?xvector<4xf32>> -> vector<4xf32>
```
MSL: `tex.read(uint2(x, y))`

### `enigma.texture_write`
Write texel at integer coordinates.
```mlir
enigma.texture_write %val, %tex[%x, %y] : vector<4xf32>, memref<?x?xvector<4xf32>>
```
MSL: `tex.write(val, uint2(x, y))`

### `enigma.texture_sample`
Sample with normalized coordinates and a sampler.
```mlir
%val = enigma.texture_sample %tex[%u, %v] filter linear address repeat
    : memref<?x?xvector<4xf32>> -> vector<4xf32>
```
MSL: `tex.sample(sampler(filter::linear, address::repeat), float2(u, v))`

### Queries
```mlir
%w = enigma.texture_get_width %tex : memref<?x?xvector<4xf32>>
%h = enigma.texture_get_height %tex : memref<?x?xvector<4xf32>>
```

---

## Cast Operations

### `enigma.metal_cast`
Static type cast (`static_cast<T>` in MSL).
```mlir
%f = enigma.metal_cast %i : i32 to f32
```

### `enigma.as_type`
Bitwise reinterpretation (`as_type<T>` in MSL). No conversion — bits are reinterpreted.
```mlir
%i = enigma.as_type %f : f32 to i32
```

### Pack/Unpack
```mlir
%packed   = enigma.pack_float_to_snorm2x16 %v : vector<2xf32>
%unpacked = enigma.unpack_snorm2x16_to_float %i : vector<2xf32>
```

---

## Module Layout

The `.td` definitions are split into focused modules:

```
include/enigma/Dialect/Enigma/IR/
├── EnigmaDialect.td    — dialect definition + Enigma_Op base class
├── EnigmaEnums.td      — all enum attributes
├── EnigmaFuncOps.td    — kernel / vertex / fragment / return
├── EnigmaThreadOps.td  — thread indexing builtins
├── EnigmaSyncOps.td    — barriers + threadgroup memory
├── EnigmaSimdOps.td    — SIMD group operations
├── EnigmaAtomicOps.td  — atomic operations
├── EnigmaMathOps.td    — GPU math built-ins
├── EnigmaIntOps.td     — integer intrinsics
├── EnigmaGeomOps.td    — geometric / vector functions
├── EnigmaTextureOps.td — texture read / write / sample
├── EnigmaCastOps.td    — type casts and packing
└── EnigmaOps.td        — master include (pulls everything together)
```

The MSL emitter is similarly modularized:

```
lib/Target/MSL/
├── MSLEmitterCore.cpp     — dispatch, registration, name/type mapping
├── MSLEmitterThread.cpp   — thread indexing emission
├── MSLEmitterSync.cpp     — barriers + threadgroup memory
├── MSLEmitterSimd.cpp     — SIMD operations
├── MSLEmitterAtomic.cpp   — atomic operations
├── MSLEmitterMath.cpp     — math built-ins
├── MSLEmitterInt.cpp      — integer intrinsics
├── MSLEmitterGeom.cpp     — geometric functions
├── MSLEmitterTexture.cpp  — texture operations
├── MSLEmitterCast.cpp         — type casts
├── MSLEmitterUpstream.cpp     — arith / memref / returns
├── MSLEmitterRelational.cpp   — comparison predicates, select, int min/max
├── MSLEmitterQuad.cpp         — quad group operations
├── MSLEmitterControlFlow.cpp  — scf.for/scf.if → Metal for/if, function constants
├── MSLEmitterPack.cpp         — pack/unpack operations
└── MSLEmitterMatrix.cpp       — matrix + simdgroup matrix operations
```

---

## Relational / Select / Integer Min-Max-Clamp

### Float Comparison Predicates

Test floating-point properties. Return `i1` (bool).

| Op | MSL Function | Description |
|----|-------------|-------------|
| `enigma.isnan %v : f32` | `isnan(v)` | True if NaN |
| `enigma.isinf %v : f32` | `isinf(v)` | True if infinity |
| `enigma.isfinite %v : f32` | `isfinite(v)` | True if finite |
| `enigma.signbit %v : f32` | `signbit(v)` | True if sign bit set |
| `enigma.isnormal %v : f32` | `isnormal(v)` | True if normal number |

### Select (Branchless Conditional)

```mlir
%r = enigma.select %false_val, %true_val, %cond : f32
```

Maps to `select(false_val, true_val, cond)` in MSL. Semantics: `cond ? true_val : false_val`.

### Integer Min / Max / Clamp

| Op | MSL Function | Description |
|----|-------------|-------------|
| `enigma.imin %x, %y : i32` | `min(x, y)` | Integer minimum |
| `enigma.imax %x, %y : i32` | `max(x, y)` | Integer maximum |
| `enigma.iclamp %x, %lo, %hi : i32` | `clamp(x, lo, hi)` | Integer clamp |

---

## Quad Group Operations

Quad group ops work on groups of 4 threads (2x2 pixel quads in fragment shaders).

### Reductions

| Op | MSL Function |
|----|-------------|
| `enigma.quad_sum %v : f32` | `quad_sum(v)` |
| `enigma.quad_product %v : f32` | `quad_product(v)` |
| `enigma.quad_min %v : f32` | `quad_min(v)` |
| `enigma.quad_max %v : f32` | `quad_max(v)` |

### Bitwise Reductions (Integer Only)

| Op | MSL Function |
|----|-------------|
| `enigma.quad_and %v : i32` | `quad_and(v)` |
| `enigma.quad_or %v : i32` | `quad_or(v)` |
| `enigma.quad_xor %v : i32` | `quad_xor(v)` |

### Shuffles

| Op | MSL Function |
|----|-------------|
| `enigma.quad_shuffle %v, %lane : f32` | `quad_shuffle(v, lane)` |
| `enigma.quad_broadcast %v, %lane : f32` | `quad_broadcast(v, lane)` |
| `enigma.quad_shuffle_down %v, %delta : f32` | `quad_shuffle_down(v, delta)` |
| `enigma.quad_shuffle_up %v, %delta : f32` | `quad_shuffle_up(v, delta)` |
| `enigma.quad_shuffle_xor %v, %mask : f32` | `quad_shuffle_xor(v, mask)` |

### Prefix Scans

| Op | MSL Function |
|----|-------------|
| `enigma.quad_prefix_exclusive_sum %v : f32` | `quad_prefix_exclusive_sum(v)` |
| `enigma.quad_prefix_inclusive_sum %v : f32` | `quad_prefix_inclusive_sum(v)` |

---

## Function Constants

Shader specialization constants set at pipeline creation time.

```mlir
%use_texture = enigma.function_constant 0 : i1
%mode = enigma.function_constant 1 : i32
```

Maps to `constant T name [[function_constant(N)]];` in MSL.

---

## Control Flow (via SCF Dialect)

The emitter translates SCF dialect ops directly to Metal control flow:

| MLIR | MSL |
|------|-----|
| `scf.for %iv = %lo to %hi step %s` | `for (int iv = lo; iv < hi; iv += s)` |
| `scf.if %cond` | `if (cond)` |
| `scf.yield` | loop-carried variable update |

Loop-carried variables (`iter_args`) are correctly handled with pre-loop initialization and in-loop updates.

---

## Pack / Unpack Operations

MSL `<metal_pack>` functions for packing float/half vectors into compact integer formats.

### Pack (vector → integer)

| Op | MSL Function | Input → Output |
|----|-------------|----------------|
| `enigma.pack_float_to_snorm4x8` | `pack_float_to_snorm4x8()` | `vector<4xf32>` → `i32` |
| `enigma.pack_float_to_unorm4x8` | `pack_float_to_unorm4x8()` | `vector<4xf32>` → `i32` |
| `enigma.pack_float_to_snorm2x16` | `pack_float_to_snorm2x16()` | `vector<2xf32>` → `i32` |
| `enigma.pack_float_to_unorm2x16` | `pack_float_to_unorm2x16()` | `vector<2xf32>` → `i32` |
| `enigma.pack_float_to_srgb_unorm4x8` | `pack_float_to_srgb_unorm4x8()` | `vector<4xf32>` → `i32` |
| `enigma.pack_float_to_unorm10a2` | `pack_float_to_unorm10a2()` | `vector<4xf32>` → `i32` |

### Unpack (integer → vector)

| Op | MSL Function | Input → Output |
|----|-------------|----------------|
| `enigma.unpack_snorm4x8_to_float` | `unpack_snorm4x8_to_float()` | `i32` → `vector<4xf32>` |
| `enigma.unpack_unorm4x8_to_float` | `unpack_unorm4x8_to_float()` | `i32` → `vector<4xf32>` |
| `enigma.unpack_snorm2x16_to_float` | `unpack_snorm2x16_to_float()` | `i32` → `vector<2xf32>` |
| `enigma.unpack_unorm2x16_to_float` | `unpack_unorm2x16_to_float()` | `i32` → `vector<2xf32>` |
| `enigma.unpack_srgb_unorm4x8_to_float` | `unpack_unorm4x8_srgb_to_float()` | `i32` → `vector<4xf32>` |
| `enigma.unpack_unorm10a2_to_float` | `unpack_unorm10a2_to_float()` | `i32` → `vector<4xf32>` |

---

## Matrix Operations

### Standard Matrix

| Op | MSL | Description |
|----|-----|-------------|
| `enigma.matmul %a, %b` | `A * B` | Matrix multiply |
| `enigma.transpose %m` | `transpose(m)` | Matrix transpose |
| `enigma.determinant %m` | `determinant(m)` | Matrix determinant |

### Simdgroup Matrix (Apple GPU, 8x8 tiles)

| Op | MSL Function | Description |
|----|-------------|-------------|
| `enigma.simdgroup_matrix_load %src, %stride` | `simdgroup_load(d, src, stride)` | Load 8x8 tile from memory |
| `enigma.simdgroup_matrix_store %mat, %dst, %stride` | `simdgroup_store(mat, dst, stride)` | Store 8x8 tile to memory |
| `enigma.simdgroup_multiply_accumulate %a, %b, %c` | `simdgroup_multiply_accumulate(d, a, b, c)` | d = a * b + c |
| `enigma.make_filled_simdgroup_matrix %val` | `make_filled_simdgroup_matrix<T,8,8>(val)` | Create filled 8x8 matrix |

---

## Comparison Emission (arith dialect)

The emitter now handles `arith.cmpf` and `arith.cmpi` directly:

| MLIR | MSL |
|------|-----|
| `arith.cmpf uge, %a, %b : f32` | `a >= b` |
| `arith.cmpf oeq, %a, %b : f32` | `a == b` |
| `arith.cmpi slt, %a, %b : i32` | `a < b` |
| `arith.cmpi eq, %a, %b : i32` | `a == b` |

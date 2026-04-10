# MSL Spec Function Signatures Reference

Source: Apple Metal SDK headers (Xcode toolchain `metal_integer`, `metal_relational`,
`metal_pack`, `metal_compute`, `metal_quadgroup`, `metal_simdgroup`, `metal_simdgroup_matrix`,
`metal_matrix`) + MSL Spec v4.

All functions live in `namespace metal`. Header: `<metal_stdlib>`.

---

## 1. Integer min/max/clamp

Header: `<metal_integer>` — overloaded for every scalar/vector integer type.

| MSL Function | Signature (generic) | Example |
|---|---|---|
| `min` | `T min(T x, T y)` | `int a = min(x, y);` |
| `max` | `T max(T x, T y)` | `int a = max(x, y);` |
| `clamp` | `T clamp(T x, T minval, T maxval)` | `int a = clamp(x, 0, 255);` |

**Concrete scalar types T:** `char`, `uchar`, `short`, `ushort`, `int`, `uint` (also `long`/`ulong` on some targets).
**Vector variants:** `T2`, `T3`, `T4` (e.g. `int2 min(int2, int2)`).

---

## 2. Select

Header: `<metal_relational>`

| MSL Function | Signature | Example |
|---|---|---|
| `select` | `T select(T a, T b, bool c)` | `float r = select(x, y, cond);` |
| `select` (vec) | `Tn select(Tn a, Tn b, booln c)` | `float4 r = select(a, b, mask);` |

**Semantics:** `result = c ? b : a` (note: `a` is false-value, `b` is true-value).

**Supported T:** `bool`, `char`, `uchar`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `half`, `float`, `bfloat` and all vector widths (2,3,4).

---

## 3. Comparison / Relational Functions

Header: `<metal_relational>`

| MSL Function | Signature (scalar) | Signature (vector) | Example |
|---|---|---|---|
| `isnan` | `bool isnan(float x)` | `booln isnan(floatn x)` | `if (isnan(val)) {...}` |
| `isinf` | `bool isinf(float x)` | `booln isinf(floatn x)` | `if (isinf(val)) {...}` |
| `isfinite` | `bool isfinite(float x)` | `booln isfinite(floatn x)` | `if (isfinite(val)) {...}` |
| `signbit` | `bool signbit(float x)` | `booln signbit(floatn x)` | `bool neg = signbit(val);` |
| `isnormal` | `bool isnormal(float x)` | `booln isnormal(floatn x)` | `if (isnormal(val)) {...}` |

**Supported float types:** `half`, `float`, `bfloat` (and `double` where available), plus all vector widths (2,3,4).

---

## 4. Memory Fences / Barriers

Header: `<metal_compute>`

**`mem_flags` enum:**
```cpp
enum class mem_flags {
  mem_none,
  mem_device,
  mem_threadgroup,
  mem_threadgroup_imageblock,  // iOS v2.0+
  mem_texture,                 // macOS v1.2+, iOS v2.0+
  mem_object_data              // mesh shaders
};
```

| MSL Function | Signature | Example |
|---|---|---|
| `threadgroup_barrier` | `void threadgroup_barrier(mem_flags flags)` | `threadgroup_barrier(mem_flags::mem_threadgroup);` |
| `simdgroup_barrier` | `void simdgroup_barrier(mem_flags flags)` | `simdgroup_barrier(mem_flags::mem_none);` |

**Note:** MSL does NOT have standalone `threadgroup_memory_fence()` / `device_memory_fence()` functions. Memory ordering is done through `threadgroup_barrier(mem_flags::mem_threadgroup)` and `threadgroup_barrier(mem_flags::mem_device)`. The barrier combines execution barrier + memory fence via the `mem_flags` argument.

---

## 5. Matrix Types

Header: `<metal_matrix>`

### Available types (`matrix<T, Cols, Rows>`):

**half-precision:**
`half2x2`, `half2x3`, `half2x4`, `half3x2`, `half3x3`, `half3x4`, `half4x2`, `half4x3`, `half4x4`

**single-precision:**
`float2x2`, `float2x3`, `float2x4`, `float3x2`, `float3x3`, `float3x4`, `float4x2`, `float4x3`, `float4x4`

**Convention:** `floatNxM` = N columns, M rows.

### Construction:
```cpp
// Diagonal (square matrices only):
float4x4 identity = float4x4(1.0f);

// From column vectors:
float3x3 m = float3x3(col0, col1, col2);

// From all elements (column-major order):
float2x2 m = float2x2(1.0, 2.0, 3.0, 4.0);
```

### Multiply:
```cpp
float4x4 C = A * B;        // matrix * matrix
float4 v = M * vec;         // matrix * vector
float4 v = vec * M;         // vector * matrix
```

### Matrix functions:

| MSL Function | Signature | Example |
|---|---|---|
| `determinant` | `float determinant(floatNxN)` / `half determinant(halfNxN)` | `float d = determinant(m);` |
| `transpose` | `floatMxN transpose(floatNxM)` / `halfMxN transpose(halfNxM)` | `float3x4 t = transpose(m4x3);` |

---

## 6. Simdgroup Matrix Ops

Header: `<metal_simdgroup_matrix>` — requires Apple GPU family (Apple Silicon).

### Types:
```cpp
typedef simdgroup_matrix<half, 8, 8>  simdgroup_half8x8;
typedef simdgroup_matrix<float, 8, 8> simdgroup_float8x8;
typedef simdgroup_matrix<bfloat, 8, 8> simdgroup_bfloat8x8;  // where available
```

Only 8x8 size is currently valid.

### Functions:

| MSL Function | Signature | Example |
|---|---|---|
| `simdgroup_load` | `void simdgroup_load(thread simdgroup_matrix<T,C,R> &d, const device T *src, ulong elements_per_row = C, ulong2 matrix_origin = ulong2(0,0), bool transpose_matrix = false)` | `simdgroup_float8x8 a; simdgroup_load(a, src_ptr, 16);` |
| `simdgroup_load` | `void simdgroup_load(thread simdgroup_matrix<T,C,R> &d, const threadgroup T *src, ulong elements_per_row = C, ulong2 matrix_origin = ulong2(0,0), bool transpose_matrix = false)` | `simdgroup_load(a, tg_ptr);` |
| `simdgroup_store` | `void simdgroup_store(simdgroup_matrix<T,C,R> a, device T *dst, ulong elements_per_row = C, ulong2 matrix_origin = ulong2(0,0), bool transpose_matrix = false)` | `simdgroup_store(a, dst_ptr, 16);` |
| `simdgroup_store` | `void simdgroup_store(simdgroup_matrix<T,C,R> a, threadgroup T *dst, ulong elements_per_row = C, ulong2 matrix_origin = ulong2(0,0), bool transpose_matrix = false)` | `simdgroup_store(a, tg_ptr);` |
| `simdgroup_multiply` | `void simdgroup_multiply(thread simdgroup_matrix<R,C2,R1> &d, simdgroup_matrix<T,K,R1> a, simdgroup_matrix<U,C2,K> b)` | `simdgroup_multiply(d, a, b);` |
| `simdgroup_multiply_accumulate` | `void simdgroup_multiply_accumulate(thread simdgroup_matrix<R,C2,R1> &d, simdgroup_matrix<T,K,R1> a, simdgroup_matrix<U,C2,K> b, simdgroup_matrix<V,C2,R1> c)` | `simdgroup_multiply_accumulate(d, a, b, c);` |
| `make_filled_simdgroup_matrix` | `simdgroup_matrix<T,C,R> make_filled_simdgroup_matrix<T,C,R>(U value)` | `auto z = make_filled_simdgroup_matrix<float,8,8>(0.0f);` |
| `operator*` | `simdgroup_matrix<T,C2,R1> operator*(simdgroup_matrix<T,K,R1> a, simdgroup_matrix<U,C2,K> b)` | `auto d = a * b;` |

---

## 7. Quad Group Ops

Header: `<metal_quadgroup>` — works on groups of 4 threads (2x2 fragment quads).

**T:** `half`, `float`, `char`, `uchar`, `short`, `ushort`, `int`, `uint` (and vector variants).
**T_int:** only integer scalar types for `and`/`or`/`xor`.

| MSL Function | Signature | Example |
|---|---|---|
| `quad_shuffle` | `T quad_shuffle(T data, ushort quad_lane_id)` | `float v = quad_shuffle(myVal, 2);` |
| `quad_broadcast` | `T quad_broadcast(T data, ushort broadcast_lane_id)` | `float v = quad_broadcast(myVal, 0);` |
| `quad_and` | `T quad_and(T data)` | `int r = quad_and(mask);` |
| `quad_or` | `T quad_or(T data)` | `int r = quad_or(mask);` |
| `quad_xor` | `T quad_xor(T data)` | `int r = quad_xor(mask);` |
| `quad_min` | `T quad_min(T data)` | `float m = quad_min(val);` |
| `quad_max` | `T quad_max(T data)` | `float m = quad_max(val);` |
| `quad_sum` | `T quad_sum(T data)` | `float s = quad_sum(val);` |
| `quad_product` | `T quad_product(T data)` | `float p = quad_product(val);` |
| `quad_shuffle_down` | `T quad_shuffle_down(T data, ushort delta)` | `float v = quad_shuffle_down(val, 1);` |
| `quad_shuffle_up` | `T quad_shuffle_up(T data, ushort delta)` | `float v = quad_shuffle_up(val, 1);` |
| `quad_shuffle_xor` | `T quad_shuffle_xor(T data, ushort mask)` | `float v = quad_shuffle_xor(val, 0x1);` |
| `quad_prefix_exclusive_sum` | `T quad_prefix_exclusive_sum(T data)` | `float s = quad_prefix_exclusive_sum(val);` |
| `quad_prefix_inclusive_sum` | `T quad_prefix_inclusive_sum(T data)` | `float s = quad_prefix_inclusive_sum(val);` |

---

## 8. Function Constants

Syntax: `[[function_constant(index)]]` attribute on `constant` address-space variables.

| Feature | Syntax | Example |
|---|---|---|
| Declaration | `constant T name [[function_constant(N)]];` | `constant bool useNormalMap [[function_constant(0)]];` |
| Derived | `constant bool c = (a == 1) && b;` | `constant int d = (a * 4);` |

**Allowed types:** scalar and vector types only (no arrays, no structs).

```cpp
// Full example:
constant bool hasTexture [[function_constant(0)]];
constant int  mode       [[function_constant(1)]];

kernel void myKernel(...) {
    if (hasTexture) {
        // specialized path
    }
}
```

---

## 9. Pack/Unpack Functions

Header: `<metal_pack>`

### Pack (float/half → uint):

| MSL Function | Signature | Example |
|---|---|---|
| `pack_float_to_snorm4x8` | `uint pack_float_to_snorm4x8(float4 x)` | `uint packed = pack_float_to_snorm4x8(color);` |
| `pack_float_to_unorm4x8` | `uint pack_float_to_unorm4x8(float4 x)` | `uint packed = pack_float_to_unorm4x8(color);` |
| `pack_float_to_snorm2x16` | `uint pack_float_to_snorm2x16(float2 x)` | `uint packed = pack_float_to_snorm2x16(uv);` |
| `pack_float_to_unorm2x16` | `uint pack_float_to_unorm2x16(float2 x)` | `uint packed = pack_float_to_unorm2x16(uv);` |
| `pack_half_to_snorm4x8` | `uint pack_half_to_snorm4x8(half4 x)` | `uint packed = pack_half_to_snorm4x8(color);` |
| `pack_half_to_unorm4x8` | `uint pack_half_to_unorm4x8(half4 x)` | `uint packed = pack_half_to_unorm4x8(color);` |
| `pack_half_to_snorm2x16` | `uint pack_half_to_snorm2x16(half2 x)` | `uint packed = pack_half_to_snorm2x16(uv);` |
| `pack_half_to_unorm2x16` | `uint pack_half_to_unorm2x16(half2 x)` | `uint packed = pack_half_to_unorm2x16(uv);` |
| `pack_float_to_srgb_unorm4x8` | `uint pack_float_to_srgb_unorm4x8(float4 x)` | `uint packed = pack_float_to_srgb_unorm4x8(color);` |
| `pack_half_to_srgb_unorm4x8` | `uint pack_half_to_srgb_unorm4x8(half4 x)` | `uint packed = pack_half_to_srgb_unorm4x8(color);` |
| `pack_float_to_unorm10a2` | `uint pack_float_to_unorm10a2(float4 x)` | `uint packed = pack_float_to_unorm10a2(color);` |
| `pack_float_to_unorm565` | `ushort pack_float_to_unorm565(float3 x)` | `ushort packed = pack_float_to_unorm565(rgb);` |

### Unpack (uint → float/half):

| MSL Function | Signature | Example |
|---|---|---|
| `unpack_snorm4x8_to_float` | `float4 unpack_snorm4x8_to_float(uint x)` | `float4 c = unpack_snorm4x8_to_float(packed);` |
| `unpack_unorm4x8_to_float` | `float4 unpack_unorm4x8_to_float(uint x)` | `float4 c = unpack_unorm4x8_to_float(packed);` |
| `unpack_snorm2x16_to_float` | `float2 unpack_snorm2x16_to_float(uint x)` | `float2 uv = unpack_snorm2x16_to_float(packed);` |
| `unpack_unorm2x16_to_float` | `float2 unpack_unorm2x16_to_float(uint x)` | `float2 uv = unpack_unorm2x16_to_float(packed);` |
| `unpack_snorm4x8_to_half` | `half4 unpack_snorm4x8_to_half(uint x)` | `half4 c = unpack_snorm4x8_to_half(packed);` |
| `unpack_unorm4x8_to_half` | `half4 unpack_unorm4x8_to_half(uint x)` | `half4 c = unpack_unorm4x8_to_half(packed);` |
| `unpack_snorm2x16_to_half` | `half2 unpack_snorm2x16_to_half(uint x)` | `half2 uv = unpack_snorm2x16_to_half(packed);` |
| `unpack_unorm2x16_to_half` | `half2 unpack_unorm2x16_to_half(uint x)` | `half2 uv = unpack_unorm2x16_to_half(packed);` |
| `unpack_unorm4x8_srgb_to_float` | `float4 unpack_unorm4x8_srgb_to_float(uint x)` | `float4 c = unpack_unorm4x8_srgb_to_float(packed);` |
| `unpack_unorm4x8_srgb_to_half` | `half4 unpack_unorm4x8_srgb_to_half(uint x)` | `half4 c = unpack_unorm4x8_srgb_to_half(packed);` |
| `unpack_unorm10a2_to_float` | `float4 unpack_unorm10a2_to_float(uint x)` | `float4 c = unpack_unorm10a2_to_float(packed);` |
| `unpack_unorm10a2_to_half` | `half4 unpack_unorm10a2_to_half(uint x)` | `half4 c = unpack_unorm10a2_to_half(packed);` |
| `unpack_unorm565_to_float` | `float3 unpack_unorm565_to_float(ushort x)` | `float3 c = unpack_unorm565_to_float(packed);` |
| `unpack_unorm565_to_half` | `half3 unpack_unorm565_to_half(ushort x)` | `half3 c = unpack_unorm565_to_half(packed);` |

---

## 10. Render Attributes (Vertex/Fragment Built-ins)

These are `[[attribute]]` qualifiers on struct members or function parameters.

| Attribute | Type | Stage | Example |
|---|---|---|---|
| `[[position]]` | `float4` | vertex out / fragment in | `float4 pos [[position]];` |
| `[[point_size]]` | `float` | vertex out | `float sz [[point_size]];` |
| `[[color(N)]]` | `half4` / `float4` | fragment in (framebuffer fetch) | `half4 dst [[color(0)]];` |
| `[[front_facing]]` | `bool` | fragment in (rasterizer) | `bool ff [[front_facing]];` |
| `[[sample_id]]` | `uint` | fragment in (rasterizer) | `uint sid [[sample_id]];` |
| `[[clip_distance]]` | `float` / `float[N]` | vertex out | `float cd [[clip_distance]];` |
| `[[vertex_id]]` | `uint` | vertex in | `uint vid [[vertex_id]];` |
| `[[instance_id]]` | `uint` | vertex in | `uint iid [[instance_id]];` |
| `[[sample_mask]]` | `uint` | fragment in/out | `uint mask [[sample_mask]];` |
| `[[point_coord]]` | `float2` | fragment in | `float2 pc [[point_coord]];` |

```cpp
// Full vertex output example:
struct VertexOut {
    float4 position [[position]];
    float  pointSize [[point_size]];
    float  clipDist [[clip_distance]];
};
```

---

## 11. Interpolation Qualifiers

These are `[[attribute]]` qualifiers on fragment input struct members controlling how vertex outputs are interpolated across the primitive.

| Qualifier | Description | Example |
|---|---|---|
| `[[flat]]` | No interpolation (use provoking vertex value). Mandatory for integer types. | `int idx [[flat]];` |
| `[[center_perspective]]` | **Default.** Perspective-correct interpolation at pixel center. | `float4 color [[center_perspective]];` |
| `[[center_no_perspective]]` | Screen-space linear interpolation at pixel center. | `float4 pos [[center_no_perspective]];` |
| `[[centroid_perspective]]` | Perspective-correct at centroid. | `float2 uv [[centroid_perspective]];` |
| `[[centroid_no_perspective]]` | Screen-space linear at centroid. | `float2 uv [[centroid_no_perspective]];` |
| `[[sample_perspective]]` | Perspective-correct per-sample. | `float f [[sample_perspective]];` |
| `[[sample_no_perspective]]` | Screen-space linear per-sample. | `float f [[sample_no_perspective]];` |

```cpp
struct FragmentInput {
    float4 position [[center_no_perspective]];
    float4 color    [[center_perspective]];   // default, can omit
    float2 texcoord;                          // defaults to center_perspective
    int    index    [[flat]];
    float  f        [[sample_perspective]];
};
```

---

## Quick Type Reference for TableGen

### Integer scalar types in MSL:
`char`, `uchar`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`

### Floating-point scalar types:
`half` (16-bit), `float` (32-bit), `bfloat` (16-bit brain float, where available)

### Vector types:
`{scalar}{N}` where N ∈ {2, 3, 4} — e.g. `float4`, `int2`, `half3`

### Matrix types:
`{scalar}{C}x{R}` where C,R ∈ {2, 3, 4} — e.g. `float4x4`, `half3x3`

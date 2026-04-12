# MLIR Examples — How to Write Enigma Dialect IR

This guide shows how to write Enigma dialect MLIR by example. Each section shows the MLIR input and the MSL output it produces via `enigma-translate --enigma-to-msl`.

---

## 1. Hello World: Vector Add

The simplest kernel — add two arrays element-wise.

### MLIR Input
```mlir
module {
  enigma.kernel @vector_add(%a: memref<?xf32>,
                            %b: memref<?xf32>,
                            %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %va = memref.load %a[%id] : memref<?xf32>
    %vb = memref.load %b[%id] : memref<?xf32>
    %vc = arith.addf %va, %vb : f32
    memref.store %vc, %out[%id] : memref<?xf32>
    enigma.return
  }
}
```

### MSL Output
```metal
#include <metal_stdlib>
using namespace metal;

kernel void vector_add(
    device float* v0 [[buffer(0)]],
    device float* v1 [[buffer(1)]],
    device float* v2 [[buffer(2)]],
    uint3 _tpg [[thread_position_in_grid]]
) {
    uint v3 = _tpg.x;
    float v4 = v0[v3];
    float v5 = v1[v3];
    float v6 = v4 + v5;
    v2[v3] = v6;
}
```

**Key points:**
- `enigma.kernel @name(...)` defines a compute entry point
- Thread position ops become `[[...]]` kernel parameters
- `memref<?xf32>` becomes `device float*`
- Standard `arith` and `memref` ops work inside enigma kernels

---

## 2. Address Spaces: Constant Buffers

Read from read-only `constant` memory (memory space 1).

### MLIR Input
```mlir
module {
  enigma.kernel @scale(%weights: memref<?xf32, 1>,   // constant
                       %data: memref<?xf32>,          // device
                       %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %w = memref.load %weights[%id] : memref<?xf32, 1>
    %d = memref.load %data[%id] : memref<?xf32>
    %r = arith.mulf %w, %d : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}
```

### MSL Output
```metal
kernel void scale(
    constant float* v0 [[buffer(0)]],
    device float* v1 [[buffer(1)]],
    device float* v2 [[buffer(2)]],
    uint3 _tpg [[thread_position_in_grid]]
) {
    uint v3 = _tpg.x;
    float v4 = v0[v3];
    float v5 = v1[v3];
    float v6 = v4 * v5;
    v2[v3] = v6;
}
```

**Key point:** `memref<?xf32, 1>` maps to `constant float*`.

---

## 3. Threadgroup Shared Memory + Barriers

Parallel reduction using shared threadgroup memory.

### MLIR Input
```mlir
module {
  enigma.kernel @tg_reduce(%input: memref<?xf32>,
                           %output: memref<?xf32>) {
    %gid = enigma.thread_position_in_grid x
    %lid = enigma.thread_position_in_threadgroup x

    // Allocate shared memory (threadgroup address space = 2)
    %shared = enigma.threadgroup_alloc : memref<256xf32, 2>

    // Load global -> shared
    %val = memref.load %input[%gid] : memref<?xf32>
    memref.store %val, %shared[%lid] : memref<256xf32, 2>

    // Synchronize all threads in the threadgroup
    enigma.threadgroup_barrier mem_threadgroup

    // Read back from shared
    %result = memref.load %shared[%lid] : memref<256xf32, 2>
    memref.store %result, %output[%gid] : memref<?xf32>
    enigma.return
  }
}
```

### MSL Output
```metal
kernel void tg_reduce(
    device float* v0 [[buffer(0)]],
    device float* v1 [[buffer(1)]],
    uint3 _tpg [[thread_position_in_grid]],
    uint3 _tpt [[thread_position_in_threadgroup]]
) {
    uint v2 = _tpg.x;
    uint v3 = _tpt.x;
    threadgroup float v4[256];
    float v5 = v0[v2];
    v4[v3] = v5;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float v6 = v4[v3];
    v1[v2] = v6;
}
```

---

## 4. SIMD Group Reduction

Use SIMD intrinsics for warp-level operations (no shared memory needed).

### MLIR Input
```mlir
module {
  enigma.kernel @simd_reduce(%input: memref<?xf32>,
                             %output: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x

    %val = memref.load %input[%id] : memref<?xf32>

    // Sum across all 32 lanes of the SIMD group
    %total = enigma.simd_sum %val : f32

    // Prefix scan for stream compaction
    %prefix = enigma.simd_prefix_exclusive_sum %val : f32

    // Shuffle: get value from lane (current - 1)
    %c1 = arith.constant 1 : index
    %neighbor = enigma.simd_shuffle_up %val, %c1 : f32

    memref.store %total, %output[%id] : memref<?xf32>
    enigma.return
  }
}
```

### MSL Output
```metal
kernel void simd_reduce(
    device float* v0 [[buffer(0)]],
    device float* v1 [[buffer(1)]],
    uint3 _tpg [[thread_position_in_grid]]
) {
    uint v2 = _tpg.x;
    float v3 = v0[v2];
    float v4 = simd_sum(v3);
    float v5 = simd_prefix_exclusive_sum(v3);
    uint v6 = 1;
    float v7 = simd_shuffle_up(v3, v6);
    v1[v2] = v4;
}
```

---

## 5. Atomic Operations

Global histogram with atomic increments.

### MLIR Input
```mlir
module {
  enigma.kernel @histogram(%data: memref<?xi32>,
                           %bins: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %data[%id] : memref<?xi32>
    %c1 = arith.constant 1 : i32

    // Atomically increment the bin count
    %old = enigma.atomic_fetch_add %bins[%val], %c1 relaxed
               : memref<?xi32>, i32
    enigma.return
  }
}
```

### MSL Output
```metal
kernel void histogram(
    device int* v0 [[buffer(0)]],
    device int* v1 [[buffer(1)]],
    uint3 _tpg [[thread_position_in_grid]]
) {
    uint v2 = _tpg.x;
    int v3 = v0[v2];
    int v4 = 1;
    int v5 = atomic_fetch_add_explicit((device atomic_int*)&v1[v3], v4, memory_order_relaxed);
}
```

---

## 6. GPU Math Built-ins

Neural network activation functions.

### MLIR Input
```mlir
module {
  enigma.kernel @activations(%input: memref<?xf32>,
                             %output: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %x = memref.load %input[%id] : memref<?xf32>

    // Sigmoid: 1 / (1 + exp(-x))
    %neg_x = arith.negf %x : f32
    %exp_neg = enigma.exp %neg_x : f32
    %one = arith.constant 1.0 : f32
    %denom = arith.addf %one, %exp_neg : f32

    // tanh activation (fast precision for throughput)
    %th = enigma.tanh %x {precision = fast} : f32

    // Clamp output to [0, 1]
    %zero = arith.constant 0.0 : f32
    %clamped = enigma.clamp %th, %zero, %one : f32

    memref.store %clamped, %output[%id] : memref<?xf32>
    enigma.return
  }
}
```

---

## 7. Geometric Operations

Lighting calculation using geometric functions.

### MLIR Input
```mlir
module {
  enigma.kernel @phong_lighting(%normals: memref<?xf32>,
                                %output: memref<?xf32>) {
    %light_dir = arith.constant dense<[0.0, 1.0, 0.0]> : vector<3xf32>
    %view_dir = arith.constant dense<[0.0, 0.0, 1.0]> : vector<3xf32>
    %normal = arith.constant dense<[0.0, 1.0, 0.0]> : vector<3xf32>

    // Normalize the normal vector
    %n = enigma.normalize %normal : vector<3xf32>

    // Diffuse: max(dot(N, L), 0)
    %ndotl = enigma.dot %n, %light_dir : vector<3xf32> -> f32
    %zero = arith.constant 0.0 : f32
    %diffuse = enigma.fmax %ndotl, %zero : f32

    // Specular: reflect(-L, N), then dot with view
    %reflect_dir = enigma.reflect %light_dir, %n : vector<3xf32>
    %spec_dot = enigma.dot %reflect_dir, %view_dir : vector<3xf32> -> f32
    %spec_base = enigma.fmax %spec_dot, %zero : f32
    %shininess = arith.constant 32.0 : f32
    %specular = enigma.pow %spec_base, %shininess : f32

    enigma.return
  }
}
```

---

## 8. Integer Bit Manipulation

Bitfield packing/unpacking.

### MLIR Input
```mlir
module {
  enigma.kernel @bitfield_ops(%data: memref<?xi32>,
                              %output: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %data[%id] : memref<?xi32>

    // Extract 8 bits starting at offset 16 (bits [16:23])
    %channel = enigma.extract_bits %val 16 8 : i32

    // Count set bits
    %ones = enigma.popcount %val : i32

    // Count leading zeros (useful for priority encoding)
    %priority = enigma.clz %val : i32

    // Reverse bits (for FFT butterfly addressing)
    %reversed = enigma.reverse_bits %val : i32

    // Saturating arithmetic (safe for DSP)
    %w = memref.load %data[%id] : memref<?xi32>
    %safe_add = enigma.add_sat %val, %w : i32

    memref.store %ones, %output[%id] : memref<?xi32>
    enigma.return
  }
}
```

---

## 9. Vertex + Fragment Shaders

Basic vertex/fragment rendering pipeline.

### MLIR Input
```mlir
module {
  enigma.vertex @vertex_passthrough(%positions: memref<?xf32>) -> vector<4xf32> {
    %vid = enigma.vertex_id
    %pos = arith.constant dense<[0.0, 0.0, 0.0, 1.0]> : vector<4xf32>
    enigma.vertex_return %pos : vector<4xf32>
  }

  enigma.fragment @fragment_red(%color_in: vector<4xf32>) -> vector<4xf32> {
    %red = arith.constant dense<[1.0, 0.0, 0.0, 1.0]> : vector<4xf32>
    enigma.fragment_return %red : vector<4xf32>
  }
}
```

---

## Running the Examples

```bash
# Parse and re-print (roundtrip test)
enigma-opt path/to/example.mlir

# Translate to MSL
enigma-translate --enigma-to-msl path/to/example.mlir

# Verify MSL compiles (macOS only)
enigma-translate --enigma-to-msl path/to/example.mlir | xcrun metal -c -x metal -
```

---

## Type Mapping Quick Reference

| MLIR Type | MSL Type |
|-----------|----------|
| `f32` | `float` |
| `f16` | `half` |
| `i1` | `bool` |
| `i8` | `char` |
| `i16` | `short` |
| `i32` | `int` |
| `i64` | `long` |
| `index` | `uint` |
| `vector<3xf32>` | `float3` |
| `vector<4xf32>` | `float4` |
| `memref<?xf32>` | `device float*` |
| `memref<?xf32, 1>` | `constant float*` |
| `memref<256xf32, 2>` | `threadgroup float[256]` |

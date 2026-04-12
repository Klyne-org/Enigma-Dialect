// RUN: enigma-opt %s | enigma-opt | FileCheck %s

// =============================================================================
// roundtrip.mlir — parse-print-parse roundtrip for ALL Enigma dialect ops.
// =============================================================================

// ============================================================================
// Section 1: Function entry points
// ============================================================================

// CHECK-LABEL: enigma.kernel @vector_add
// CHECK-SAME:  (%{{.*}}: memref<?xf32>, %{{.*}}: memref<?xf32>, %{{.*}}: memref<?xf32>)
enigma.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>, %c: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %va = memref.load %a[%id] : memref<?xf32>
  %vb = memref.load %b[%id] : memref<?xf32>
  // CHECK: arith.addf
  %vc = arith.addf %va, %vb : f32
  memref.store %vc, %c[%id] : memref<?xf32>
  // CHECK: enigma.return
  enigma.return
}

// CHECK-LABEL: enigma.vertex @vertex_main
// CHECK-SAME:  -> vector<4xf32>
enigma.vertex @vertex_main(%pos: memref<?xf32>) -> vector<4xf32> {
  %vid = enigma.vertex_id
  %c0 = arith.constant 0.0 : f32
  %v = arith.constant dense<[0.0, 0.0, 0.0, 1.0]> : vector<4xf32>
  // CHECK: enigma.vertex_return
  enigma.vertex_return %v : vector<4xf32>
}

// CHECK-LABEL: enigma.fragment @fragment_main
// CHECK-SAME:  -> vector<4xf32>
enigma.fragment @fragment_main(%in: vector<4xf32>) -> vector<4xf32> {
  // CHECK: enigma.fragment_return
  enigma.fragment_return %in : vector<4xf32>
}

// ============================================================================
// Section 2: Thread indexing — all 12 builtins + vertex/instance id
// ============================================================================

// CHECK-LABEL: enigma.kernel @thread_indexing
enigma.kernel @thread_indexing(%buf: memref<?xf32>) {
  // CHECK: enigma.thread_position_in_grid x
  %tpg_x = enigma.thread_position_in_grid x
  // CHECK: enigma.thread_position_in_grid y
  %tpg_y = enigma.thread_position_in_grid y
  // CHECK: enigma.thread_position_in_grid z
  %tpg_z = enigma.thread_position_in_grid z

  // CHECK: enigma.threadgroup_position_in_grid x
  %bgid = enigma.threadgroup_position_in_grid x
  // CHECK: enigma.thread_position_in_threadgroup x
  %ltid = enigma.thread_position_in_threadgroup x
  // CHECK: enigma.threads_per_threadgroup x
  %bdim = enigma.threads_per_threadgroup x
  // CHECK: enigma.thread_index_in_threadgroup x
  %titg = enigma.thread_index_in_threadgroup x
  // CHECK: enigma.threadgroups_per_grid x
  %tgpg = enigma.threadgroups_per_grid x
  // CHECK: enigma.threads_per_grid x
  %tpg_count = enigma.threads_per_grid x
  // CHECK: enigma.grid_size x
  %gs = enigma.grid_size x
  // CHECK: enigma.simdgroup_index_in_threadgroup x
  %sigt = enigma.simdgroup_index_in_threadgroup x
  // CHECK: enigma.thread_index_in_simdgroup x
  %tisg = enigma.thread_index_in_simdgroup x
  // CHECK: enigma.threads_per_simdgroup x
  %tpsg = enigma.threads_per_simdgroup x
  // CHECK: enigma.simdgroups_per_threadgroup x
  %sgptg = enigma.simdgroups_per_threadgroup x
  enigma.return
}

// ============================================================================
// Section 3: Address spaces
// ============================================================================

// CHECK-LABEL: enigma.kernel @addr_space_test
// CHECK-SAME:  (%{{.*}}: memref<?xf32, 1>, %{{.*}}: memref<?xf32>)
enigma.kernel @addr_space_test(%w: memref<?xf32, 1>, %out: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %v = memref.load %w[%id] : memref<?xf32, 1>
  memref.store %v, %out[%id] : memref<?xf32>
  enigma.return
}

// ============================================================================
// Section 4: Synchronization + Threadgroup memory
// ============================================================================

// CHECK-LABEL: enigma.kernel @sync_ops
enigma.kernel @sync_ops(%buf: memref<?xf32>) {
  // CHECK: enigma.threadgroup_barrier mem_threadgroup
  enigma.threadgroup_barrier mem_threadgroup
  // CHECK: enigma.threadgroup_barrier mem_device
  enigma.threadgroup_barrier mem_device
  // CHECK: enigma.threadgroup_barrier mem_device_and_threadgroup
  enigma.threadgroup_barrier mem_device_and_threadgroup
  // CHECK: enigma.threadgroup_barrier mem_none
  enigma.threadgroup_barrier mem_none
  // CHECK: enigma.simdgroup_barrier mem_threadgroup
  enigma.simdgroup_barrier mem_threadgroup

  // CHECK: enigma.threadgroup_alloc : memref<256xf32, 2>
  %shared = enigma.threadgroup_alloc : memref<256xf32, 2>
  enigma.return
}

// ============================================================================
// Section 5: SIMD group operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @simd_ops
enigma.kernel @simd_ops(%buf: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %val = memref.load %buf[%id] : memref<?xf32>

  // --- Reductions ---
  // CHECK: enigma.simd_sum
  %sum = enigma.simd_sum %val : f32
  // CHECK: enigma.simd_product
  %prod = enigma.simd_product %val : f32
  // CHECK: enigma.simd_min
  %mn = enigma.simd_min %val : f32
  // CHECK: enigma.simd_max
  %mx = enigma.simd_max %val : f32

  // --- Prefix scans ---
  // CHECK: enigma.simd_prefix_exclusive_sum
  %pxs = enigma.simd_prefix_exclusive_sum %val : f32
  // CHECK: enigma.simd_prefix_inclusive_sum
  %pis = enigma.simd_prefix_inclusive_sum %val : f32
  // CHECK: enigma.simd_prefix_exclusive_product
  %pxp = enigma.simd_prefix_exclusive_product %val : f32
  // CHECK: enigma.simd_prefix_inclusive_product
  %pip = enigma.simd_prefix_inclusive_product %val : f32

  // --- Shuffles ---
  %c4 = arith.constant 4 : index
  // CHECK: enigma.simd_shuffle
  %sh = enigma.simd_shuffle %val, %c4 : f32
  // CHECK: enigma.simd_shuffle_up
  %shup = enigma.simd_shuffle_up %val, %c4 : f32
  // CHECK: enigma.simd_shuffle_down
  %shdn = enigma.simd_shuffle_down %val, %c4 : f32
  // CHECK: enigma.simd_shuffle_xor
  %shxor = enigma.simd_shuffle_xor %val, %c4 : f32
  // CHECK: enigma.simd_broadcast
  %bcast = enigma.simd_broadcast %val, %c4 : f32
  enigma.return
}

// Bitwise SIMD ops (integer)
// CHECK-LABEL: enigma.kernel @simd_bitwise
enigma.kernel @simd_bitwise(%buf: memref<?xi32>) {
  %id = enigma.thread_position_in_grid x
  %val = memref.load %buf[%id] : memref<?xi32>
  // CHECK: enigma.simd_and
  %a = enigma.simd_and %val : i32
  // CHECK: enigma.simd_or
  %o = enigma.simd_or %val : i32
  // CHECK: enigma.simd_xor
  %x = enigma.simd_xor %val : i32
  enigma.return
}

// ============================================================================
// Section 6: Atomic operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @atomic_ops
enigma.kernel @atomic_ops(%buf: memref<?xi32>) {
  %id = enigma.thread_position_in_grid x
  %c1 = arith.constant 1 : i32
  %c0 = arith.constant 0 : index
  %c5 = arith.constant 5 : i32

  // CHECK: enigma.atomic_load
  %loaded = enigma.atomic_load %buf[%c0] relaxed : memref<?xi32> -> i32
  // CHECK: enigma.atomic_store
  enigma.atomic_store %c1, %buf[%c0] release : i32, memref<?xi32>
  // CHECK: enigma.atomic_exchange
  %old = enigma.atomic_exchange %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_compare_exchange_weak
  %ok = enigma.atomic_compare_exchange_weak %buf[%c0], %c1, %c5 acq_rel relaxed : memref<?xi32>, i32

  // CHECK: enigma.atomic_fetch_add
  %a = enigma.atomic_fetch_add %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_sub
  %s = enigma.atomic_fetch_sub %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_min
  %mn = enigma.atomic_fetch_min %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_max
  %mx = enigma.atomic_fetch_max %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_and
  %an = enigma.atomic_fetch_and %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_or
  %or = enigma.atomic_fetch_or %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  // CHECK: enigma.atomic_fetch_xor
  %xor = enigma.atomic_fetch_xor %buf[%c0], %c1 relaxed : memref<?xi32>, i32
  enigma.return
}

// ============================================================================
// Section 7: Math built-ins (float)
// ============================================================================

// CHECK-LABEL: enigma.kernel @math_unary
enigma.kernel @math_unary(%buf: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %v = memref.load %buf[%id] : memref<?xf32>

  // CHECK: enigma.abs
  %a0 = enigma.abs %v : f32
  // CHECK: enigma.ceil
  %a1 = enigma.ceil %v : f32
  // CHECK: enigma.floor
  %a2 = enigma.floor %v : f32
  // CHECK: enigma.round
  %a3 = enigma.round %v : f32
  // CHECK: enigma.trunc
  %a4 = enigma.trunc %v : f32
  // CHECK: enigma.sign
  %a5 = enigma.sign %v : f32
  // CHECK: enigma.saturate
  %a6 = enigma.saturate %v : f32
  // CHECK: enigma.fract
  %a7 = enigma.fract %v : f32
  // CHECK: enigma.sqrt
  %a8 = enigma.sqrt %v : f32
  // CHECK: enigma.rsqrt
  %a9 = enigma.rsqrt %v : f32
  // CHECK: enigma.exp
  %b0 = enigma.exp %v : f32
  // CHECK: enigma.exp2
  %b1 = enigma.exp2 %v : f32
  // CHECK: enigma.log
  %b2 = enigma.log %v : f32
  // CHECK: enigma.log2
  %b3 = enigma.log2 %v : f32
  // CHECK: enigma.log10
  %b4 = enigma.log10 %v : f32
  // CHECK: enigma.sin
  %b5 = enigma.sin %v : f32
  // CHECK: enigma.cos
  %b6 = enigma.cos %v : f32
  // CHECK: enigma.tan
  %b7 = enigma.tan %v : f32
  // CHECK: enigma.asin
  %b8 = enigma.asin %v : f32
  // CHECK: enigma.acos
  %b9 = enigma.acos %v : f32
  // CHECK: enigma.atan
  %c0 = enigma.atan %v : f32
  // CHECK: enigma.sinh
  %c1 = enigma.sinh %v : f32
  // CHECK: enigma.cosh
  %c2 = enigma.cosh %v : f32
  // CHECK: enigma.tanh
  %c3 = enigma.tanh %v : f32
  enigma.return
}

// CHECK-LABEL: enigma.kernel @math_binary_ternary
enigma.kernel @math_binary_ternary(%buf: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %x = memref.load %buf[%id] : memref<?xf32>
  %y = memref.load %buf[%id] : memref<?xf32>
  %z = memref.load %buf[%id] : memref<?xf32>

  // Binary
  // CHECK: enigma.fmin
  %fmn = enigma.fmin %x, %y : f32
  // CHECK: enigma.fmax
  %fmx = enigma.fmax %x, %y : f32
  // CHECK: enigma.pow
  %pw = enigma.pow %x, %y : f32
  // CHECK: enigma.fmod
  %fm = enigma.fmod %x, %y : f32
  // CHECK: enigma.atan2
  %at2 = enigma.atan2 %x, %y : f32
  // CHECK: enigma.step
  %st = enigma.step %x, %y : f32
  // CHECK: enigma.copysign
  %cs = enigma.copysign %x, %y : f32

  // Ternary
  // CHECK: enigma.clamp
  %cl = enigma.clamp %x, %y, %z : f32
  // CHECK: enigma.fma
  %fma = enigma.fma %x, %y, %z : f32
  // CHECK: enigma.mix
  %mx = enigma.mix %x, %y, %z : f32
  // CHECK: enigma.smoothstep
  %ss = enigma.smoothstep %x, %y, %z : f32
  enigma.return
}

// ============================================================================
// Section 8: Integer intrinsics
// ============================================================================

// CHECK-LABEL: enigma.kernel @int_ops
enigma.kernel @int_ops(%buf: memref<?xi32>) {
  %id = enigma.thread_position_in_grid x
  %v = memref.load %buf[%id] : memref<?xi32>
  %w = memref.load %buf[%id] : memref<?xi32>

  // Unary
  // CHECK: enigma.popcount
  %pc = enigma.popcount %v : i32
  // CHECK: enigma.clz
  %clz = enigma.clz %v : i32
  // CHECK: enigma.ctz
  %ctz = enigma.ctz %v : i32
  // CHECK: enigma.reverse_bits
  %rb = enigma.reverse_bits %v : i32

  // Binary
  // CHECK: enigma.abs_diff
  %ad = enigma.abs_diff %v, %w : i32
  // CHECK: enigma.add_sat
  %as = enigma.add_sat %v, %w : i32
  // CHECK: enigma.sub_sat
  %ss = enigma.sub_sat %v, %w : i32
  // CHECK: enigma.mul_hi
  %mh = enigma.mul_hi %v, %w : i32
  // CHECK: enigma.rotate
  %rot = enigma.rotate %v, %w : i32

  // Bit extraction/insertion
  // CHECK: enigma.extract_bits
  %eb = enigma.extract_bits %v 4 8 : i32
  // CHECK: enigma.insert_bits
  %ib = enigma.insert_bits %v, %w 4 8 : i32

  // Ternary
  // CHECK: enigma.mad_sat
  %ms = enigma.mad_sat %v, %w, %v : i32
  enigma.return
}

// ============================================================================
// Section 9: Geometric / vector operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @geom_ops
enigma.kernel @geom_ops(%buf: memref<?xf32>) {
  %v3 = arith.constant dense<[1.0, 0.0, 0.0]> : vector<3xf32>
  %n3 = arith.constant dense<[0.0, 1.0, 0.0]> : vector<3xf32>
  %eta = arith.constant 1.5 : f32

  // CHECK: enigma.dot
  %d = enigma.dot %v3, %n3 : vector<3xf32> -> f32
  // CHECK: enigma.cross
  %cr = enigma.cross %v3, %n3 : vector<3xf32>
  // CHECK: enigma.length
  %l = enigma.length %v3 : vector<3xf32> -> f32
  // CHECK: enigma.distance
  %dist = enigma.distance %v3, %n3 : vector<3xf32> -> f32
  // CHECK: enigma.normalize
  %nm = enigma.normalize %v3 : vector<3xf32>
  // CHECK: enigma.reflect
  %ref = enigma.reflect %v3, %n3 : vector<3xf32>
  // CHECK: enigma.refract
  %rfr = enigma.refract %v3, %n3, %eta : vector<3xf32>, f32
  // CHECK: enigma.faceforward
  %ff = enigma.faceforward %n3, %v3, %n3 : vector<3xf32>
  enigma.return
}

// ============================================================================
// Section 10: Cast operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @cast_ops
enigma.kernel @cast_ops(%buf: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %fval = memref.load %buf[%id] : memref<?xf32>
  %ival = arith.constant 42 : i32

  // CHECK: enigma.metal_cast
  %cast1 = enigma.metal_cast %ival : i32 to f32
  // CHECK: enigma.as_type
  %cast2 = enigma.as_type %fval : f32 to i32
  enigma.return
}

// ============================================================================
// Section 11: Relational / Select / Integer min-max-clamp
// ============================================================================

// CHECK-LABEL: enigma.kernel @relational_ops
enigma.kernel @relational_ops(%buf: memref<?xf32>, %ibuf: memref<?xi32>) {
  %id = enigma.thread_position_in_grid x
  %fval = memref.load %buf[%id] : memref<?xf32>
  %ival = memref.load %ibuf[%id] : memref<?xi32>

  // CHECK: enigma.isnan
  %nan = enigma.isnan %fval : f32
  // CHECK: enigma.isinf
  %inf = enigma.isinf %fval : f32
  // CHECK: enigma.isfinite
  %fin = enigma.isfinite %fval : f32
  // CHECK: enigma.signbit
  %sb = enigma.signbit %fval : f32
  // CHECK: enigma.isnormal
  %norm = enigma.isnormal %fval : f32

  // CHECK: enigma.select
  %sel = enigma.select %fval, %fval, %nan : f32

  // CHECK: enigma.imin
  %imn = enigma.imin %ival, %ival : i32
  // CHECK: enigma.imax
  %imx = enigma.imax %ival, %ival : i32
  // CHECK: enigma.iclamp
  %ic = enigma.iclamp %ival, %ival, %ival : i32
  enigma.return
}

// ============================================================================
// Section 12: Quad group operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @quad_ops
enigma.kernel @quad_ops(%buf: memref<?xf32>, %ibuf: memref<?xi32>) {
  %id = enigma.thread_position_in_grid x
  %fval = memref.load %buf[%id] : memref<?xf32>
  %ival = memref.load %ibuf[%id] : memref<?xi32>
  %c2 = arith.constant 2 : index

  // Reductions
  // CHECK: enigma.quad_sum
  %qs = enigma.quad_sum %fval : f32
  // CHECK: enigma.quad_product
  %qp = enigma.quad_product %fval : f32
  // CHECK: enigma.quad_min
  %qmn = enigma.quad_min %fval : f32
  // CHECK: enigma.quad_max
  %qmx = enigma.quad_max %fval : f32

  // Bitwise
  // CHECK: enigma.quad_and
  %qa = enigma.quad_and %ival : i32
  // CHECK: enigma.quad_or
  %qo = enigma.quad_or %ival : i32
  // CHECK: enigma.quad_xor
  %qx = enigma.quad_xor %ival : i32

  // Shuffles
  // CHECK: enigma.quad_shuffle
  %sh = enigma.quad_shuffle %fval, %c2 : f32
  // CHECK: enigma.quad_broadcast
  %bc = enigma.quad_broadcast %fval, %c2 : f32
  // CHECK: enigma.quad_shuffle_down
  %sd = enigma.quad_shuffle_down %fval, %c2 : f32
  // CHECK: enigma.quad_shuffle_up
  %su = enigma.quad_shuffle_up %fval, %c2 : f32
  // CHECK: enigma.quad_shuffle_xor
  %sx = enigma.quad_shuffle_xor %fval, %c2 : f32

  // Prefix scans
  // CHECK: enigma.quad_prefix_exclusive_sum
  %qpes = enigma.quad_prefix_exclusive_sum %fval : f32
  // CHECK: enigma.quad_prefix_inclusive_sum
  %qpis = enigma.quad_prefix_inclusive_sum %fval : f32
  enigma.return
}

// ============================================================================
// Section 13: Function constants
// ============================================================================

// CHECK-LABEL: enigma.kernel @function_constant_test
enigma.kernel @function_constant_test(%buf: memref<?xf32>) {
  // CHECK: enigma.function_constant 0 : i1
  %use_tex = enigma.function_constant 0 : i1
  // CHECK: enigma.function_constant 1 : i32
  %mode = enigma.function_constant 1 : i32
  enigma.return
}

// ============================================================================
// Section 14: Pack / Unpack operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @pack_unpack_ops
enigma.kernel @pack_unpack_ops(%buf: memref<?xf32>) {
  %v4 = arith.constant dense<[0.5, 0.5, 0.5, 1.0]> : vector<4xf32>
  %v2 = arith.constant dense<[0.5, 0.5]> : vector<2xf32>

  // CHECK: enigma.pack_float_to_snorm4x8
  %ps4 = enigma.pack_float_to_snorm4x8 %v4 : vector<4xf32> -> i32
  // CHECK: enigma.pack_float_to_unorm4x8
  %pu4 = enigma.pack_float_to_unorm4x8 %v4 : vector<4xf32> -> i32
  // CHECK: enigma.pack_float_to_snorm2x16
  %ps2 = enigma.pack_float_to_snorm2x16 %v2 : vector<2xf32> -> i32
  // CHECK: enigma.pack_float_to_unorm2x16
  %pu2 = enigma.pack_float_to_unorm2x16 %v2 : vector<2xf32> -> i32
  // CHECK: enigma.pack_float_to_srgb_unorm4x8
  %psr = enigma.pack_float_to_srgb_unorm4x8 %v4 : vector<4xf32> -> i32
  // CHECK: enigma.pack_float_to_unorm10a2
  %p10 = enigma.pack_float_to_unorm10a2 %v4 : vector<4xf32> -> i32

  // CHECK: enigma.unpack_snorm4x8_to_float
  %us4 = enigma.unpack_snorm4x8_to_float %ps4 : i32 -> vector<4xf32>
  // CHECK: enigma.unpack_unorm4x8_to_float
  %uu4 = enigma.unpack_unorm4x8_to_float %pu4 : i32 -> vector<4xf32>
  // CHECK: enigma.unpack_snorm2x16_to_float
  %us2 = enigma.unpack_snorm2x16_to_float %ps2 : i32 -> vector<2xf32>
  // CHECK: enigma.unpack_unorm2x16_to_float
  %uu2 = enigma.unpack_unorm2x16_to_float %pu2 : i32 -> vector<2xf32>
  // CHECK: enigma.unpack_srgb_unorm4x8_to_float
  %usr = enigma.unpack_srgb_unorm4x8_to_float %psr : i32 -> vector<4xf32>
  // CHECK: enigma.unpack_unorm10a2_to_float
  %u10 = enigma.unpack_unorm10a2_to_float %p10 : i32 -> vector<4xf32>
  enigma.return
}

// ============================================================================
// Section 15: Matrix operations
// ============================================================================

// CHECK-LABEL: enigma.kernel @matrix_ops
enigma.kernel @matrix_ops(%buf: memref<?xf32>) {
  %id = enigma.thread_position_in_grid x
  %fval = memref.load %buf[%id] : memref<?xf32>

  // CHECK: enigma.determinant
  %det = enigma.determinant %fval : f32 -> f32
  enigma.return
}

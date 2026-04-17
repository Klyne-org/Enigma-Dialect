// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// Bug 2 regression test: atomics on threadgroup memory (memory space 2)
// must cast to `threadgroup atomic_*`, not `device atomic_*`.

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void tg_atomic_test(
module {
  enigma.kernel @tg_atomic_test(%out: memref<?xi32>) {
    %tid = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : i32
    %c5 = arith.constant 5 : i32

    %shared = enigma.threadgroup_alloc : memref<64xi32, 2>

    // CHECK: atomic_load_explicit((threadgroup atomic_int*)
    %loaded = enigma.atomic_load %shared[%c0] relaxed : memref<64xi32, 2> -> i32

    // CHECK: atomic_store_explicit((threadgroup atomic_int*)
    enigma.atomic_store %c1, %shared[%c0] relaxed : i32, memref<64xi32, 2>

    // CHECK: atomic_fetch_add_explicit((threadgroup atomic_int*)
    %old_add = enigma.atomic_fetch_add %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_sub_explicit((threadgroup atomic_int*)
    %old_sub = enigma.atomic_fetch_sub %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_min_explicit((threadgroup atomic_int*)
    %old_min = enigma.atomic_fetch_min %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_max_explicit((threadgroup atomic_int*)
    %old_max = enigma.atomic_fetch_max %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_and_explicit((threadgroup atomic_int*)
    %old_and = enigma.atomic_fetch_and %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_or_explicit((threadgroup atomic_int*)
    %old_or = enigma.atomic_fetch_or %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_fetch_xor_explicit((threadgroup atomic_int*)
    %old_xor = enigma.atomic_fetch_xor %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_exchange_explicit((threadgroup atomic_int*)
    %old_xchg = enigma.atomic_exchange %shared[%c0], %c1 relaxed : memref<64xi32, 2>, i32

    // CHECK: atomic_compare_exchange_weak_explicit((threadgroup atomic_int*)
    %ok = enigma.atomic_compare_exchange_weak %shared[%c0], %c1, %c5 relaxed relaxed : memref<64xi32, 2>, i32

    %result = memref.load %shared[%c0] : memref<64xi32, 2>
    memref.store %result, %out[%tid] : memref<?xi32>
    enigma.return
  }
}

// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void atomic_test(
module {
  enigma.kernel @atomic_test(%buf: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : i32

    // CHECK: atomic_load_explicit
    // CHECK-SAME: memory_order_relaxed
    %loaded = enigma.atomic_load %buf[%c0] relaxed : memref<?xi32> -> i32

    // CHECK: atomic_store_explicit
    // CHECK-SAME: memory_order_release
    enigma.atomic_store %c1, %buf[%c0] release : i32, memref<?xi32>

    // CHECK: atomic_fetch_add_explicit
    // CHECK-SAME: memory_order_relaxed
    %old_add = enigma.atomic_fetch_add %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_fetch_sub_explicit
    %old_sub = enigma.atomic_fetch_sub %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_fetch_min_explicit
    %old_min = enigma.atomic_fetch_min %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_fetch_max_explicit
    %old_max = enigma.atomic_fetch_max %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_exchange_explicit
    %old_xchg = enigma.atomic_exchange %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_compare_exchange_weak_explicit
    %c5 = arith.constant 5 : i32
    %ok = enigma.atomic_compare_exchange_weak %buf[%c0], %c1, %c5 acq_rel relaxed : memref<?xi32>, i32

    enigma.return
  }
}

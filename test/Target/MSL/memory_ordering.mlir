// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// memory_ordering.mlir — Tests that atomic memory orderings are correctly emitted
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   Verifies that the emitter respects the memory_order attribute on atomic
//   ops. Note: Metal device-address-space atomics only support relaxed
//   ordering. Acquire/release/acq_rel are only valid for threadgroup atomics.
//   This test validates relaxed ordering on device atomics (the common case).
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void ordering_test(
module {
  enigma.kernel @ordering_test(%buf: memref<?xi32>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : i32

    // Device atomics: relaxed is the only valid ordering
    // CHECK: atomic_load_explicit
    // CHECK-SAME: memory_order_relaxed
    %v0 = enigma.atomic_load %buf[%c0] relaxed : memref<?xi32> -> i32

    // CHECK: atomic_store_explicit
    // CHECK-SAME: memory_order_relaxed
    enigma.atomic_store %c1, %buf[%c0] relaxed : i32, memref<?xi32>

    // CHECK: atomic_fetch_add_explicit
    // CHECK-SAME: memory_order_relaxed
    %v2 = enigma.atomic_fetch_add %buf[%c0], %c1 relaxed : memref<?xi32>, i32

    // CHECK: atomic_compare_exchange_weak_explicit
    // CHECK-SAME: memory_order_relaxed
    // CHECK-SAME: memory_order_relaxed
    %c5 = arith.constant 5 : i32
    %ok = enigma.atomic_compare_exchange_weak %buf[%c0], %c1, %c5 relaxed relaxed : memref<?xi32>, i32

    enigma.return
  }
}

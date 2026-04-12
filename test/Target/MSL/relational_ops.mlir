// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// relational_ops.mlir — Tests floating-point predicates and select emission
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void relational_test(
module {
  enigma.kernel @relational_test(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %buf[%id] : memref<?xf32>
    %w = memref.load %buf[%id] : memref<?xf32>

    // CHECK: isnan(
    %nan = enigma.isnan %v : f32
    // CHECK: isinf(
    %inf = enigma.isinf %v : f32
    // CHECK: isfinite(
    %fin = enigma.isfinite %v : f32

    // CHECK: select(
    %sel = enigma.select %v, %w, %nan : f32

    memref.store %sel, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

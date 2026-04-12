// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// comparison_ops.mlir — Tests arith comparison and conditional emission
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void cmp_test(
module {
  enigma.kernel @cmp_test(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %a = memref.load %buf[%id] : memref<?xf32>
    %b = memref.load %buf[%id] : memref<?xf32>

    // CHECK: ==
    %eq = arith.cmpf oeq, %a, %b : f32
    // CHECK: <
    %lt = arith.cmpf olt, %a, %b : f32
    // CHECK: >=
    %ge = arith.cmpf oge, %a, %b : f32
    // CHECK: !=
    %ne = arith.cmpf one, %a, %b : f32

    memref.store %a, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

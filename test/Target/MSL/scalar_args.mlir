// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// scalar_args.mlir — Tests that scalar kernel arguments emit valid MSL syntax
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   In MSL, scalar kernel arguments bound to [[buffer(N)]] must use
//   constant reference syntax: "constant float& v0 [[buffer(0)]]"
//   not bare "float v0 [[buffer(0)]]" which is invalid MSL.
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void scale(
// CHECK:         device float* v{{[0-9]+}} {{\[\[}}buffer(0)]],
// CHECK:         constant float& v{{[0-9]+}} {{\[\[}}buffer(1)]],
// CHECK:         constant int& v{{[0-9]+}} {{\[\[}}buffer(2)]],
module {
  enigma.kernel @scale(%buf: memref<?xf32>,
                       %factor: f32,
                       %count: i32) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %buf[%id] : memref<?xf32>
    %scaled = arith.mulf %val, %factor : f32
    memref.store %scaled, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

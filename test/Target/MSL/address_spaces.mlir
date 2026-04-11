// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// address_spaces.mlir — MSL emission test for address-space aware memrefs
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   Verifies that kernel arguments with different memref memory spaces
//   emit the correct MSL address-space qualifiers:
//     memory space 0 (default) -> device
//     memory space 1           -> constant
//
//   The test uses a kernel that reads from a `constant` buffer and writes
//   to a `device` buffer — a common pattern for lookup tables and weights.
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void scale_constant(
// CHECK:         constant float* v0 {{\[\[}}buffer(0)]],
// CHECK:         device float* v1 {{\[\[}}buffer(1)]],
// CHECK:         uint3 _tpg {{\[\[}}thread_position_in_grid]]
// CHECK:       ) {

// CHECK:         uint v{{[0-9]+}} = _tpg.x;
// CHECK:         float v{{[0-9]+}} = v0[
// CHECK:         float v{{[0-9]+}} = v{{[0-9]+}} + v{{[0-9]+}};
// CHECK:         v1[
// CHECK:       }

module {
  enigma.kernel @scale_constant(%weights: memref<?xf32, 1>,
                                %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %w = memref.load %weights[%id] : memref<?xf32, 1>
    %w2 = arith.addf %w, %w : f32
    memref.store %w2, %out[%id] : memref<?xf32>
    enigma.return
  }
}

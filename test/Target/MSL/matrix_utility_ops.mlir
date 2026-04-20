// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// matrix_utility_ops.mlir — Tests for mat_make, matmul, transpose, determinant
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void matrix_ops(
module {
  enigma.kernel @matrix_ops(%out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x

    %a = arith.constant 1.0 : f32
    %b = arith.constant 2.0 : f32
    %c = arith.constant 3.0 : f32
    %d = arith.constant 4.0 : f32

    // Build two column vectors for a 2x2 matrix
    %col0 = enigma.vec_make %a, %b : f32, f32 -> vector<2xf32>
    %col1 = enigma.vec_make %c, %d : f32, f32 -> vector<2xf32>

    // mat_make: construct a 2x2 matrix from column vectors
    // CHECK: float2x2
    %m = enigma.mat_make %col0, %col1 : vector<2xf32>, vector<2xf32> -> vector<2x2xf32>

    // transpose
    // CHECK: transpose(
    %mt = enigma.transpose %m : vector<2x2xf32> -> vector<2x2xf32>

    // determinant
    // CHECK: determinant(
    %det = enigma.determinant %m : vector<2x2xf32> -> f32

    // matmul
    // CHECK: *
    %mm = enigma.matmul %m, %mt : vector<2x2xf32>, vector<2x2xf32> -> vector<2x2xf32>

    memref.store %det, %out[%id] : memref<?xf32>
    enigma.return
  }
}

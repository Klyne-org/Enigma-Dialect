// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

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

    %col0 = enigma.vec_make %a, %b : f32, f32 -> vector<2xf32>
    %col1 = enigma.vec_make %c, %d : f32, f32 -> vector<2xf32>

    // CHECK: float2x2
    %m = enigma.mat_make %col0, %col1 : vector<2xf32>, vector<2xf32> -> vector<2x2xf32>

    // CHECK: transpose(
    %mt = enigma.transpose %m : vector<2x2xf32> -> vector<2x2xf32>

    // CHECK: determinant(
    %det = enigma.determinant %m : vector<2x2xf32> -> f32

    // CHECK: v{{[0-9]+}} * v{{[0-9]+}}
    %mm = enigma.matmul %m, %mt : vector<2x2xf32>, vector<2x2xf32> -> vector<2x2xf32>

    memref.store %det, %out[%id] : memref<?xf32>
    enigma.return
  }
}

// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// Bug 1 regression test: local variable declarations for 8x8 simdgroup
// matrices must use `simdgroup_float8x8`, not `float`.

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void simd_gemm(
module {
  enigma.kernel @simd_gemm(%A: memref<?xf32>, %B: memref<?xf32>, %C: memref<?xf32>) {
    %elems_per_row = arith.constant 8 : index
    %zero = arith.constant 0.0 : f32

    // CHECK: simdgroup_float8x8 {{v[0-9]+}};
    // CHECK: simdgroup_load
    %a = enigma.simdgroup_matrix_load %A, %elems_per_row
        : memref<?xf32> -> vector<8x8xf32>

    // CHECK: simdgroup_float8x8 {{v[0-9]+}};
    // CHECK: simdgroup_load
    %b = enigma.simdgroup_matrix_load %B, %elems_per_row
        : memref<?xf32> -> vector<8x8xf32>

    // CHECK: simdgroup_float8x8 {{v[0-9]+}} = make_filled_simdgroup_matrix<float, 8, 8>
    %c = enigma.make_filled_simdgroup_matrix %zero
        : f32 -> vector<8x8xf32>

    // CHECK: simdgroup_float8x8 {{v[0-9]+}};
    // CHECK: simdgroup_multiply_accumulate
    %r = enigma.simdgroup_multiply_accumulate %a, %b, %c
        : vector<8x8xf32>, vector<8x8xf32>, vector<8x8xf32> -> vector<8x8xf32>

    // CHECK: simdgroup_store
    enigma.simdgroup_matrix_store %r, %C, %elems_per_row
        : vector<8x8xf32>, memref<?xf32>

    enigma.return
  }
}

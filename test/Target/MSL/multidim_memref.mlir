// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// multidim_memref.mlir — Tests linearized index emission for multi-dim memrefs
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   Verifies that 2D memref access correctly emits row-major linearized
//   indices: for memref<MxNxf32>[i, j] the emitted index must be "i * N + j".
//   This was a bug where the emitter produced a comment placeholder instead
//   of the actual stride.
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void matmul_load(
module {
  enigma.kernel @matmul_load(%A: memref<64x128xf32>,
                             %B: memref<128x64xf32>,
                             %C: memref<64x64xf32>) {
    %id = enigma.thread_position_in_grid x

    // 2D load from A[id, id] should emit "v{{.*}} * 128 + v{{.*}}"
    // CHECK: v{{[0-9]+}} * 128 + v{{[0-9]+}}
    %a = memref.load %A[%id, %id] : memref<64x128xf32>

    // 2D load from B[id, id] should emit "v{{.*}} * 64 + v{{.*}}"
    // CHECK: v{{[0-9]+}} * 64 + v{{[0-9]+}}
    %b = memref.load %B[%id, %id] : memref<128x64xf32>

    %c = arith.addf %a, %b : f32

    // 2D store to C[id, id] should emit "v{{.*}} * 64 + v{{.*}}"
    // CHECK: v{{[0-9]+}} * 64 + v{{[0-9]+}}] =
    memref.store %c, %C[%id, %id] : memref<64x64xf32>

    enigma.return
  }
}

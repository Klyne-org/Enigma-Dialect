// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// cast_ops.mlir — Tests type cast and conversion emission
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void cast_test(
module {
  enigma.kernel @cast_test(%ibuf: memref<?xi32>, %fbuf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %iv = memref.load %ibuf[%id] : memref<?xi32>
    %fv = memref.load %fbuf[%id] : memref<?xf32>

    // CHECK: static_cast<float>
    %i2f = arith.sitofp %iv : i32 to f32

    // CHECK: static_cast<int>
    %f2i = arith.fptosi %fv : f32 to i32

    // CHECK: (int)
    %idx = arith.index_cast %id : index to i32

    memref.store %i2f, %fbuf[%id] : memref<?xf32>
    enigma.return
  }
}

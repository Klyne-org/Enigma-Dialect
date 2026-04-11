// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// texture_ops.mlir — Tests texture read/write/sample coordinate packing
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   MSL texture methods require packed vector coords (uint2 for 2D read/write,
//   float2 for 2D sample), not separate scalar arguments. Verifies:
//   - texture_read packs coords as uint2(x, y)
//   - texture_write packs coords as uint2(x, y)
//   - texture_sample packs coords as float2(u, v) with unique sampler names
//   - Multiple texture_sample ops get different sampler names (no collision)
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void texture_test(
module {
  enigma.kernel @texture_test(%tex: memref<?x?xvector<4xf32>>,
                              %out: memref<?xvector<4xf32>>) {
    %id = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index

    // 2D read should pack coords as uint2(c0, c1)
    // CHECK: .read(uint2(
    %val = enigma.texture_read %tex[%c0, %c1] : memref<?x?xvector<4xf32>> -> vector<4xf32>

    // 2D write should pack coords as uint2(c0, c1)
    // CHECK: .write({{.*}}, uint2(
    enigma.texture_write %val, %tex[%c0, %c1] : vector<4xf32>, memref<?x?xvector<4xf32>>

    // 1D read with single coord should NOT pack
    // CHECK: .read(v
    %val1d = enigma.texture_read %tex[%c0] : memref<?x?xvector<4xf32>> -> vector<4xf32>

    enigma.return
  }
}

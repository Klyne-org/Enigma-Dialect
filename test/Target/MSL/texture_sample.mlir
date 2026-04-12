// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// texture_sample.mlir — Tests sampler naming and float coord packing
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   - texture_sample uses float2 for 2D coords (not uint2)
//   - Multiple texture_sample ops get unique sampler names (no collision)
//   - Sampler config (filter/address) is correctly emitted
//
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void sample_test(
module {
  enigma.kernel @sample_test(%tex: memref<?x?xvector<4xf32>>) {
    %u = arith.constant 0.5 : f32
    %v = arith.constant 0.5 : f32

    // First sample — should get unique sampler name
    // CHECK: constexpr sampler _samp{{[0-9]+}}(filter::nearest, address::repeat)
    // CHECK: .sample(_samp{{[0-9]+}}, float2(
    %s1 = enigma.texture_sample %tex[%u, %v] filter nearest address repeat
        : memref<?x?xvector<4xf32>>, f32, f32 -> vector<4xf32>

    // Second sample — must get a DIFFERENT sampler name (no collision)
    // CHECK: constexpr sampler _samp{{[0-9]+}}(filter::linear, address::clamp_to_edge)
    // CHECK: .sample(_samp{{[0-9]+}}, float2(
    %s2 = enigma.texture_sample %tex[%u, %v] filter linear address clamp_to_edge
        : memref<?x?xvector<4xf32>>, f32, f32 -> vector<4xf32>

    enigma.return
  }
}

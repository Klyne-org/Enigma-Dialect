// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// instance_id.mlir — Tests for the instance_id thread-indexing op
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: vertex float4 instanced_vertex(
module {
  enigma.vertex @instanced_vertex(%positions: memref<?xf32>) -> vector<4xf32> {
    %vid = enigma.vertex_id

    // CHECK: instance_id
    %iid = enigma.instance_id

    %v = memref.load %positions[%vid] : memref<?xf32>
    %r = arith.constant 0.0 : f32
    %result = enigma.vec_make %v, %r, %r, %r : f32, f32, f32, f32 -> vector<4xf32>
    enigma.vertex_return %result : vector<4xf32>
  }
}

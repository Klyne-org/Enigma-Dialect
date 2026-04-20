// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// texture_queries.mlir — Tests for texture_get_width and texture_get_height
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void tex_query(
module {
  enigma.kernel @tex_query(%tex: memref<?x?xvector<4xf32>>,
                           %out: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x

    // CHECK: get_width(
    %w = enigma.texture_get_width %tex : memref<?x?xvector<4xf32>>

    // CHECK: get_height(
    %h = enigma.texture_get_height %tex : memref<?x?xvector<4xf32>>

    enigma.return
  }
}

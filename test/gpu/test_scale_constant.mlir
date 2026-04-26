// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = weights[i] * 2.0  (constant address space read)
// Input:  weights[i] = i (constant buffer)
// Expect: out[i] = 2*i

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void scale_constant(
// CHECK:         constant float*
// CHECK:         thread_position_in_grid

module {
  enigma.kernel @scale_constant(%weights: memref<?xf32, 1>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %w = memref.load %weights[%id] : memref<?xf32, 1>
    %sum = arith.addf %w, %w : f32
    memref.store %sum, %out[%id] : memref<?xf32>
    enigma.return
  }
}

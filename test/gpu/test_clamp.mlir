// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = clamp(in[i], 0.0, 1.0)
// Input:  in = [-2, -1, 0, 0.5, 1.0, 1.5, 2.0, 3.0, ...]
// Expect: out = [0, 0, 0, 0.5, 1.0, 1.0, 1.0, 1.0, ...]

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void clamp_test(
// CHECK:         thread_position_in_grid
// CHECK:         clamp(

module {
  enigma.kernel @clamp_test(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %lo = arith.constant 0.0 : f32
    %hi = arith.constant 1.0 : f32
    %r = enigma.clamp %v, %lo, %hi : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

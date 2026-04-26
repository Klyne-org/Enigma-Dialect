// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = sqrt(in[i])
// Input:  in[i] = (i+1)*(i+1)   i.e. 1, 4, 9, 16, 25, ...
// Expect: out[i] = i+1           i.e. 1, 2, 3, 4, 5, ...

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void math_sqrt(
// CHECK:         thread_position_in_grid
// CHECK:         sqrt(

module {
  enigma.kernel @math_sqrt(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %r = enigma.sqrt %v : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

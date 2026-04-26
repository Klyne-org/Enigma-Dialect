// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = -in[i]
// Input:  in[i] = i + 1
// Expect: out[i] = -(i + 1)

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void negate(
// CHECK:         thread_position_in_grid
// CHECK:         -v{{[0-9]+}}

module {
  enigma.kernel @negate(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %neg = arith.negf %v : f32
    memref.store %neg, %out[%id] : memref<?xf32>
    enigma.return
  }
}

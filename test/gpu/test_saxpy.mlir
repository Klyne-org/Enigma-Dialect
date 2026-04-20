// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: SAXPY  out[i] = a * x[i] + y[i]
// Input:  x[i] = i,  y[i] = 100,  a_buf[0] = 2.0
// Expect: out[i] = 2*i + 100

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void saxpy(
// CHECK:         thread_position_in_grid
// CHECK:         v{{[0-9]+}} * v{{[0-9]+}}
// CHECK:         v{{[0-9]+}} + v{{[0-9]+}}

module {
  enigma.kernel @saxpy(%a_buf: memref<?xf32, 1>, %x: memref<?xf32>,
                       %y: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %a = memref.load %a_buf[%c0] : memref<?xf32, 1>
    %xv = memref.load %x[%id] : memref<?xf32>
    %yv = memref.load %y[%id] : memref<?xf32>
    %ax = arith.mulf %a, %xv : f32
    %r = arith.addf %ax, %yv : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

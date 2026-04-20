// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = max(min(a[i], 100), 0) — integer min/max
// Input: a[i] = i * 3 - 50
// Expect: clamped to [0, 100]

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void imin_imax_test(
// CHECK:         thread_position_in_grid
// CHECK:         min(
// CHECK:         max(

module {
  enigma.kernel @imin_imax_test(%a: memref<?xi32>, %out: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %a[%id] : memref<?xi32>
    %c0 = arith.constant 0 : i32
    %c100 = arith.constant 100 : i32
    %t = enigma.imin %v, %c100 : i32
    %r = enigma.imax %t, %c0 : i32
    memref.store %r, %out[%id] : memref<?xi32>
    enigma.return
  }
}

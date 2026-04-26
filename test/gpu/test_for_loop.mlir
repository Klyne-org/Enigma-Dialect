// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: out[i] = sum(0..9) = 45 for all i (loop test)
// Uses scf.for to compute a simple sum

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void for_loop_test(
// CHECK:         thread_position_in_grid
// CHECK:         for (

module {
  enigma.kernel @for_loop_test(%out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %c10 = arith.constant 10 : index
    %c1 = arith.constant 1 : index
    %init = arith.constant 0.0 : f32
    %sum = scf.for %iv = %c0 to %c10 step %c1 iter_args(%acc = %init) -> f32 {
      %ivf = arith.index_cast %iv : index to i32
      %fiv = arith.sitofp %ivf : i32 to f32
      %new_acc = arith.addf %acc, %fiv : f32
      scf.yield %new_acc : f32
    }
    memref.store %sum, %out[%id] : memref<?xf32>
    enigma.return
  }
}

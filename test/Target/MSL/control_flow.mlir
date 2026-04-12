// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// control_flow.mlir — Tests scf.for and scf.if emission to MSL
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void loop_kernel(
module {
  enigma.kernel @loop_kernel(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %buf[%id] : memref<?xf32>

    %c0 = arith.constant 0 : index
    %c10 = arith.constant 10 : index
    %c1 = arith.constant 1 : index

    // CHECK: for (int
    scf.for %i = %c0 to %c10 step %c1 {
      memref.store %val, %buf[%id] : memref<?xf32>
      scf.yield
    }

    enigma.return
  }
}

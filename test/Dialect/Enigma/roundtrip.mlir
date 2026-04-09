// RUN: enigma-opt %s | enigma-opt | FileCheck %s

// =============================================================================
// roundtrip.mlir — verify that our ops parse and print symmetrically
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   The single most important property of an MLIR dialect: if you parse
//   a .mlir file and print it back out, the output must be parseable
//   again and produce identical IR. This catches bugs in the custom
//   parser/printer for `enigma.kernel` (which is hand-written in
//   EnigmaDialect.cpp — any asymmetry there will fail this test).
//
// HOW IT WORKS
//   `enigma-opt %s` parses this file and prints it. We pipe that output
//   into another `enigma-opt` to confirm it still parses. Then FileCheck
//   verifies the final printed form matches the `// CHECK:` lines below.
//
// HOW TO EXTEND
//   For every new op you add, append a block here that exercises its
//   assembly form. One CHECK line per interesting piece of syntax is
//   usually enough.
// =============================================================================

// CHECK-LABEL: enigma.kernel @vector_add
// CHECK-SAME:  (%{{.*}}: memref<?xf32>, %{{.*}}: memref<?xf32>, %{{.*}}: memref<?xf32>)
enigma.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>, %c: memref<?xf32>) {
  // CHECK: enigma.thread_position_in_grid x
  %id = enigma.thread_position_in_grid x
  %va = memref.load %a[%id] : memref<?xf32>
  %vb = memref.load %b[%id] : memref<?xf32>
  // CHECK: arith.addf
  %vc = arith.addf %va, %vb : f32
  memref.store %vc, %c[%id] : memref<?xf32>
  // CHECK: enigma.return
  enigma.return
}

// A second kernel exercising the barrier and y-dimension so we actually
// test more than one code path.
// CHECK-LABEL: enigma.kernel @barrier_demo
enigma.kernel @barrier_demo(%a: memref<?xf32>) {
  // CHECK: enigma.thread_position_in_threadgroup y
  %tid = enigma.thread_position_in_threadgroup y
  // CHECK: enigma.threadgroup_barrier
  enigma.threadgroup_barrier 2
  enigma.return
}

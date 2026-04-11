// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// vector_add.mlir — end-to-end MSL emission test for vector_add
// =============================================================================
//
// WHAT THIS TEST CHECKS
//   Feeds the canonical vector-add kernel through enigma-translate's
//   --enigma-to-msl direction and verifies the emitted MSL text, line by
//   line, against the expected output from the old demo. This is the
//   test that will fail the moment the MSLEmitter produces wrong code,
//   so it's your regression anchor.
//
// HOW IT RELATES TO THE "ORACLE"
//   The expected CHECK lines below are derived from the hand-written
//   reference `kernel.metal` that was compiled successfully by
//   `xcrun metal` in the old demo. That's the ground truth: if
//   enigma-translate starts emitting something different, either the
//   test is stale (update the CHECK lines) or the emitter regressed
//   (fix the emitter).
//
// HOW TO EXTEND
//   When you add a new op:
//     1. Write a new .mlir test file under test/Target/MSL/ that uses it.
//     2. Run enigma-translate on it by hand.
//     3. Compile the output with `xcrun metal -c -` to confirm it's
//        valid MSL. (Yes, do this even for tiny changes — this is the
//        oracle step.)
//     4. Paste the interesting lines of the output as FileCheck lines.
//
// =============================================================================

// The preamble is always emitted once at the top of the MSL file.
// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// The kernel function signature. Note that v0/v1/v2 are the stable
// names our emitter assigns to SSA values in visitation order.
// CHECK-LABEL: kernel void vector_add(
// CHECK:         device float* v0 {{\[\[}}buffer(0)]],
// CHECK:         device float* v1 {{\[\[}}buffer(1)]],
// CHECK:         device float* v2 {{\[\[}}buffer(2)]],
// CHECK:         uint3 _tpg {{\[\[}}thread_position_in_grid]]
// CHECK:       ) {

// The body — thread id, two loads, an add, a store.
// CHECK:         uint v{{[0-9]+}} = _tpg.x;
// CHECK:         float v{{[0-9]+}} = v0[
// CHECK:         float v{{[0-9]+}} = v1[
// CHECK:         float v{{[0-9]+}} = v{{[0-9]+}} + v{{[0-9]+}};
// CHECK:         v2[
// CHECK:       }

module {
  enigma.kernel @vector_add(%a: memref<?xf32>,
                            %b: memref<?xf32>,
                            %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %va = memref.load %a[%id] : memref<?xf32>
    %vb = memref.load %b[%id] : memref<?xf32>
    %vc = arith.addf %va, %vb : f32
    memref.store %vc, %out[%id] : memref<?xf32>
    enigma.return
  }
}

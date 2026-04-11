// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// math_precision.mlir — Tests fast/precise math precision prefixes
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void precision_test(
module {
  enigma.kernel @precision_test(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %buf[%id] : memref<?xf32>

    // Default precision (no prefix)
    // CHECK: float v{{[0-9]+}} = sin(
    %s = enigma.sin %v : f32

    // Fast precision (enum value 1)
    // CHECK: float v{{[0-9]+}} = fast::sin(
    %sf = enigma.sin %v {precision = 1 : i32} : f32

    // Precise precision (enum value 2)
    // CHECK: float v{{[0-9]+}} = precise::sin(
    %sp = enigma.sin %v {precision = 2 : i32} : f32

    memref.store %s, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

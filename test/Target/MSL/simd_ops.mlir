// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void simd_reduction(
module {
  enigma.kernel @simd_reduction(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %buf[%id] : memref<?xf32>
    // CHECK: simd_sum(
    %sum = enigma.simd_sum %val : f32
    // CHECK: simd_product(
    %prod = enigma.simd_product %val : f32
    // CHECK: simd_min(
    %mn = enigma.simd_min %val : f32
    // CHECK: simd_max(
    %mx = enigma.simd_max %val : f32
    // CHECK: simd_prefix_exclusive_sum(
    %pxs = enigma.simd_prefix_exclusive_sum %val : f32
    // CHECK: simd_prefix_inclusive_sum(
    %pis = enigma.simd_prefix_inclusive_sum %val : f32
    memref.store %sum, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

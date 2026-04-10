// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void simd_shuffle_test(
module {
  enigma.kernel @simd_shuffle_test(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %val = memref.load %buf[%id] : memref<?xf32>
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index

    // CHECK: simd_shuffle(
    %sh = enigma.simd_shuffle %val, %c4 : f32
    // CHECK: simd_shuffle_up(
    %shup = enigma.simd_shuffle_up %val, %c4 : f32
    // CHECK: simd_shuffle_down(
    %shdn = enigma.simd_shuffle_down %val, %c4 : f32
    // CHECK: simd_shuffle_xor(
    %shxor = enigma.simd_shuffle_xor %val, %c4 : f32
    // CHECK: simd_broadcast(
    %bcast = enigma.simd_broadcast %val, %c0 : f32

    memref.store %bcast, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

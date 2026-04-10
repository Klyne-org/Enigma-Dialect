// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void integer_test(
module {
  enigma.kernel @integer_test(%buf: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %buf[%id] : memref<?xi32>
    %w = memref.load %buf[%id] : memref<?xi32>

    // CHECK: popcount(
    %pc = enigma.popcount %v : i32
    // CHECK: clz(
    %clz = enigma.clz %v : i32
    // CHECK: ctz(
    %ctz = enigma.ctz %v : i32
    // CHECK: reverse_bits(
    %rb = enigma.reverse_bits %v : i32
    // CHECK: abs_diff(
    %ad = enigma.abs_diff %v, %w : i32
    // CHECK: add_sat(
    %as = enigma.add_sat %v, %w : i32
    // CHECK: sub_sat(
    %ss = enigma.sub_sat %v, %w : i32
    // CHECK: mul_hi(
    %mh = enigma.mul_hi %v, %w : i32
    // CHECK: rotate(
    %rot = enigma.rotate %v, %w : i32
    // CHECK: extract_bits(
    %eb = enigma.extract_bits %v 4 8 : i32
    // CHECK: insert_bits(
    %ib = enigma.insert_bits %v, %w 4 8 : i32
    // CHECK: mad_sat(
    %ms = enigma.mad_sat %v, %w, %v : i32

    memref.store %pc, %buf[%id] : memref<?xi32>
    enigma.return
  }
}

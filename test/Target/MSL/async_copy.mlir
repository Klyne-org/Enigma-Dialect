// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// File-scope async-copy preamble (must precede every kernel definition).
// CHECK: struct _enigma_async_event_t;
// CHECK: __asm("air.simdgroup_async_copy_1d.p3i8.p1i8")
// CHECK: __asm("air.simdgroup_async_copy_1d.p1i8.p3i8")
// CHECK: __asm("air.simdgroup_async_copy_2d.p3i8.p1i8")
// CHECK: __asm("air.simdgroup_async_copy_2d.p1i8.p3i8")
// CHECK: __asm("air.wait_simdgroup_events")

// CHECK-LABEL: kernel void async_copy_demo(
module {
  enigma.kernel @async_copy_demo(%A: memref<?xf32>, %B: memref<?xf32>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c64 = arith.constant 64 : index
    %c8 = arith.constant 8 : index

    %tile = enigma.threadgroup_alloc : memref<64xf32, 2>

    // CHECK: __enigma_async_copy_1d_d2t(
    %ev0 = enigma.async_copy_1d_d2t %tile [%c0] from %A [%c0], %c64
        : memref<64xf32, 2>, memref<?xf32>

    // CHECK: __enigma_async_copy_2d_d2t(
    %ev1 = "enigma.async_copy_2d_d2t"(%tile, %c0, %c8, %A, %c0, %c64, %c8, %c8)
        : (memref<64xf32, 2>, index, index, memref<?xf32>, index, index, index, index) -> i64

    // CHECK: __enigma_wait_async_events(2,
    enigma.async_copy_wait %ev0, %ev1

    enigma.threadgroup_barrier mem_threadgroup

    // CHECK: __enigma_async_copy_1d_t2d(
    %ev2 = enigma.async_copy_1d_t2d %B [%c0] from %tile [%c0], %c64
        : memref<?xf32>, memref<64xf32, 2>

    // CHECK: __enigma_async_copy_2d_t2d(
    %ev3 = "enigma.async_copy_2d_t2d"(%B, %c0, %c64, %tile, %c0, %c8, %c8, %c8)
        : (memref<?xf32>, index, index, memref<64xf32, 2>, index, index, index, index) -> i64

    // CHECK: __enigma_wait_async_events(2,
    enigma.async_copy_wait %ev2, %ev3
    enigma.return
  }
}

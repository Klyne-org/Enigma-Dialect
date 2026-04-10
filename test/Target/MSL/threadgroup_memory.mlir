// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void tg_memory_test(
module {
  enigma.kernel @tg_memory_test(%in: memref<?xf32>, %out: memref<?xf32>) {
    %tid = enigma.thread_position_in_grid x
    %ltid = enigma.thread_position_in_threadgroup x

    // CHECK: threadgroup float {{.*}}[256]
    %shared = enigma.threadgroup_alloc : memref<256xf32, 2>

    %val = memref.load %in[%tid] : memref<?xf32>
    memref.store %val, %shared[%ltid] : memref<256xf32, 2>

    // CHECK: threadgroup_barrier(mem_flags::mem_threadgroup)
    enigma.threadgroup_barrier mem_threadgroup

    %out_val = memref.load %shared[%ltid] : memref<256xf32, 2>
    memref.store %out_val, %out[%tid] : memref<?xf32>
    enigma.return
  }
}

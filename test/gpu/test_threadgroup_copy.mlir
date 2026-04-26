// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// GPU test: copy through threadgroup shared memory
// Input:  in[i] = i * 10.0
// Expect: out[i] = i * 10.0  (pass-through via shared mem + barrier)

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void threadgroup_copy(
// CHECK:         threadgroup float
// CHECK:         threadgroup_barrier(mem_flags::mem_threadgroup)

module {
  enigma.kernel @threadgroup_copy(%in: memref<?xf32>, %out: memref<?xf32>) {
    %gid = enigma.thread_position_in_grid x
    %lid = enigma.thread_position_in_threadgroup x
    %shared = enigma.threadgroup_alloc : memref<256xf32, 2>
    %val = memref.load %in[%gid] : memref<?xf32>
    memref.store %val, %shared[%lid] : memref<256xf32, 2>
    enigma.threadgroup_barrier mem_threadgroup
    %out_val = memref.load %shared[%lid] : memref<256xf32, 2>
    memref.store %out_val, %out[%gid] : memref<?xf32>
    enigma.return
  }
}

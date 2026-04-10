// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// =============================================================================
// A realistic parallel reduction kernel using threadgroup memory + SIMD ops.
// Demonstrates how multiple Enigma features compose in a real algorithm.
// =============================================================================

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void parallel_reduce(
module {
  enigma.kernel @parallel_reduce(%input: memref<?xf32>,
                                 %output: memref<?xf32>) {
    %tid = enigma.thread_position_in_grid x
    %ltid = enigma.thread_position_in_threadgroup x
    %sgidx = enigma.simdgroup_index_in_threadgroup x

    // Load input value
    %val = memref.load %input[%tid] : memref<?xf32>

    // Phase 1: SIMD-level reduction (32 threads -> 1 value)
    // CHECK: simd_sum(
    %simd_sum = enigma.simd_sum %val : f32

    // Phase 2: Write SIMD results to threadgroup memory
    // CHECK: threadgroup float
    %shared = enigma.threadgroup_alloc : memref<32xf32, 2>
    memref.store %simd_sum, %shared[%sgidx] : memref<32xf32, 2>

    // Phase 3: Synchronize
    // CHECK: threadgroup_barrier(mem_flags::mem_threadgroup)
    enigma.threadgroup_barrier mem_threadgroup

    // Phase 4: First SIMD group reads back and reduces again
    %final = memref.load %shared[%ltid] : memref<32xf32, 2>
    // CHECK: simd_sum(
    %result = enigma.simd_sum %final : f32

    // Write final result
    %c0 = arith.constant 0 : index
    memref.store %result, %output[%c0] : memref<?xf32>
    enigma.return
  }
}

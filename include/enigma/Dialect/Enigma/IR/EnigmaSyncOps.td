//===- EnigmaSyncOps.td - Synchronization ops --------------*- tablegen -*-===//
//
// Barriers and threadgroup memory allocation.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_SYNC_OPS_TD
#define ENIGMA_SYNC_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"

// ============================================================================
// Barriers
// ============================================================================

def Enigma_ThreadgroupBarrierOp : Enigma_Op<"threadgroup_barrier", []> {
  let summary = "threadgroup_barrier(mem_flags) — synchronize threads in threadgroup";
  let description = [{
    All threads in the threadgroup must reach this point before any may
    proceed. Memory writes before the barrier become visible to peers
    after the barrier according to the specified mem_flags.

    ```mlir
    enigma.threadgroup_barrier mem_threadgroup
    ```
  }];
  let arguments = (ins Enigma_MemFlags:$mem_flags);
  let assemblyFormat = "$mem_flags attr-dict";
}

def Enigma_SimdgroupBarrierOp : Enigma_Op<"simdgroup_barrier", []> {
  let summary = "simdgroup_barrier(mem_flags) — synchronize threads in SIMD group";
  let description = [{
    Synchronizes threads within a single SIMD group (warp). Lighter weight
    than threadgroup_barrier — only 32 threads participate.

    ```mlir
    enigma.simdgroup_barrier mem_threadgroup
    ```
  }];
  let arguments = (ins Enigma_MemFlags:$mem_flags);
  let assemblyFormat = "$mem_flags attr-dict";
}

// ============================================================================
// Threadgroup Memory
// ============================================================================

def Enigma_ThreadgroupAllocOp : Enigma_Op<"threadgroup_alloc", []> {
  let summary = "Allocate threadgroup-shared memory";
  let description = [{
    Allocates memory in the threadgroup address space (memory space 2).
    Shared by all threads in the threadgroup. Backed by tile memory on
    Apple GPUs. Maps to `threadgroup T buf[N];` in MSL.

    ```mlir
    %shared = enigma.threadgroup_alloc : memref<256xf32, 2>
    ```
  }];
  let results = (outs AnyMemRef:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

#endif // ENIGMA_SYNC_OPS_TD

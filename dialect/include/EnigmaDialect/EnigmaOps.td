#ifndef ENIGMA_OPS_TD
#define ENIGMA_OPS_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "EnigmaDialect.td"
include "EnigmaTypes.td"

class Enigma_Op<string mnemonic, list<Trait> traits = []>
    : Op<Enigma_Dialect, mnemonic, traits>;

// --- Thread position in grid (1D convenience + per-axis) ---

def Enigma_ThreadPositionInGridOp : Enigma_Op<"thread_position_in_grid", [Pure]> {
  let summary = "Thread's absolute position in the compute grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadPositionInGridXOp : Enigma_Op<"thread_position_in_grid_x", [Pure]> {
  let summary = "X component of thread position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadPositionInGridYOp : Enigma_Op<"thread_position_in_grid_y", [Pure]> {
  let summary = "Y component of thread position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadPositionInGridZOp : Enigma_Op<"thread_position_in_grid_z", [Pure]> {
  let summary = "Z component of thread position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

// --- Threadgroup position in grid (block ID) ---

def Enigma_ThreadgroupPositionInGridXOp : Enigma_Op<"threadgroup_position_in_grid_x", [Pure]> {
  let summary = "X component of threadgroup position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadgroupPositionInGridYOp : Enigma_Op<"threadgroup_position_in_grid_y", [Pure]> {
  let summary = "Y component of threadgroup position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadgroupPositionInGridZOp : Enigma_Op<"threadgroup_position_in_grid_z", [Pure]> {
  let summary = "Z component of threadgroup position in grid";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

// --- Thread position in threadgroup (local thread ID) ---

def Enigma_ThreadPositionInThreadgroupXOp : Enigma_Op<"thread_position_in_threadgroup_x", [Pure]> {
  let summary = "X component of thread position within threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadPositionInThreadgroupYOp : Enigma_Op<"thread_position_in_threadgroup_y", [Pure]> {
  let summary = "Y component of thread position within threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_ThreadPositionInThreadgroupZOp : Enigma_Op<"thread_position_in_threadgroup_z", [Pure]> {
  let summary = "Z component of thread position within threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

// --- SIMD indexing ---

def Enigma_ThreadIndexInSimdgroupOp : Enigma_Op<"thread_index_in_simdgroup", [Pure]> {
  let summary = "Thread index within its 32-thread simdgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_SimdgroupIndexInThreadgroupOp : Enigma_Op<"simdgroup_index_in_threadgroup", [Pure]> {
  let summary = "Simdgroup index within the threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

// --- Grid size queries ---

def Enigma_ThreadsPerThreadgroupOp : Enigma_Op<"threads_per_threadgroup", [Pure]> {
  let summary = "Number of threads per threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Enigma_SimdgroupsPerThreadgroupOp : Enigma_Op<"simdgroups_per_threadgroup", [Pure]> {
  let summary = "Number of simdgroups per threadgroup";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

// --- Synchronization ---

def Enigma_ThreadgroupBarrierOp : Enigma_Op<"threadgroup_barrier", []> {
  let summary = "Threadgroup memory barrier";
  let assemblyFormat = "attr-dict";
}

#endif // ENIGMA_OPS_TD

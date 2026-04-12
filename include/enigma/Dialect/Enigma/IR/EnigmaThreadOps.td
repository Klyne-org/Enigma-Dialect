//===- EnigmaThreadOps.td - Thread indexing builtins -------*- tablegen -*-===//
//
// Metal's implicit [[...]] kernel parameters for thread/group positioning.
// Each op returns one component (x/y/z) of the uint3 builtin value.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_THREAD_OPS_TD
#define ENIGMA_THREAD_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// Shared base — all thread-index ops are Pure, take a dimension, return index.
class Enigma_ThreadIndexOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure]> {
  let summary = doc;
  let arguments = (ins Enigma_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

// --- 3D builtins (take x/y/z dimension) ---

def Enigma_ThreadPositionInGridOp
    : Enigma_ThreadIndexOp<"thread_position_in_grid",
        "Global thread id [[thread_position_in_grid]]">;

def Enigma_ThreadgroupPositionInGridOp
    : Enigma_ThreadIndexOp<"threadgroup_position_in_grid",
        "Threadgroup id [[threadgroup_position_in_grid]]">;

def Enigma_ThreadPositionInThreadgroupOp
    : Enigma_ThreadIndexOp<"thread_position_in_threadgroup",
        "Local thread id [[thread_position_in_threadgroup]]">;

def Enigma_ThreadsPerThreadgroupOp
    : Enigma_ThreadIndexOp<"threads_per_threadgroup",
        "Threads per threadgroup [[threads_per_threadgroup]]">;

def Enigma_ThreadIndexInThreadgroupOp
    : Enigma_ThreadIndexOp<"thread_index_in_threadgroup",
        "Flat thread index within threadgroup [[thread_index_in_threadgroup]]">;

def Enigma_ThreadgroupsPerGridOp
    : Enigma_ThreadIndexOp<"threadgroups_per_grid",
        "Threadgroups per grid [[threadgroups_per_grid]]">;

def Enigma_ThreadsPerGridOp
    : Enigma_ThreadIndexOp<"threads_per_grid",
        "Total threads per grid [[threads_per_grid]]">;

def Enigma_GridSizeOp
    : Enigma_ThreadIndexOp<"grid_size",
        "Grid dimensions [[grid_size]]">;

// --- SIMD-related indexing ---

def Enigma_SimdgroupIndexInThreadgroupOp
    : Enigma_ThreadIndexOp<"simdgroup_index_in_threadgroup",
        "SIMD group index [[simdgroup_index_in_threadgroup]]">;

def Enigma_ThreadIndexInSimdgroupOp
    : Enigma_ThreadIndexOp<"thread_index_in_simdgroup",
        "Thread index within SIMD group [[thread_index_in_simdgroup]]">;

def Enigma_ThreadsPerSimdgroupOp
    : Enigma_ThreadIndexOp<"threads_per_simdgroup",
        "Threads per SIMD group [[threads_per_simdgroup]]">;

def Enigma_SimdgroupsPerThreadgroupOp
    : Enigma_ThreadIndexOp<"simdgroups_per_threadgroup",
        "SIMD groups per threadgroup [[simdgroups_per_threadgroup]]">;

// --- Vertex/fragment stage indexing ---

def Enigma_VertexIdOp : Enigma_Op<"vertex_id", [Pure]> {
  let summary = "Vertex identifier [[vertex_id]]";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict";
}

def Enigma_InstanceIdOp : Enigma_Op<"instance_id", [Pure]> {
  let summary = "Instance identifier [[instance_id]]";
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict";
}

#endif // ENIGMA_THREAD_OPS_TD

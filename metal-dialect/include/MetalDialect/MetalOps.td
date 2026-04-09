include "MetalDialect.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/EnumAttr.td"

// Base class for all Metal ops
class Metal_Op<string mnemonic, list<Trait> traits = []>
    : Op<Metal_Dialect, mnemonic, traits>;

//===----------------------------------------------------------------------===//
// Dimension enum attribute (x, y, z)
//===----------------------------------------------------------------------===//
def Metal_DimX : I32EnumAttrCase<"x", 0>;
def Metal_DimY : I32EnumAttrCase<"y", 1>;
def Metal_DimZ : I32EnumAttrCase<"z", 2>;

def Metal_Dimension : I32EnumAttr<"Dimension", "GPU dimension",
    [Metal_DimX, Metal_DimY, Metal_DimZ]> {
  let cppNamespace = "::metal";
}

//===----------------------------------------------------------------------===//
// Kernel function op
//===----------------------------------------------------------------------===//
def Metal_KernelOp : Metal_Op<"kernel", [IsolatedFromAbove]> {
  let summary = "Metal compute kernel function";
  let arguments = (ins
    StrAttr:$sym_name,
    TypeAttrOf<FunctionType>:$function_type
  );
  let regions = (region AnyRegion:$body);
  let hasCustomAssemblyFormat = 1;
}

//===----------------------------------------------------------------------===//
// Thread index ops
//===----------------------------------------------------------------------===//
def Metal_ThreadPositionInGridOp : Metal_Op<"thread_position_in_grid", [Pure]> {
  let summary = "Get thread position in grid (global thread id)";
  let arguments = (ins Metal_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

def Metal_ThreadgroupPositionInGridOp : Metal_Op<"threadgroup_position_in_grid", [Pure]> {
  let summary = "Get threadgroup position in grid (block id)";
  let arguments = (ins Metal_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

def Metal_ThreadPositionInThreadgroupOp : Metal_Op<"thread_position_in_threadgroup", [Pure]> {
  let summary = "Get thread position within threadgroup (local thread id)";
  let arguments = (ins Metal_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

def Metal_ThreadsPerThreadgroupOp : Metal_Op<"threads_per_threadgroup", [Pure]> {
  let summary = "Get number of threads per threadgroup (block dim)";
  let arguments = (ins Metal_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

//===----------------------------------------------------------------------===//
// Barrier op
//===----------------------------------------------------------------------===//
def Metal_ThreadgroupBarrierOp : Metal_Op<"threadgroup_barrier", []> {
  let summary = "Threadgroup memory barrier";
  let arguments = (ins I32Attr:$mem_flags);
  let assemblyFormat = "$mem_flags attr-dict";
}

//===----------------------------------------------------------------------===//
// Return op
//===----------------------------------------------------------------------===//
def Metal_ReturnOp : Metal_Op<"return", [Terminator]> {
  let summary = "Return from a Metal kernel (void)";
  let assemblyFormat = "attr-dict";
}

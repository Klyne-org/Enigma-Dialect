//===- EnigmaFuncOps.td - Function entry-point ops ---------*- tablegen -*-===//
//
// kernel / vertex / fragment entry points and their return terminators.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_FUNC_OPS_TD
#define ENIGMA_FUNC_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/BuiltinAttributes.td"

def Enigma_KernelOp : Enigma_Op<"kernel", [IsolatedFromAbove]> {
  let summary = "Metal compute kernel function (kernel void)";
  let description = [{
    Defines a GPU compute entry point. Maps to `kernel void name(...)` in MSL.

    ```mlir
    enigma.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>,
                              %c: memref<?xf32>) {
      %i = enigma.thread_position_in_grid x
      %va = memref.load %a[%i] : memref<?xf32>
      %vb = memref.load %b[%i] : memref<?xf32>
      %vc = arith.addf %va, %vb : f32
      memref.store %vc, %c[%i] : memref<?xf32>
      enigma.return
    }
    ```
  }];
  let arguments = (ins StrAttr:$sym_name, TypeAttrOf<FunctionType>:$function_type);
  let regions = (region AnyRegion:$body);
  let hasCustomAssemblyFormat = 1;
}

def Enigma_VertexOp : Enigma_Op<"vertex", [IsolatedFromAbove]> {
  let summary = "Metal vertex shader function";
  let description = [{
    Defines a vertex shader entry point. Maps to `vertex RetType name(...)`.

    ```mlir
    enigma.vertex @vertex_main(%pos: memref<?x4xf32>) -> vector<4xf32> {
      %vid = enigma.vertex_id
      // ... compute position ...
      enigma.vertex_return %position : vector<4xf32>
    }
    ```
  }];
  let arguments = (ins StrAttr:$sym_name, TypeAttrOf<FunctionType>:$function_type);
  let regions = (region AnyRegion:$body);
  let hasCustomAssemblyFormat = 1;
}

def Enigma_FragmentOp : Enigma_Op<"fragment", [IsolatedFromAbove]> {
  let summary = "Metal fragment shader function";
  let description = [{
    Defines a fragment shader entry point. Maps to `fragment RetType name(...)`.

    ```mlir
    enigma.fragment @fragment_main(%in: vector<4xf32>) -> vector<4xf32> {
      enigma.fragment_return %in : vector<4xf32>
    }
    ```
  }];
  let arguments = (ins StrAttr:$sym_name, TypeAttrOf<FunctionType>:$function_type);
  let regions = (region AnyRegion:$body);
  let hasCustomAssemblyFormat = 1;
}

// --- Terminators ---

def Enigma_ReturnOp : Enigma_Op<"return", [Terminator]> {
  let summary = "Void return from enigma.kernel";
  let assemblyFormat = "attr-dict";
}

def Enigma_VertexReturnOp : Enigma_Op<"vertex_return", [Terminator]> {
  let summary = "Return value(s) from enigma.vertex";
  let arguments = (ins Variadic<AnyType>:$operands);
  let assemblyFormat = "$operands attr-dict `:` type($operands)";
}

def Enigma_FragmentReturnOp : Enigma_Op<"fragment_return", [Terminator]> {
  let summary = "Return value(s) from enigma.fragment";
  let arguments = (ins Variadic<AnyType>:$operands);
  let assemblyFormat = "$operands attr-dict `:` type($operands)";
}

#endif // ENIGMA_FUNC_OPS_TD

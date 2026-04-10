//===- EnigmaCastOps.td - Type cast operations -------------*- tablegen -*-===//
//
// Metal-specific casts, packing, and reinterpretation operations.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_CAST_OPS_TD
#define ENIGMA_CAST_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_MetalCastOp : Enigma_Op<"metal_cast", [Pure]> {
  let summary = "Metal type cast — static_cast<T>(x)";
  let arguments = (ins AnyType:$input);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `to` type($result)";
}

def Enigma_AsTypeOp : Enigma_Op<"as_type", [Pure]> {
  let summary = "Reinterpret cast — as_type<T>(x) in MSL";
  let description = [{
    Bitwise reinterpretation from one type to another of the same size.
    No conversion is performed; the bits are simply reinterpreted.

    ```mlir
    %i = enigma.as_type %f : f32 to i32
    ```
  }];
  let arguments = (ins AnyType:$input);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `to` type($result)";
}

// Pack/unpack ops are in EnigmaPackOps.td

#endif // ENIGMA_CAST_OPS_TD

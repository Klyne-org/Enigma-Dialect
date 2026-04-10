//===- EnigmaControlFlowOps.td - Function constant ops -----*- tablegen -*-===//
//
// Metal function constants for shader specialization.
// Note: actual control flow (for/if) is handled by emitting scf.for/scf.if
// from upstream MLIR dialects -- the emitter translates those directly.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_CONTROL_FLOW_OPS_TD
#define ENIGMA_CONTROL_FLOW_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/BuiltinAttributes.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_FunctionConstantOp : Enigma_Op<"function_constant", [Pure]> {
  let summary = "Metal function constant [[function_constant(N)]]";
  let description = [{
    Declares a specialization constant that is set at pipeline creation time.
    Maps to `constant T name [[function_constant(N)]]` in MSL.

    ```mlir
    %use_texture = enigma.function_constant 0 : i1
    %mode = enigma.function_constant 1 : i32
    ```
  }];
  let arguments = (ins I32Attr:$index);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$index attr-dict `:` type($result)";
}

#endif // ENIGMA_CONTROL_FLOW_OPS_TD

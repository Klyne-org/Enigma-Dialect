#ifndef ENIGMA_DIALECT_TD
#define ENIGMA_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_Dialect : Dialect {
  let name = "enigma";
  let cppNamespace = "::enigma";
  let summary = "Dialect for Apple Metal GPU compute kernels";
}

#endif // ENIGMA_DIALECT_TD

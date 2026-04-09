include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_Dialect : Dialect {
  let name = "enigma";
  let cppNamespace = "::enigma";
  let description = "Dialect for Apple Metal GPU compute";
}
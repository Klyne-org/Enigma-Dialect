include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Metal_Dialect : Dialect {
  let name = "metal";
  let cppNamespace = "::metal";
  let description = "Dialect for Apple Metal GPU compute";
}

#ifndef ENIGMA_TYPES_TD
#define ENIGMA_TYPES_TD

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "EnigmaDialect.td"

// Address spaces: 0=device, 2=constant, 3=threadgroup
def Enigma_DeviceMemory      : I64EnumAttrCase<"Device",      0>;
def Enigma_ConstantMemory    : I64EnumAttrCase<"Constant",    2>;
def Enigma_ThreadgroupMemory : I64EnumAttrCase<"Threadgroup", 3>;

def Enigma_AddressSpace : I64EnumAttr<
    "AddressSpace",
    "Metal memory address space",
    [Enigma_DeviceMemory, Enigma_ConstantMemory, Enigma_ThreadgroupMemory]
> {
  let cppNamespace = "::enigma";
}

def Enigma_LayoutAttr : Attr<
    CPred<"::llvm::isa<::mlir::StringAttr>($_self)">,
    "CuTe-style layout string"
>;

#endif // ENIGMA_TYPES_TD

/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Enum Utility Definitions                                                   *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|* From: MetalOps.td                                                          *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

namespace metal {

::llvm::StringRef stringifyDimension(Dimension val) {
  switch (val) {
    case Dimension::x: return "x";
    case Dimension::y: return "y";
    case Dimension::z: return "z";
  }
  return "";
}

::std::optional<Dimension> symbolizeDimension(::llvm::StringRef str) {
  return ::llvm::StringSwitch<::std::optional<Dimension>>(str)
      .Case("x", Dimension::x)
      .Case("y", Dimension::y)
      .Case("z", Dimension::z)
      .Default(::std::nullopt);
}
::std::optional<Dimension> symbolizeDimension(uint32_t value) {
  switch (value) {
  case 0: return Dimension::x;
  case 1: return Dimension::y;
  case 2: return Dimension::z;
  default: return ::std::nullopt;
  }
}

bool DimensionAttr::classof(::mlir::Attribute attr) {
  return (((::llvm::isa<::mlir::IntegerAttr>(attr))) && ((::llvm::cast<::mlir::IntegerAttr>(attr).getType().isSignlessInteger(32)))) && (((
    ::llvm::cast<::mlir::IntegerAttr>(attr).getValue().eq(::llvm::APInt(32, 0)))) || ((
    ::llvm::cast<::mlir::IntegerAttr>(attr).getValue().eq(::llvm::APInt(32, 1)))) || ((
    ::llvm::cast<::mlir::IntegerAttr>(attr).getValue().eq(::llvm::APInt(32, 2)))));
}
DimensionAttr DimensionAttr::get(::mlir::MLIRContext *context, Dimension val) {
  ::mlir::IntegerType intType = ::mlir::IntegerType::get(context, 32);
  ::mlir::IntegerAttr baseAttr = ::mlir::IntegerAttr::get(intType, static_cast<uint32_t>(val));
  return ::llvm::cast<DimensionAttr>(baseAttr);
}
Dimension DimensionAttr::getValue() const {
  return static_cast<Dimension>(::mlir::IntegerAttr::getValue().getZExtValue());
}

} // namespace metal

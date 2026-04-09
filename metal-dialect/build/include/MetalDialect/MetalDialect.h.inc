/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Dialect Declarations                                                       *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|* From: MetalOps.td                                                          *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

namespace metal {

/// Dialect for Apple Metal GPU compute
class MetalDialect : public ::mlir::Dialect {
  explicit MetalDialect(::mlir::MLIRContext *context);

  void initialize();
  friend class ::mlir::MLIRContext;
public:
  ~MetalDialect() override;
  static constexpr ::llvm::StringLiteral getDialectNamespace() {
    return ::llvm::StringLiteral("metal");
  }
};

} // namespace metal
MLIR_DECLARE_EXPLICIT_TYPE_ID(::metal::MetalDialect)

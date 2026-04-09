#include "mlir/IR/MLIRContext.h"
#include "mlir/Tools/mlir-translate/MlirTranslateMain.h"
#include "MetalDialect/MetalDialect.h"

// Defined in TranslateToMSL.cpp
void registerToMSLTranslation();

int main(int argc, char **argv) {
  registerToMSLTranslation();

  return failed(mlir::mlirTranslateMain(argc, argv, "Metal MLIR translator\n"));
}

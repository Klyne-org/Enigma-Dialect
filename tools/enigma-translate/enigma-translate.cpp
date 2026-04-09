//===- enigma-translate.cpp - The enigma-translate driver ----------------===//
//
// WHAT THIS BINARY IS
//   `enigma-translate` is to Enigma what `mlir-translate` is to upstream
//   MLIR: a command-line tool that runs a registered translation direction
//   on a .mlir file. The only translation we currently ship is
//   `enigma-to-msl`, but more will come (enigma-to-metallib,
//   enigma-to-air, …) and they all get registered through InitAll.
//
// EXAMPLE USAGE
//   enigma-translate --enigma-to-msl path/to/vector_add.mlir
//
// This file stays minimal by design — see enigma-opt.cpp for the same
// philosophy.
//
//===----------------------------------------------------------------------===//

#include "enigma/InitAll.h"

#include "mlir/IR/MLIRContext.h"
#include "mlir/Tools/mlir-translate/MlirTranslateMain.h"

int main(int argc, char **argv) {
  // Translations register themselves into a global registry when their
  // `registerXTranslation()` function runs. We call through InitAll so
  // every translation direction the project knows about is available.
  enigma::registerAllEnigmaTranslations();

  return mlir::failed(
      mlir::mlirTranslateMain(argc, argv, "Enigma MLIR translator\n"));
}

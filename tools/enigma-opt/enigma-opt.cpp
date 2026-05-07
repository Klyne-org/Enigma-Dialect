// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- enigma-opt.cpp - The enigma-opt driver -----------------------------===//
//
// WHAT THIS BINARY IS
//   `enigma-opt` is to Enigma what `mlir-opt` is to upstream MLIR: a
//   command-line driver that parses a .mlir file, runs passes on it, and
//   prints the result. It is the main development workhorse — every lit
//   test you write for the dialect will either be `enigma-opt %s` (round
//   trip) or `enigma-opt --some-pass %s` (pass test).
//
// WHAT IT DOES
//   1. Builds a DialectRegistry and registers every dialect we use.
//   2. Registers every pass we define.
//   3. Hands off to `MlirOptMain`, which parses argv, loads the input,
//      runs the pass pipeline, and writes the output.
//
//   The entire body is ~10 lines. All the heavy lifting is in MLIR's
//   `MlirOptMain` helper — do not try to reimplement option parsing here.
//
// HOW TO EXTEND
//   This file should stay tiny. When you add new dialects or passes, add
//   them to enigma::registerAllEnigmaDialects / registerAllEnigmaPasses
//   in lib/InitAll.cpp, not here. The golden rule: there are no "special
//   registrations" at the tool level. Every tool uses InitAll.
//
//===----------------------------------------------------------------------===//

#include "enigma/InitAll.h"

#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  enigma::registerAllEnigmaDialects(registry);
  enigma::registerAllEnigmaPasses();

  return mlir::asMainReturnCode(mlir::MlirOptMain(
      argc, argv, "Enigma MLIR optimizer driver\n", registry));
}

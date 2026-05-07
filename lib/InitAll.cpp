// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- InitAll.cpp - Implementation of the Enigma registration layer ------===//
//
// See include/enigma/InitAll.h for the why.
//
// HOW TO EXTEND
//   - New dialect: add a `registry.insert<YourDialect>();` line inside
//     registerAllEnigmaDialects.
//   - New pass: add `mlir::registerYourPass();` inside
//     registerAllEnigmaPasses.
//   - New translation: add its `registerXTranslation()` call inside
//     registerAllEnigmaTranslations.
//
//===----------------------------------------------------------------------===//

#include "enigma/InitAll.h"
#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"
#include "enigma/Target/MSL/TranslateToMSL.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/DialectRegistry.h"

void enigma::registerAllEnigmaDialects(mlir::DialectRegistry &registry) {
  // Our own dialect.
  registry.insert<enigma::EnigmaDialect>();

  // Upstream dialects we rely on. Any dialect whose ops appear in .mlir
  // input to `enigma-opt` or `enigma-translate` must be listed here,
  // otherwise parsing fails with "Dialect `foo' not found for custom op".
  registry.insert<mlir::arith::ArithDialect>();
  registry.insert<mlir::memref::MemRefDialect>();
  registry.insert<mlir::func::FuncDialect>();
  registry.insert<mlir::scf::SCFDialect>();

  // NEXT STEPS: when we add a conversion pass from upstream `gpu` dialect,
  // `registry.insert<mlir::gpu::GPUDialect>();` goes here.
}

void enigma::registerAllEnigmaPasses() {
  // Intentionally empty for now. The wiring is in place so the moment
  // you write your first pass (e.g. in lib/Dialect/Enigma/Transforms/),
  // you just add its register-call here and every tool picks it up.
  //
  // Example of what this will look like later:
  //
  //   mlir::registerEnigmaKernelOutliningPass();
  //   mlir::registerEnigmaArgumentBufferPackingPass();
}

void enigma::registerAllEnigmaTranslations() {
  registerToMSLTranslation();

  // NEXT STEPS:
  //   - registerToMetalLibTranslation(): drive `xcrun metal` from here,
  //     producing a .metallib directly instead of just MSL text.
  //   - registerToAIRTranslation(): emit Apple's intermediate AIR format.
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

#include "enigma-c/Dialects.h"

#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"
#include "enigma/Target/MSL/TranslateToMSL.h"

#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Pass.h"
#include "mlir/CAPI/Registration.h"
#include "mlir/CAPI/Support.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Transforms/Passes.h"

#include "llvm/ADT/StringRef.h"
#include "llvm/Support/raw_ostream.h"

#include <cstring>
#include <string>

MLIR_DEFINE_CAPI_DIALECT_REGISTRATION(Enigma, enigma,
                                      ::enigma::EnigmaDialect)

extern "C" {

MlirLogicalResult enigmaTranslateModuleToMSL(MlirOperation moduleOp,
                                             MlirStringCallback callback,
                                             void *userData) {
  mlir::Operation *op = unwrap(moduleOp);
  auto module = llvm::dyn_cast<mlir::ModuleOp>(op);
  if (!module) {
    return mlirLogicalResultFailure();
  }
  std::string buffer;
  llvm::raw_string_ostream os(buffer);
  if (mlir::failed(::enigma::translateToMSL(module, os))) {
    return mlirLogicalResultFailure();
  }
  os.flush();
  MlirStringRef ref{buffer.data(), buffer.size()};
  callback(ref, userData);
  return mlirLogicalResultSuccess();
}

MlirLogicalResult enigmaRunStandardPipeline(MlirOperation moduleOp) {
  mlir::Operation *op = unwrap(moduleOp);
  auto module = llvm::dyn_cast<mlir::ModuleOp>(op);
  if (!module) {
    return mlirLogicalResultFailure();
  }
  mlir::PassManager pm(module->getContext());
  pm.addPass(mlir::createCanonicalizerPass());
  pm.addPass(mlir::createCSEPass());
  if (mlir::failed(pm.run(module))) {
    return mlirLogicalResultFailure();
  }
  return mlirLogicalResultSuccess();
}

} // extern "C"

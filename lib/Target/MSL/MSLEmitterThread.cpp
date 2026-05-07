// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterThread.cpp - Thread indexing emission --------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitThreadIndex(Operation *op, llvm::StringRef builtinName,
                                 Dimension dim) {
  std::string paramName = getBuiltinParamName(builtinName);
  stream() << "    uint " << getName(op->getResult(0)) << " = "
           << paramName << getDimSuffix(dim) << ";\n";
}

void MSLEmitter::emitFlatThreadIndex(Operation *op,
                                     llvm::StringRef builtinName) {
  std::string paramName = getBuiltinParamName(builtinName);
  stream() << "    uint " << getName(op->getResult(0)) << " = "
           << paramName << ";\n";
}

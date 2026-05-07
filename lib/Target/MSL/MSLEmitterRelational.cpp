// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterRelational.cpp - Comparison, select, int min/max ---------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitFloatPredicate(Operation *op, llvm::StringRef funcName) {
  stream() << "    bool " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitSelect(SelectOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << " = select("
           << getName(op.getFalseVal()) << ", "
           << getName(op.getTrueVal()) << ", "
           << getName(op.getCondition()) << ");\n";
}

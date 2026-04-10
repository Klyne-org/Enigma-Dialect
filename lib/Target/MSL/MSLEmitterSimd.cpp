//===- MSLEmitterSimd.cpp - SIMD group operation emission -----------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitSimdUnary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitSimdBinary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ");\n";
}

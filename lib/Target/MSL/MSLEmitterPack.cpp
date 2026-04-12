//===- MSLEmitterPack.cpp - Pack/unpack operation emission ----------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitPackOp(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitUnpackOp(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

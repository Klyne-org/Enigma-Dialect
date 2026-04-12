//===- MSLEmitterInt.cpp - Integer intrinsic emission ---------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitIntUnary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitIntBinary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ");\n";
}

void MSLEmitter::emitIntTernary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ", "
           << getName(op->getOperand(2)) << ");\n";
}

void MSLEmitter::emitExtractBits(ExtractBitsOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = extract_bits(" << getName(op.getValue())
           << ", " << op.getOffset() << ", " << op.getBits() << ");\n";
}

void MSLEmitter::emitInsertBits(InsertBitsOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = insert_bits(" << getName(op.getBase())
           << ", " << getName(op.getInsert())
           << ", " << op.getOffset() << ", " << op.getBits() << ");\n";
}

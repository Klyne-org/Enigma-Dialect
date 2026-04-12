//===- MSLEmitterMath.cpp - Math built-in emission ------------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitMathUnary(Operation *op, llvm::StringRef funcName,
                               MathPrecision prec) {
  std::string ty = getTypeString(op->getResult(0).getType());
  std::string prefix = getMathPrecisionPrefix(prec);
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << prefix << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitMathBinary(Operation *op, llvm::StringRef funcName,
                                MathPrecision prec) {
  std::string ty = getTypeString(op->getResult(0).getType());
  std::string prefix = getMathPrecisionPrefix(prec);
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << prefix << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ");\n";
}

void MSLEmitter::emitMathTernary(Operation *op, llvm::StringRef funcName,
                                 MathPrecision prec) {
  std::string ty = getTypeString(op->getResult(0).getType());
  std::string prefix = getMathPrecisionPrefix(prec);
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << prefix << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ", "
           << getName(op->getOperand(2)) << ");\n";
}

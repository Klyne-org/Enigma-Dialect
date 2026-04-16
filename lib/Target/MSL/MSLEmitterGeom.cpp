//===- MSLEmitterGeom.cpp - Geometric / vector function emission ----------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitGeomBinaryScalar(Operation *op,
                                      llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ");\n";
}

void MSLEmitter::emitGeomUnaryScalar(Operation *op,
                                     llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitGeomVecBinary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ");\n";
}

void MSLEmitter::emitGeomVecUnary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "(" << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitGeomVecTernary(Operation *op, llvm::StringRef funcName) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << funcName << "("
           << getName(op->getOperand(0)) << ", "
           << getName(op->getOperand(1)) << ", "
           << getName(op->getOperand(2)) << ");\n";
}

void MSLEmitter::emitRefract(RefractOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = refract(" << getName(op.getIncident())
           << ", " << getName(op.getNormal())
           << ", " << getName(op.getEta()) << ");\n";
}

void MSLEmitter::emitVecMake(VecMakeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = " << ty
     << "(";
  llvm::interleaveComma(op.getElems(), os,
                        [&](mlir::Value v) { os << getName(v); });
  os << ");\n";
}

void MSLEmitter::emitVecExtract(VecExtractOp op) {
  static const char *kLanes[] = {".x", ".y", ".z", ".w"};
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << " = "
           << getName(op.getInput()) << kLanes[op.getLane()] << ";\n";
}

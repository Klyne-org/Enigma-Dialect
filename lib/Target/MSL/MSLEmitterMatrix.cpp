// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterMatrix.cpp - Matrix + simdgroup matrix emission ----------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitMatMake(MatMakeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = " << ty << "(";
  llvm::interleaveComma(op.getColumns(), os,
                        [&](mlir::Value v) { os << getName(v); });
  os << ");\n";
}

void MSLEmitter::emitMatMul(MatMulOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << " = "
           << getName(op.getLhs()) << " * " << getName(op.getRhs()) << ";\n";
}

void MSLEmitter::emitTranspose(TransposeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = transpose(" << getName(op.getInput()) << ");\n";
}

void MSLEmitter::emitDeterminant(DeterminantOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = determinant(" << getName(op.getInput()) << ");\n";
}

void MSLEmitter::emitSimdgroupMatLoad(SimdgroupMatLoadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << ";\n"
           << "    simdgroup_load(" << getName(op.getResult()) << ", "
           << getName(op.getSrc()) << ", "
           << getName(op.getElementsPerRow()) << ");\n";
}

void MSLEmitter::emitSimdgroupMatStore(SimdgroupMatStoreOp op) {
  stream() << "    simdgroup_store(" << getName(op.getMatrix()) << ", "
           << getName(op.getDst()) << ", "
           << getName(op.getElementsPerRow()) << ");\n";
}

void MSLEmitter::emitSimdgroupMatMulAcc(SimdgroupMatMulAccOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << ";\n"
           << "    simdgroup_multiply_accumulate(" << getName(op.getResult())
           << ", " << getName(op.getA())
           << ", " << getName(op.getB())
           << ", " << getName(op.getC()) << ");\n";
}

void MSLEmitter::emitMakeFilledSimdgroupMat(MakeFilledSimdgroupMatOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = make_filled_simdgroup_matrix<"
           << getTypeString(op.getValue().getType()) << ", 8, 8>("
           << getName(op.getValue()) << ");\n";
}

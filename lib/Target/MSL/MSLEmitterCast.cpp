// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterCast.cpp - Type cast emission ----------------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitMetalCast(MetalCastOp op) {
  std::string dstTy = getTypeString(op.getResult().getType());
  stream() << "    " << dstTy << " " << getName(op.getResult())
           << " = static_cast<" << dstTy << ">("
           << getName(op.getInput()) << ");\n";
}

void MSLEmitter::emitAsType(AsTypeOp op) {
  std::string dstTy = getTypeString(op.getResult().getType());
  stream() << "    " << dstTy << " " << getName(op.getResult())
           << " = as_type<" << dstTy << ">("
           << getName(op.getInput()) << ");\n";
}

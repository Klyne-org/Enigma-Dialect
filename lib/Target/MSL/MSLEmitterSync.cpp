// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterSync.cpp - Barriers + threadgroup memory emission --------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitBarrier(llvm::StringRef funcName, MemFlags flags) {
  stream() << "    " << funcName << "("
           << getMemFlagsString(flags) << ");\n";
}

void MSLEmitter::emitThreadgroupAlloc(ThreadgroupAllocOp op) {
  auto memrefType = cast<MemRefType>(op.getResult().getType());
  std::string elem = getTypeString(memrefType.getElementType());
  int64_t size = 1;
  for (auto dim : memrefType.getShape())
    size *= dim;
  stream() << "    threadgroup " << elem << " "
           << getName(op.getResult()) << "[" << size << "];\n";
}

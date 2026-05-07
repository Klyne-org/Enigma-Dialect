// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterAtomic.cpp - Atomic operation emission -------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

// Metal atomics on threadgroup memory must use the `threadgroup` address
// space qualifier. Deriving this from the memref's memory space (0 = device,
// 2 = threadgroup) avoids emitting a cast that crosses address spaces.
static llvm::StringRef addrSpaceOf(Value memref) {
  auto mrt = dyn_cast<MemRefType>(memref.getType());
  if (!mrt)
    return "device";
  if (auto ms = mrt.getMemorySpace())
    if (auto intAttr = dyn_cast<IntegerAttr>(ms))
      if (intAttr.getInt() == 2)
        return "threadgroup";
  return "device";
}

void MSLEmitter::emitAtomicLoad(AtomicLoadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult())
     << " = atomic_load_explicit((" << as << " atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicStore(AtomicStoreOp op) {
  std::string ty = getTypeString(op.getValue().getType());
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  auto &os = stream();
  os << "    atomic_store_explicit((" << as << " atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getName(op.getValue())
     << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicExchange(AtomicExchangeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult())
     << " = atomic_exchange_explicit((" << as << " atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getName(op.getValue())
     << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicCAS(AtomicCompareExchangeWeakOp op) {
  std::string ty = getTypeString(op.getExpected().getType());
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  auto &os = stream();
  os << "    " << ty << " _expected = " << getName(op.getExpected()) << ";\n";
  os << "    bool " << getName(op.getResult())
     << " = atomic_compare_exchange_weak_explicit((" << as << " atomic_"
     << ty << "*)&" << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", &_expected, " << getName(op.getDesired())
     << ", " << getMemoryOrderString(op.getSuccessOrder())
     << ", " << getMemoryOrderString(op.getFailureOrder()) << ");\n";
}

void MSLEmitter::emitAtomicRMW(Operation *op, llvm::StringRef funcName,
                               MemoryOrder order) {
  std::string ty = getTypeString(op->getResult(0).getType());
  Value memref = op->getOperand(0);
  llvm::StringRef as = addrSpaceOf(memref);
  auto &os = stream();
  os << "    " << ty << " " << getName(op->getResult(0))
     << " = " << funcName << "((" << as << " atomic_" << ty << "*)&"
     << getName(memref);
  // indices follow the memref (operand 0) up to the value operand
  unsigned numIndices = op->getNumOperands() - 2; // memref, ..indices.., value
  for (unsigned i = 1; i <= numIndices; ++i)
    os << "[" << getName(op->getOperand(i)) << "]";
  os << ", " << getName(op->getOperand(op->getNumOperands() - 1))
     << ", " << getMemoryOrderString(order) << ");\n";
}

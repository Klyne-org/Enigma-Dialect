// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterAtomic.cpp - Atomic operation emission -------------------===//
//
// Two emission shapes per op:
//
//  1. The buffer is a direct kernel argument that ``scanForAtomicArgs``
//     identified as being touched by atomic ops. Then ``emitFuncArgs`` has
//     already declared it as ``device atomic_T*``, and we just call the
//     atomic intrinsic on it with no cast. This is the spec-compliant
//     shape.
//
//  2. The buffer is derived (e.g. from a ``memref.cast``) so we can't tell
//     whether it was originally atomic-typed. We fall back to the legacy
//     pointer-cast at the use site for backwards compatibility. This is
//     undefined behavior per the MSL spec, so the runtime should be
//     migrated off it; in practice today's Metal toolchains accept it.
//
//===----------------------------------------------------------------------===//

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

// True iff ``memref`` is a kernel block argument whose slot was declared
// as ``device atomic_T*`` in the signature.
static bool isAtomicTypedArg(const MSLEmitter &e, Value memref) {
  auto blockArg = dyn_cast<BlockArgument>(memref);
  if (!blockArg)
    return false;
  return e.isAtomicArg(blockArg.getArgNumber());
}

void MSLEmitter::emitAtomicLoad(AtomicLoadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  if (isAtomicTypedArg(*this, op.getMemref())) {
    os << "    " << ty << " " << getName(op.getResult())
       << " = atomic_load_explicit(&" << getName(op.getMemref());
    for (auto idx : op.getIndices())
      os << "[" << getName(idx) << "]";
    os << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
    return;
  }
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  os << "    " << ty << " " << getName(op.getResult())
     << " = atomic_load_explicit((" << as << " atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicStore(AtomicStoreOp op) {
  std::string ty = getTypeString(op.getValue().getType());
  auto &os = stream();
  if (isAtomicTypedArg(*this, op.getMemref())) {
    os << "    atomic_store_explicit(&" << getName(op.getMemref());
    for (auto idx : op.getIndices())
      os << "[" << getName(idx) << "]";
    os << ", " << getName(op.getValue())
       << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
    return;
  }
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  os << "    atomic_store_explicit((" << as << " atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getName(op.getValue())
     << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicExchange(AtomicExchangeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  if (isAtomicTypedArg(*this, op.getMemref())) {
    os << "    " << ty << " " << getName(op.getResult())
       << " = atomic_exchange_explicit(&" << getName(op.getMemref());
    for (auto idx : op.getIndices())
      os << "[" << getName(idx) << "]";
    os << ", " << getName(op.getValue())
       << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
    return;
  }
  llvm::StringRef as = addrSpaceOf(op.getMemref());
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
  auto &os = stream();
  // Unique-name the `_expected` local so two CAS ops in the same scope
  // don't produce a C++ redeclaration error.
  std::string expectedVar = "_expected_" + std::to_string(nextVarId());
  os << "    " << ty << " " << expectedVar << " = "
     << getName(op.getExpected()) << ";\n";
  if (isAtomicTypedArg(*this, op.getMemref())) {
    os << "    bool " << getName(op.getResult())
       << " = atomic_compare_exchange_weak_explicit(&"
       << getName(op.getMemref());
    for (auto idx : op.getIndices())
      os << "[" << getName(idx) << "]";
    os << ", &" << expectedVar << ", " << getName(op.getDesired())
       << ", " << getMemoryOrderString(op.getSuccessOrder())
       << ", " << getMemoryOrderString(op.getFailureOrder()) << ");\n";
    return;
  }
  llvm::StringRef as = addrSpaceOf(op.getMemref());
  os << "    bool " << getName(op.getResult())
     << " = atomic_compare_exchange_weak_explicit((" << as << " atomic_"
     << ty << "*)&" << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", &" << expectedVar << ", " << getName(op.getDesired())
     << ", " << getMemoryOrderString(op.getSuccessOrder())
     << ", " << getMemoryOrderString(op.getFailureOrder()) << ");\n";
}

void MSLEmitter::emitAtomicRMW(Operation *op, llvm::StringRef funcName,
                               MemoryOrder order) {
  std::string ty = getTypeString(op->getResult(0).getType());
  Value memref = op->getOperand(0);
  auto &os = stream();
  // indices follow the memref (operand 0) up to the value operand
  unsigned numIndices = op->getNumOperands() - 2;
  if (isAtomicTypedArg(*this, memref)) {
    os << "    " << ty << " " << getName(op->getResult(0))
       << " = " << funcName << "(&" << getName(memref);
    for (unsigned i = 1; i <= numIndices; ++i)
      os << "[" << getName(op->getOperand(i)) << "]";
    os << ", " << getName(op->getOperand(op->getNumOperands() - 1))
       << ", " << getMemoryOrderString(order) << ");\n";
    return;
  }
  llvm::StringRef as = addrSpaceOf(memref);
  os << "    " << ty << " " << getName(op->getResult(0))
     << " = " << funcName << "((" << as << " atomic_" << ty << "*)&"
     << getName(memref);
  for (unsigned i = 1; i <= numIndices; ++i)
    os << "[" << getName(op->getOperand(i)) << "]";
  os << ", " << getName(op->getOperand(op->getNumOperands() - 1))
     << ", " << getMemoryOrderString(order) << ");\n";
}

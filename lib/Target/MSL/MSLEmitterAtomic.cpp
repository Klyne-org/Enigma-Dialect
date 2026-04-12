//===- MSLEmitterAtomic.cpp - Atomic operation emission -------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitAtomicLoad(AtomicLoadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult())
     << " = atomic_load_explicit((device atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicStore(AtomicStoreOp op) {
  std::string ty = getTypeString(op.getValue().getType());
  auto &os = stream();
  os << "    atomic_store_explicit((device atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getName(op.getValue())
     << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicExchange(AtomicExchangeOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult())
     << " = atomic_exchange_explicit((device atomic_" << ty << "*)&"
     << getName(op.getMemref());
  for (auto idx : op.getIndices())
    os << "[" << getName(idx) << "]";
  os << ", " << getName(op.getValue())
     << ", " << getMemoryOrderString(op.getMemoryOrder()) << ");\n";
}

void MSLEmitter::emitAtomicCAS(AtomicCompareExchangeWeakOp op) {
  std::string ty = getTypeString(op.getExpected().getType());
  auto &os = stream();
  os << "    " << ty << " _expected = " << getName(op.getExpected()) << ";\n";
  os << "    bool " << getName(op.getResult())
     << " = atomic_compare_exchange_weak_explicit((device atomic_"
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
  auto &os = stream();
  os << "    " << ty << " " << getName(op->getResult(0))
     << " = " << funcName << "((device atomic_" << ty << "*)&"
     << getName(op->getOperand(0));
  // indices follow the memref (operand 0) up to the value operand
  unsigned numIndices = op->getNumOperands() - 2; // memref, ..indices.., value
  for (unsigned i = 1; i <= numIndices; ++i)
    os << "[" << getName(op->getOperand(i)) << "]";
  os << ", " << getName(op->getOperand(op->getNumOperands() - 1))
     << ", " << getMemoryOrderString(order) << ");\n";
}

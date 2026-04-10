//===- MSLEmitterUpstream.cpp - arith / memref / return emission ----------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitLoad(memref::LoadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getMemRef()) << "[";
  for (unsigned i = 0, e = op.getIndices().size(); i < e; ++i) {
    if (i > 0) os << " * /* stride */ + ";
    os << getName(op.getIndices()[i]);
  }
  os << "];\n";
}

void MSLEmitter::emitStore(memref::StoreOp op) {
  auto &os = stream();
  os << "    " << getName(op.getMemRef()) << "[";
  for (unsigned i = 0, e = op.getIndices().size(); i < e; ++i) {
    if (i > 0) os << " * /* stride */ + ";
    os << getName(op.getIndices()[i]);
  }
  os << "] = " << getName(op.getValue()) << ";\n";
}

void MSLEmitter::emitArithBinOp(Operation *op, llvm::StringRef sym) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0)) << " = "
           << getName(op->getOperand(0)) << " " << sym << " "
           << getName(op->getOperand(1)) << ";\n";
}

void MSLEmitter::emitArithNeg(arith::NegFOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult()) << " = -"
           << getName(op.getOperand()) << ";\n";
}

void MSLEmitter::emitConstant(arith::ConstantOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = ";
  if (auto intAttr = dyn_cast<IntegerAttr>(op.getValue()))
    os << intAttr.getInt();
  else if (auto floatAttr = dyn_cast<FloatAttr>(op.getValue()))
    os << floatAttr.getValueAsDouble();
  else if (auto denseAttr = dyn_cast<DenseElementsAttr>(op.getValue())) {
    os << ty << "(";
    bool first = true;
    for (auto val : denseAttr.getValues<Attribute>()) {
      if (!first) os << ", ";
      if (auto f = dyn_cast<FloatAttr>(val))
        os << f.getValueAsDouble();
      else if (auto i = dyn_cast<IntegerAttr>(val))
        os << i.getInt();
      first = false;
    }
    os << ")";
  } else
    os << "/*unsupported const*/0";
  os << ";\n";
}

void MSLEmitter::emitIndexCast(arith::IndexCastOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    " << ty << " " << getName(op.getResult())
           << " = (" << ty << ")" << getName(op.getIn()) << ";\n";
}

void MSLEmitter::emitTypeCast(Operation *op) {
  std::string ty = getTypeString(op->getResult(0).getType());
  stream() << "    " << ty << " " << getName(op->getResult(0))
           << " = static_cast<" << ty << ">("
           << getName(op->getOperand(0)) << ");\n";
}

void MSLEmitter::emitCmpF(arith::CmpFOp op) {
  std::string ty = "bool";
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getLhs()) << " ";
  switch (op.getPredicate()) {
    case arith::CmpFPredicate::OEQ: case arith::CmpFPredicate::UEQ: os << "=="; break;
    case arith::CmpFPredicate::ONE: case arith::CmpFPredicate::UNE: os << "!="; break;
    case arith::CmpFPredicate::OLT: case arith::CmpFPredicate::ULT: os << "<"; break;
    case arith::CmpFPredicate::OLE: case arith::CmpFPredicate::ULE: os << "<="; break;
    case arith::CmpFPredicate::OGT: case arith::CmpFPredicate::UGT: os << ">"; break;
    case arith::CmpFPredicate::OGE: case arith::CmpFPredicate::UGE: os << ">="; break;
    default: os << "/* unsupported cmp */=="; break;
  }
  os << " " << getName(op.getRhs()) << ";\n";
}

void MSLEmitter::emitCmpI(arith::CmpIOp op) {
  std::string ty = "bool";
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getLhs()) << " ";
  switch (op.getPredicate()) {
    case arith::CmpIPredicate::eq:  os << "=="; break;
    case arith::CmpIPredicate::ne:  os << "!="; break;
    case arith::CmpIPredicate::slt: case arith::CmpIPredicate::ult: os << "<"; break;
    case arith::CmpIPredicate::sle: case arith::CmpIPredicate::ule: os << "<="; break;
    case arith::CmpIPredicate::sgt: case arith::CmpIPredicate::ugt: os << ">"; break;
    case arith::CmpIPredicate::sge: case arith::CmpIPredicate::uge: os << ">="; break;
  }
  os << " " << getName(op.getRhs()) << ";\n";
}

void MSLEmitter::emitVertexReturn(VertexReturnOp op) {
  if (op.getOperands().empty()) return;
  stream() << "    return " << getName(op.getOperands()[0]) << ";\n";
}

void MSLEmitter::emitFragmentReturn(FragmentReturnOp op) {
  if (op.getOperands().empty()) return;
  stream() << "    return " << getName(op.getOperands()[0]) << ";\n";
}

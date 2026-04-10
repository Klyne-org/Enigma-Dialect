//===- MSLEmitterTexture.cpp - Texture operation emission -----------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitTextureRead(TextureReadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getTexture()) << ".read(";
  bool first = true;
  for (auto coord : op.getCoords()) {
    if (!first) os << ", ";
    os << getName(coord);
    first = false;
  }
  os << ");\n";
}

void MSLEmitter::emitTextureWrite(TextureWriteOp op) {
  auto &os = stream();
  os << "    " << getName(op.getTexture()) << ".write("
     << getName(op.getValue()) << ", ";
  bool first = true;
  for (auto coord : op.getCoords()) {
    if (!first) os << ", ";
    os << getName(coord);
    first = false;
  }
  os << ");\n";
}

void MSLEmitter::emitTextureSample(TextureSampleOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    constexpr sampler _samp("
     << "filter::" << stringifyEnum(op.getFilter())
     << ", address::" << stringifyEnum(op.getAddress()) << ");\n";
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getTexture()) << ".sample(_samp, ";
  bool first = true;
  for (auto coord : op.getCoords()) {
    if (!first) os << ", ";
    os << getName(coord);
    first = false;
  }
  os << ");\n";
}

void MSLEmitter::emitTextureQuery(Operation *op, llvm::StringRef method) {
  auto &os = stream();
  os << "    uint " << getName(op->getResult(0)) << " = "
     << getName(op->getOperand(0)) << "." << method << "();\n";
}

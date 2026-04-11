//===- MSLEmitterTexture.cpp - Texture operation emission -----------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

/// Emit packed coordinate expression for texture ops.
/// MSL texture methods require packed vector coords (uint2, uint3) not
/// separate scalar arguments. For a single coord, emit it directly.
/// For multiple coords, pack them as uintN(x, y, ...) for read/write
/// or floatN(x, y, ...) for sample.
static void emitPackedCoords(MSLEmitter &e, llvm::raw_ostream &os,
                             mlir::Operation::operand_range coords,
                             llvm::StringRef elemType) {
  unsigned n = coords.size();
  if (n == 1) {
    os << e.getName(coords[0]);
    return;
  }
  os << elemType << n << "(";
  for (unsigned i = 0; i < n; ++i) {
    if (i > 0) os << ", ";
    os << e.getName(coords[i]);
  }
  os << ")";
}

void MSLEmitter::emitTextureRead(TextureReadOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getTexture()) << ".read(";
  emitPackedCoords(*this, os, op.getCoords(), "uint");
  os << ");\n";
}

void MSLEmitter::emitTextureWrite(TextureWriteOp op) {
  auto &os = stream();
  os << "    " << getName(op.getTexture()) << ".write("
     << getName(op.getValue()) << ", ";
  emitPackedCoords(*this, os, op.getCoords(), "uint");
  os << ");\n";
}

void MSLEmitter::emitTextureSample(TextureSampleOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  auto &os = stream();
  // Use unique sampler names to avoid redefinition when multiple
  // texture_sample ops appear in the same kernel.
  std::string sampName = "_samp" + std::to_string(nextVarId());
  os << "    constexpr sampler " << sampName << "("
     << "filter::" << stringifyEnum(op.getFilter())
     << ", address::" << stringifyEnum(op.getAddress()) << ");\n";
  os << "    " << ty << " " << getName(op.getResult()) << " = "
     << getName(op.getTexture()) << ".sample(" << sampName << ", ";
  emitPackedCoords(*this, os, op.getCoords(), "float");
  os << ");\n";
}

void MSLEmitter::emitTextureQuery(Operation *op, llvm::StringRef method) {
  auto &os = stream();
  os << "    uint " << getName(op->getResult(0)) << " = "
     << getName(op->getOperand(0)) << "." << method << "();\n";
}

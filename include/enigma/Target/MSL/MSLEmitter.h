//===- MSLEmitter.h - Enigma -> MSL emitter class decl ----------*- C++ -*-===//
//
// The MSLEmitter class: walks Enigma dialect IR and prints equivalent MSL.
// Method implementations are split across multiple .cpp files by category.
//
//===----------------------------------------------------------------------===//

#pragma once

#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinOps.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Support/raw_ostream.h"

namespace enigma {

class MSLEmitter {
  llvm::raw_ostream &os;
  llvm::DenseMap<mlir::Value, std::string> valueNames;
  int nextVar = 0;
  llvm::StringSet<> usedBuiltins;

public:
  explicit MSLEmitter(llvm::raw_ostream &os) : os(os) {}

  // === Name management ===
  llvm::StringRef getName(mlir::Value v);

  // === Type / enum string mapping ===
  llvm::StringRef getAddressSpaceString(unsigned memorySpace);
  std::string getTypeString(mlir::Type type);
  std::string getMemFlagsString(MemFlags flags);
  std::string getMemoryOrderString(MemoryOrder order);
  std::string getDimSuffix(Dimension dim);
  std::string getBuiltinParamName(llvm::StringRef opMnemonic);
  std::string getMathPrecisionPrefix(MathPrecision prec);

  // === Top-level emission ===
  void emitPreamble();
  void emitFunctionConstants(mlir::ModuleOp module);
  void emitKernel(KernelOp kernel);
  void emitVertex(VertexOp vertex);
  void emitFragment(FragmentOp fragment);

  // === Op dispatch ===
  void emitOp(mlir::Operation &op);

  // === Scanning ===
  void scanForBuiltins(mlir::Region &body);
  void emitBuiltinParam(llvm::StringRef builtin);

  // === Thread indexing (MSLEmitterThread.cpp) ===
  void emitThreadIndex(mlir::Operation *op, llvm::StringRef builtinName,
                       Dimension dim);
  void emitFlatThreadIndex(mlir::Operation *op, llvm::StringRef builtinName);

  // === Synchronization (MSLEmitterSync.cpp) ===
  void emitBarrier(llvm::StringRef funcName, MemFlags flags);
  void emitThreadgroupAlloc(ThreadgroupAllocOp op);

  // === SIMD ops (MSLEmitterSimd.cpp) ===
  void emitSimdUnary(mlir::Operation *op, llvm::StringRef funcName);
  void emitSimdBinary(mlir::Operation *op, llvm::StringRef funcName);

  // === Atomics (MSLEmitterAtomic.cpp) ===
  void emitAtomicLoad(AtomicLoadOp op);
  void emitAtomicStore(AtomicStoreOp op);
  void emitAtomicExchange(AtomicExchangeOp op);
  void emitAtomicCAS(AtomicCompareExchangeWeakOp op);
  void emitAtomicRMW(mlir::Operation *op, llvm::StringRef funcName,
                     MemoryOrder order);

  // === Math (MSLEmitterMath.cpp) ===
  void emitMathUnary(mlir::Operation *op, llvm::StringRef funcName,
                     MathPrecision prec);
  void emitMathBinary(mlir::Operation *op, llvm::StringRef funcName,
                      MathPrecision prec);
  void emitMathTernary(mlir::Operation *op, llvm::StringRef funcName,
                       MathPrecision prec);

  // === Integer intrinsics (MSLEmitterInt.cpp) ===
  void emitIntUnary(mlir::Operation *op, llvm::StringRef funcName);
  void emitIntBinary(mlir::Operation *op, llvm::StringRef funcName);
  void emitIntTernary(mlir::Operation *op, llvm::StringRef funcName);
  void emitExtractBits(ExtractBitsOp op);
  void emitInsertBits(InsertBitsOp op);

  // === Geometric (MSLEmitterGeom.cpp) ===
  void emitGeomBinaryScalar(mlir::Operation *op, llvm::StringRef funcName);
  void emitGeomUnaryScalar(mlir::Operation *op, llvm::StringRef funcName);
  void emitGeomVecBinary(mlir::Operation *op, llvm::StringRef funcName);
  void emitGeomVecUnary(mlir::Operation *op, llvm::StringRef funcName);
  void emitGeomVecTernary(mlir::Operation *op, llvm::StringRef funcName);
  void emitRefract(RefractOp op);
  void emitVecMake(VecMakeOp op);
  void emitVecExtract(VecExtractOp op);

  // === Texture (MSLEmitterTexture.cpp) ===
  void emitTextureRead(TextureReadOp op);
  void emitTextureWrite(TextureWriteOp op);
  void emitTextureSample(TextureSampleOp op);
  void emitTextureQuery(mlir::Operation *op, llvm::StringRef method);

  // === Casts (MSLEmitterCast.cpp) ===
  void emitMetalCast(MetalCastOp op);
  void emitAsType(AsTypeOp op);

  // === Upstream dialect ops (MSLEmitterUpstream.cpp) ===
  void emitLoad(mlir::memref::LoadOp op);
  void emitStore(mlir::memref::StoreOp op);
  void emitMemRefCast(mlir::memref::CastOp op);
  void emitArithBinOp(mlir::Operation *op, llvm::StringRef sym);
  void emitArithNeg(mlir::arith::NegFOp op);
  void emitConstant(mlir::arith::ConstantOp op);
  void emitIndexCast(mlir::arith::IndexCastOp op);
  void emitTypeCast(mlir::Operation *op);
  void emitCmpF(mlir::arith::CmpFOp op);
  void emitCmpI(mlir::arith::CmpIOp op);
  void emitVertexReturn(VertexReturnOp op);
  void emitFragmentReturn(FragmentReturnOp op);

  // === Relational (MSLEmitterRelational.cpp) ===
  void emitFloatPredicate(mlir::Operation *op, llvm::StringRef funcName);
  void emitSelect(SelectOp op);

  // === Quad group (MSLEmitterQuad.cpp) ===
  void emitQuadUnary(mlir::Operation *op, llvm::StringRef funcName);
  void emitQuadBinary(mlir::Operation *op, llvm::StringRef funcName);

  // === Control flow (MSLEmitterControlFlow.cpp) ===
  void emitFunctionConstant(FunctionConstantOp op);
  void emitScfFor(mlir::scf::ForOp op);
  void emitScfIf(mlir::scf::IfOp op);

  // === Pack/Unpack (MSLEmitterPack.cpp) ===
  void emitPackOp(mlir::Operation *op, llvm::StringRef funcName);
  void emitUnpackOp(mlir::Operation *op, llvm::StringRef funcName);

  // === Matrix (MSLEmitterMatrix.cpp) ===
  void emitMatMake(MatMakeOp op);
  void emitMatMul(MatMulOp op);
  void emitTranspose(TransposeOp op);
  void emitDeterminant(DeterminantOp op);
  void emitSimdgroupMatLoad(SimdgroupMatLoadOp op);
  void emitSimdgroupMatStore(SimdgroupMatStoreOp op);
  void emitSimdgroupMatMulAcc(SimdgroupMatMulAccOp op);
  void emitMakeFilledSimdgroupMat(MakeFilledSimdgroupMatOp op);

  // === Helpers for control flow emitter ===
  int nextVarId() { return nextVar++; }
  void assignName(mlir::Value v, const std::string &name) { valueNames[v] = name; }

  // === Stream access for method impls in other TUs ===
  llvm::raw_ostream &stream() { return os; }
};

} // namespace enigma

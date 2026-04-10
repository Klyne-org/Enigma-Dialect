//===- MSLEmitterCore.cpp - Core emitter: names, types, dispatch ----------===//

#include "enigma/Target/MSL/MSLEmitter.h"
#include "enigma/Target/MSL/TranslateToMSL.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/Tools/mlir-translate/Translation.h"

using namespace mlir;
using namespace enigma;

// ============================================================================
// Name management
// ============================================================================

llvm::StringRef MSLEmitter::getName(Value v) {
  auto it = valueNames.find(v);
  if (it != valueNames.end())
    return it->second;
  std::string name = "v" + std::to_string(nextVar++);
  valueNames[v] = name;
  return valueNames[v];
}

// ============================================================================
// Type / enum string mapping
// ============================================================================

llvm::StringRef MSLEmitter::getAddressSpaceString(unsigned memorySpace) {
  switch (memorySpace) {
  case 0: return "device";
  case 1: return "constant";
  case 2: return "threadgroup";
  case 3: return "thread";
  default: return "device";
  }
}

std::string MSLEmitter::getTypeString(Type type) {
  if (type.isF32())       return "float";
  if (type.isF16())       return "half";
  if (type.isBF16())      return "bfloat";
  if (type.isInteger(1))  return "bool";
  if (type.isInteger(8))  return "char";
  if (type.isInteger(16)) return "short";
  if (type.isInteger(32)) return "int";
  if (type.isInteger(64)) return "long";
  if (type.isIndex())     return "uint";
  if (auto vecTy = dyn_cast<VectorType>(type))
    return getTypeString(vecTy.getElementType()) +
           std::to_string(vecTy.getNumElements());
  return "float";
}

std::string MSLEmitter::getMemFlagsString(MemFlags flags) {
  switch (flags) {
  case MemFlags::mem_none:                   return "mem_flags::mem_none";
  case MemFlags::mem_device:                 return "mem_flags::mem_device";
  case MemFlags::mem_threadgroup:            return "mem_flags::mem_threadgroup";
  case MemFlags::mem_device_and_threadgroup: return "mem_flags::mem_device_and_threadgroup";
  case MemFlags::mem_texture:                return "mem_flags::mem_texture";
  }
  return "mem_flags::mem_threadgroup";
}

std::string MSLEmitter::getMemoryOrderString(MemoryOrder order) {
  // Metal only supports memory_order_relaxed for most atomics.
  // Acquire/release semantics are handled via barriers instead.
  (void)order;
  return "memory_order_relaxed";
}

std::string MSLEmitter::getDimSuffix(Dimension dim) {
  switch (dim) {
  case Dimension::x: return ".x";
  case Dimension::y: return ".y";
  case Dimension::z: return ".z";
  }
  return ".x";
}

std::string MSLEmitter::getBuiltinParamName(llvm::StringRef opMnemonic) {
  if (opMnemonic == "thread_position_in_grid")       return "_tpg";
  if (opMnemonic == "threadgroup_position_in_grid")   return "_tgpg";
  if (opMnemonic == "thread_position_in_threadgroup") return "_tpt";
  if (opMnemonic == "threads_per_threadgroup")        return "_tptg";
  if (opMnemonic == "thread_index_in_threadgroup")    return "_titg";
  if (opMnemonic == "threadgroups_per_grid")          return "_tgpg_count";
  if (opMnemonic == "threads_per_grid")               return "_tpg_count";
  if (opMnemonic == "grid_size")                      return "_gs";
  if (opMnemonic == "simdgroup_index_in_threadgroup") return "_sigt";
  if (opMnemonic == "thread_index_in_simdgroup")      return "_tisg";
  if (opMnemonic == "threads_per_simdgroup")          return "_tpsg";
  if (opMnemonic == "simdgroups_per_threadgroup")     return "_sgptg";
  if (opMnemonic == "vertex_id")                      return "_vid";
  if (opMnemonic == "instance_id")                    return "_iid";
  return "_unknown";
}

std::string MSLEmitter::getMathPrecisionPrefix(MathPrecision prec) {
  switch (prec) {
  case MathPrecision::fast:    return "fast::";
  case MathPrecision::precise: return "precise::";
  default:                     return "";
  }
}

// ============================================================================
// Builtin scanning & parameter emission
// ============================================================================

void MSLEmitter::scanForBuiltins(Region &body) {
  usedBuiltins.clear();
  body.walk([&](Operation *op) {
    if (isa<ThreadPositionInGridOp>(op))
      usedBuiltins.insert("thread_position_in_grid");
    else if (isa<ThreadgroupPositionInGridOp>(op))
      usedBuiltins.insert("threadgroup_position_in_grid");
    else if (isa<ThreadPositionInThreadgroupOp>(op))
      usedBuiltins.insert("thread_position_in_threadgroup");
    else if (isa<ThreadsPerThreadgroupOp>(op))
      usedBuiltins.insert("threads_per_threadgroup");
    else if (isa<ThreadIndexInThreadgroupOp>(op))
      usedBuiltins.insert("thread_index_in_threadgroup");
    else if (isa<ThreadgroupsPerGridOp>(op))
      usedBuiltins.insert("threadgroups_per_grid");
    else if (isa<ThreadsPerGridOp>(op))
      usedBuiltins.insert("threads_per_grid");
    else if (isa<GridSizeOp>(op))
      usedBuiltins.insert("grid_size");
    else if (isa<SimdgroupIndexInThreadgroupOp>(op))
      usedBuiltins.insert("simdgroup_index_in_threadgroup");
    else if (isa<ThreadIndexInSimdgroupOp>(op))
      usedBuiltins.insert("thread_index_in_simdgroup");
    else if (isa<ThreadsPerSimdgroupOp>(op))
      usedBuiltins.insert("threads_per_simdgroup");
    else if (isa<SimdgroupsPerThreadgroupOp>(op))
      usedBuiltins.insert("simdgroups_per_threadgroup");
    else if (isa<VertexIdOp>(op))
      usedBuiltins.insert("vertex_id");
    else if (isa<InstanceIdOp>(op))
      usedBuiltins.insert("instance_id");
  });
}

void MSLEmitter::emitBuiltinParam(llvm::StringRef builtin) {
  std::string paramName = getBuiltinParamName(builtin);
  bool isFlat = (builtin == "thread_index_in_threadgroup" ||
                 builtin == "simdgroup_index_in_threadgroup" ||
                 builtin == "thread_index_in_simdgroup" ||
                 builtin == "threads_per_simdgroup" ||
                 builtin == "simdgroups_per_threadgroup" ||
                 builtin == "vertex_id" ||
                 builtin == "instance_id");
  llvm::StringRef type = isFlat ? "uint" : "uint3";
  os << "    " << type << " " << paramName << " [[" << builtin << "]]";
}

// ============================================================================
// Preamble
// ============================================================================

void MSLEmitter::emitPreamble() {
  os << "#include <metal_stdlib>\n";
  os << "using namespace metal;\n\n";
}

// ============================================================================
// Kernel / Vertex / Fragment emission
// ============================================================================

static void emitFuncArgs(MSLEmitter &e, llvm::raw_ostream &os,
                         FunctionType funcType, Block &entryBlock,
                         bool isFragment, bool hasTrailingParams) {
  unsigned end = funcType.getNumInputs();
  for (unsigned i = 0; i < end; ++i) {
    Type argType = funcType.getInput(i);
    if (auto memref = dyn_cast<MemRefType>(argType)) {
      std::string elem = e.getTypeString(memref.getElementType());
      unsigned memSpace = 0;
      if (auto ms = memref.getMemorySpace())
        if (auto intAttr = dyn_cast<IntegerAttr>(ms))
          memSpace = intAttr.getInt();
      llvm::StringRef addrSpace = e.getAddressSpaceString(memSpace);
      os << "    " << addrSpace << " " << elem << "* "
         << e.getName(entryBlock.getArgument(i))
         << " [[buffer(" << i << ")]]";
    } else if (isFragment) {
      os << "    " << e.getTypeString(argType) << " "
         << e.getName(entryBlock.getArgument(i)) << " [[stage_in]]";
    } else {
      os << "    " << e.getTypeString(argType) << " "
         << e.getName(entryBlock.getArgument(i))
         << " [[buffer(" << i << ")]]";
    }
    if (hasTrailingParams || i + 1 < end)
      os << ",";
    os << "\n";
  }
}

void MSLEmitter::emitKernel(KernelOp kernel) {
  scanForBuiltins(kernel.getBody());
  os << "kernel void " << kernel.getSymName() << "(\n";
  auto funcType = kernel.getFunctionType();
  auto &entry = kernel.getBody().front();
  bool hasBuiltins = !usedBuiltins.empty();

  emitFuncArgs(*this, os, funcType, entry, false, hasBuiltins);

  unsigned idx = 0;
  for (auto &b : usedBuiltins) {
    emitBuiltinParam(b.getKey());
    if (idx + 1 < usedBuiltins.size()) os << ",";
    os << "\n";
    idx++;
  }

  os << ") {\n";
  for (Operation &op : entry) emitOp(op);
  os << "}\n\n";
}

void MSLEmitter::emitVertex(VertexOp vertex) {
  scanForBuiltins(vertex.getBody());
  auto funcType = vertex.getFunctionType();
  std::string retType = funcType.getNumResults() > 0
      ? getTypeString(funcType.getResult(0)) : "void";
  os << "vertex " << retType << " " << vertex.getSymName() << "(\n";
  auto &entry = vertex.getBody().front();
  bool hasBuiltins = !usedBuiltins.empty();

  emitFuncArgs(*this, os, funcType, entry, false, hasBuiltins);

  unsigned idx = 0;
  for (auto &b : usedBuiltins) {
    emitBuiltinParam(b.getKey());
    if (idx + 1 < usedBuiltins.size()) os << ",";
    os << "\n";
    idx++;
  }

  os << ") {\n";
  for (Operation &op : entry) emitOp(op);
  os << "}\n\n";
}

void MSLEmitter::emitFragment(FragmentOp fragment) {
  scanForBuiltins(fragment.getBody());
  auto funcType = fragment.getFunctionType();
  std::string retType = funcType.getNumResults() > 0
      ? getTypeString(funcType.getResult(0)) : "void";
  os << "fragment " << retType << " " << fragment.getSymName() << "(\n";
  auto &entry = fragment.getBody().front();

  emitFuncArgs(*this, os, funcType, entry, true, false);
  os << ") {\n";
  for (Operation &op : entry) emitOp(op);
  os << "}\n\n";
}

// ============================================================================
// Op dispatch
// ============================================================================

void MSLEmitter::emitOp(Operation &op) {
  // --- Terminators ---
  if (isa<ReturnOp>(op)) return;
  if (auto r = dyn_cast<VertexReturnOp>(op)) return emitVertexReturn(r);
  if (auto r = dyn_cast<FragmentReturnOp>(op)) return emitFragmentReturn(r);

  // --- Thread indexing ---
  if (auto o = dyn_cast<ThreadPositionInGridOp>(op))
    return emitThreadIndex(&op, "thread_position_in_grid", o.getDimension());
  if (auto o = dyn_cast<ThreadgroupPositionInGridOp>(op))
    return emitThreadIndex(&op, "threadgroup_position_in_grid", o.getDimension());
  if (auto o = dyn_cast<ThreadPositionInThreadgroupOp>(op))
    return emitThreadIndex(&op, "thread_position_in_threadgroup", o.getDimension());
  if (auto o = dyn_cast<ThreadsPerThreadgroupOp>(op))
    return emitThreadIndex(&op, "threads_per_threadgroup", o.getDimension());
  if (auto o = dyn_cast<ThreadIndexInThreadgroupOp>(op))
    return emitFlatThreadIndex(&op, "thread_index_in_threadgroup");
  if (auto o = dyn_cast<ThreadgroupsPerGridOp>(op))
    return emitThreadIndex(&op, "threadgroups_per_grid", o.getDimension());
  if (auto o = dyn_cast<ThreadsPerGridOp>(op))
    return emitThreadIndex(&op, "threads_per_grid", o.getDimension());
  if (auto o = dyn_cast<GridSizeOp>(op))
    return emitThreadIndex(&op, "grid_size", o.getDimension());
  if (auto o = dyn_cast<SimdgroupIndexInThreadgroupOp>(op))
    return emitFlatThreadIndex(&op, "simdgroup_index_in_threadgroup");
  if (auto o = dyn_cast<ThreadIndexInSimdgroupOp>(op))
    return emitFlatThreadIndex(&op, "thread_index_in_simdgroup");
  if (auto o = dyn_cast<ThreadsPerSimdgroupOp>(op))
    return emitFlatThreadIndex(&op, "threads_per_simdgroup");
  if (auto o = dyn_cast<SimdgroupsPerThreadgroupOp>(op))
    return emitFlatThreadIndex(&op, "simdgroups_per_threadgroup");
  if (isa<VertexIdOp>(op))
    return emitFlatThreadIndex(&op, "vertex_id");
  if (isa<InstanceIdOp>(op))
    return emitFlatThreadIndex(&op, "instance_id");

  // --- Synchronization ---
  if (auto o = dyn_cast<ThreadgroupBarrierOp>(op))
    return emitBarrier("threadgroup_barrier", o.getMemFlags());
  if (auto o = dyn_cast<SimdgroupBarrierOp>(op))
    return emitBarrier("simdgroup_barrier", o.getMemFlags());
  if (auto o = dyn_cast<ThreadgroupAllocOp>(op))
    return emitThreadgroupAlloc(o);

  // --- SIMD ---
  if (isa<SimdSumOp>(op))     return emitSimdUnary(&op, "simd_sum");
  if (isa<SimdProductOp>(op)) return emitSimdUnary(&op, "simd_product");
  if (isa<SimdMinOp>(op))     return emitSimdUnary(&op, "simd_min");
  if (isa<SimdMaxOp>(op))     return emitSimdUnary(&op, "simd_max");
  if (isa<SimdAndOp>(op))     return emitSimdUnary(&op, "simd_and");
  if (isa<SimdOrOp>(op))      return emitSimdUnary(&op, "simd_or");
  if (isa<SimdXorOp>(op))     return emitSimdUnary(&op, "simd_xor");
  if (isa<SimdPrefixExclusiveSumOp>(op))
    return emitSimdUnary(&op, "simd_prefix_exclusive_sum");
  if (isa<SimdPrefixInclusiveSumOp>(op))
    return emitSimdUnary(&op, "simd_prefix_inclusive_sum");
  if (isa<SimdPrefixExclusiveProductOp>(op))
    return emitSimdUnary(&op, "simd_prefix_exclusive_product");
  if (isa<SimdPrefixInclusiveProductOp>(op))
    return emitSimdUnary(&op, "simd_prefix_inclusive_product");
  if (isa<SimdShuffleOp>(op))     return emitSimdBinary(&op, "simd_shuffle");
  if (isa<SimdShuffleUpOp>(op))   return emitSimdBinary(&op, "simd_shuffle_up");
  if (isa<SimdShuffleDownOp>(op)) return emitSimdBinary(&op, "simd_shuffle_down");
  if (isa<SimdShuffleXorOp>(op))  return emitSimdBinary(&op, "simd_shuffle_xor");
  if (isa<SimdBroadcastOp>(op))   return emitSimdBinary(&op, "simd_broadcast");

  // --- Atomics ---
  if (auto o = dyn_cast<AtomicLoadOp>(op))    return emitAtomicLoad(o);
  if (auto o = dyn_cast<AtomicStoreOp>(op))   return emitAtomicStore(o);
  if (auto o = dyn_cast<AtomicExchangeOp>(op)) return emitAtomicExchange(o);
  if (auto o = dyn_cast<AtomicCompareExchangeWeakOp>(op)) return emitAtomicCAS(o);
  if (auto o = dyn_cast<AtomicFetchAddOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_add_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchSubOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_sub_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchMinOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_min_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchMaxOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_max_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchAndOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_and_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchOrOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_or_explicit", o.getMemoryOrder());
  if (auto o = dyn_cast<AtomicFetchXorOp>(op))
    return emitAtomicRMW(&op, "atomic_fetch_xor_explicit", o.getMemoryOrder());

  // --- Math unary ---
  if (auto o = dyn_cast<AbsOp>(op))      return emitMathUnary(&op, "abs", o.getPrecision());
  if (auto o = dyn_cast<CeilOp>(op))     return emitMathUnary(&op, "ceil", o.getPrecision());
  if (auto o = dyn_cast<FloorOp>(op))    return emitMathUnary(&op, "floor", o.getPrecision());
  if (auto o = dyn_cast<RoundOp>(op))    return emitMathUnary(&op, "rint", o.getPrecision());
  if (auto o = dyn_cast<TruncOp>(op))    return emitMathUnary(&op, "trunc", o.getPrecision());
  if (auto o = dyn_cast<SignOp>(op))     return emitMathUnary(&op, "sign", o.getPrecision());
  if (auto o = dyn_cast<SaturateOp>(op)) return emitMathUnary(&op, "saturate", o.getPrecision());
  if (auto o = dyn_cast<FractOp>(op))    return emitMathUnary(&op, "fract", o.getPrecision());
  if (auto o = dyn_cast<SqrtOp>(op))     return emitMathUnary(&op, "sqrt", o.getPrecision());
  if (auto o = dyn_cast<RsqrtOp>(op))    return emitMathUnary(&op, "rsqrt", o.getPrecision());
  if (auto o = dyn_cast<ExpOp>(op))      return emitMathUnary(&op, "exp", o.getPrecision());
  if (auto o = dyn_cast<Exp2Op>(op))     return emitMathUnary(&op, "exp2", o.getPrecision());
  if (auto o = dyn_cast<LogOp>(op))      return emitMathUnary(&op, "log", o.getPrecision());
  if (auto o = dyn_cast<Log2Op>(op))     return emitMathUnary(&op, "log2", o.getPrecision());
  if (auto o = dyn_cast<Log10Op>(op))    return emitMathUnary(&op, "log10", o.getPrecision());
  if (auto o = dyn_cast<SinOp>(op))      return emitMathUnary(&op, "sin", o.getPrecision());
  if (auto o = dyn_cast<CosOp>(op))      return emitMathUnary(&op, "cos", o.getPrecision());
  if (auto o = dyn_cast<TanOp>(op))      return emitMathUnary(&op, "tan", o.getPrecision());
  if (auto o = dyn_cast<AsinOp>(op))     return emitMathUnary(&op, "asin", o.getPrecision());
  if (auto o = dyn_cast<AcosOp>(op))     return emitMathUnary(&op, "acos", o.getPrecision());
  if (auto o = dyn_cast<AtanOp>(op))     return emitMathUnary(&op, "atan", o.getPrecision());
  if (auto o = dyn_cast<SinhOp>(op))     return emitMathUnary(&op, "sinh", o.getPrecision());
  if (auto o = dyn_cast<CoshOp>(op))     return emitMathUnary(&op, "cosh", o.getPrecision());
  if (auto o = dyn_cast<TanhOp>(op))     return emitMathUnary(&op, "tanh", o.getPrecision());

  // --- Math binary ---
  if (auto o = dyn_cast<FminOp>(op))     return emitMathBinary(&op, "fmin", o.getPrecision());
  if (auto o = dyn_cast<FmaxOp>(op))     return emitMathBinary(&op, "fmax", o.getPrecision());
  if (auto o = dyn_cast<PowOp>(op))      return emitMathBinary(&op, "pow", o.getPrecision());
  if (auto o = dyn_cast<FmodOp>(op))     return emitMathBinary(&op, "fmod", o.getPrecision());
  if (auto o = dyn_cast<Atan2Op>(op))    return emitMathBinary(&op, "atan2", o.getPrecision());
  if (auto o = dyn_cast<StepOp>(op))     return emitMathBinary(&op, "step", o.getPrecision());
  if (auto o = dyn_cast<CopysignOp>(op)) return emitMathBinary(&op, "copysign", o.getPrecision());

  // --- Math ternary ---
  if (auto o = dyn_cast<ClampOp>(op))      return emitMathTernary(&op, "clamp", o.getPrecision());
  if (auto o = dyn_cast<FmaOp>(op))        return emitMathTernary(&op, "fma", o.getPrecision());
  if (auto o = dyn_cast<MixOp>(op))        return emitMathTernary(&op, "mix", o.getPrecision());
  if (auto o = dyn_cast<SmoothstepOp>(op)) return emitMathTernary(&op, "smoothstep", o.getPrecision());

  // --- Integer intrinsics ---
  if (isa<PopcountOp>(op))    return emitIntUnary(&op, "popcount");
  if (isa<ClzOp>(op))         return emitIntUnary(&op, "clz");
  if (isa<CtzOp>(op))         return emitIntUnary(&op, "ctz");
  if (isa<ReverseBitsOp>(op)) return emitIntUnary(&op, "reverse_bits");
  if (isa<AbsDiffBinOp>(op))  return emitIntBinary(&op, "absdiff");
  if (isa<AddSatOp>(op))      return emitIntBinary(&op, "addsat");
  if (isa<SubSatOp>(op))      return emitIntBinary(&op, "subsat");
  if (isa<MulHiOp>(op))       return emitIntBinary(&op, "mulhi");
  if (isa<RotateOp>(op))      return emitIntBinary(&op, "rotate");
  if (auto o = dyn_cast<ExtractBitsOp>(op)) return emitExtractBits(o);
  if (auto o = dyn_cast<InsertBitsOp>(op))  return emitInsertBits(o);
  if (isa<MadSatOp>(op))      return emitIntTernary(&op, "madsat");

  // --- Geometric ---
  if (isa<DotOp>(op))         return emitGeomBinaryScalar(&op, "dot");
  if (isa<CrossOp>(op))       return emitGeomVecBinary(&op, "cross");
  if (isa<LengthOp>(op))      return emitGeomUnaryScalar(&op, "length");
  if (isa<NormalizeOp>(op))   return emitGeomVecUnary(&op, "normalize");
  if (isa<DistanceOp>(op))    return emitGeomBinaryScalar(&op, "distance");
  if (isa<ReflectOp>(op))     return emitGeomVecBinary(&op, "reflect");
  if (auto o = dyn_cast<RefractOp>(op)) return emitRefract(o);
  if (isa<FaceforwardOp>(op)) return emitGeomVecTernary(&op, "faceforward");

  // --- Texture ---
  if (auto o = dyn_cast<TextureReadOp>(op))     return emitTextureRead(o);
  if (auto o = dyn_cast<TextureWriteOp>(op))    return emitTextureWrite(o);
  if (auto o = dyn_cast<TextureSampleOp>(op))   return emitTextureSample(o);
  if (isa<TextureGetWidthOp>(op))  return emitTextureQuery(&op, "get_width");
  if (isa<TextureGetHeightOp>(op)) return emitTextureQuery(&op, "get_height");

  // --- Casts ---
  if (auto o = dyn_cast<MetalCastOp>(op)) return emitMetalCast(o);
  if (auto o = dyn_cast<AsTypeOp>(op))    return emitAsType(o);

  // --- Upstream arith/memref ---
  if (auto o = dyn_cast<memref::LoadOp>(op))  return emitLoad(o);
  if (auto o = dyn_cast<memref::StoreOp>(op)) return emitStore(o);

  if (isa<arith::AddFOp>(op))  return emitArithBinOp(&op, "+");
  if (isa<arith::SubFOp>(op))  return emitArithBinOp(&op, "-");
  if (isa<arith::MulFOp>(op))  return emitArithBinOp(&op, "*");
  if (isa<arith::DivFOp>(op))  return emitArithBinOp(&op, "/");
  if (isa<arith::AddIOp>(op))  return emitArithBinOp(&op, "+");
  if (isa<arith::SubIOp>(op))  return emitArithBinOp(&op, "-");
  if (isa<arith::MulIOp>(op))  return emitArithBinOp(&op, "*");
  if (isa<arith::DivSIOp>(op)) return emitArithBinOp(&op, "/");
  if (isa<arith::RemSIOp>(op)) return emitArithBinOp(&op, "%");
  if (isa<arith::AndIOp>(op))  return emitArithBinOp(&op, "&");
  if (isa<arith::OrIOp>(op))   return emitArithBinOp(&op, "|");
  if (isa<arith::XOrIOp>(op))  return emitArithBinOp(&op, "^");
  if (isa<arith::ShLIOp>(op))  return emitArithBinOp(&op, "<<");
  if (isa<arith::ShRSIOp>(op)) return emitArithBinOp(&op, ">>");
  if (isa<arith::ShRUIOp>(op)) return emitArithBinOp(&op, ">>");
  if (auto o = dyn_cast<arith::NegFOp>(op))      return emitArithNeg(o);
  if (auto o = dyn_cast<arith::ConstantOp>(op))   return emitConstant(o);
  if (auto o = dyn_cast<arith::IndexCastOp>(op))  return emitIndexCast(o);
  if (isa<arith::SIToFPOp>(op))  return emitTypeCast(&op);
  if (isa<arith::FPToSIOp>(op))  return emitTypeCast(&op);
  if (isa<arith::UIToFPOp>(op))  return emitTypeCast(&op);
  if (isa<arith::FPToUIOp>(op))  return emitTypeCast(&op);
  if (isa<arith::ExtFOp>(op))    return emitTypeCast(&op);
  if (isa<arith::TruncFOp>(op))  return emitTypeCast(&op);
  if (isa<arith::ExtSIOp>(op))   return emitTypeCast(&op);
  if (isa<arith::ExtUIOp>(op))   return emitTypeCast(&op);
  if (isa<arith::TruncIOp>(op))  return emitTypeCast(&op);
  if (auto o = dyn_cast<arith::CmpFOp>(op)) return emitCmpF(o);
  if (auto o = dyn_cast<arith::CmpIOp>(op)) return emitCmpI(o);

  // --- Relational / Select ---
  if (isa<IsNanOp>(op))    return emitFloatPredicate(&op, "isnan");
  if (isa<IsInfOp>(op))    return emitFloatPredicate(&op, "isinf");
  if (isa<IsFiniteOp>(op)) return emitFloatPredicate(&op, "isfinite");
  if (isa<SignbitOp>(op))   return emitFloatPredicate(&op, "signbit");
  if (isa<IsNormalOp>(op))  return emitFloatPredicate(&op, "isnormal");
  if (auto o = dyn_cast<SelectOp>(op)) return emitSelect(o);
  if (isa<IMinOp>(op))  return emitIntBinary(&op, "min");
  if (isa<IMaxOp>(op))  return emitIntBinary(&op, "max");
  if (isa<IClampOp>(op)) return emitIntTernary(&op, "clamp");

  // --- Quad group ---
  if (isa<QuadSumOp>(op))     return emitQuadUnary(&op, "quad_sum");
  if (isa<QuadProductOp>(op)) return emitQuadUnary(&op, "quad_product");
  if (isa<QuadMinOp>(op))     return emitQuadUnary(&op, "quad_min");
  if (isa<QuadMaxOp>(op))     return emitQuadUnary(&op, "quad_max");
  if (isa<QuadAndOp>(op))     return emitQuadUnary(&op, "quad_and");
  if (isa<QuadOrOp>(op))      return emitQuadUnary(&op, "quad_or");
  if (isa<QuadXorOp>(op))     return emitQuadUnary(&op, "quad_xor");
  if (isa<QuadShuffleOp>(op))     return emitQuadBinary(&op, "quad_shuffle");
  if (isa<QuadBroadcastOp>(op))   return emitQuadBinary(&op, "quad_broadcast");
  if (isa<QuadShuffleDownOp>(op)) return emitQuadBinary(&op, "quad_shuffle_down");
  if (isa<QuadShuffleUpOp>(op))   return emitQuadBinary(&op, "quad_shuffle_up");
  if (isa<QuadShuffleXorOp>(op))  return emitQuadBinary(&op, "quad_shuffle_xor");
  if (isa<QuadPrefixExclusiveSumOp>(op))
    return emitQuadUnary(&op, "quad_prefix_exclusive_sum");
  if (isa<QuadPrefixInclusiveSumOp>(op))
    return emitQuadUnary(&op, "quad_prefix_inclusive_sum");

  // --- Function constants ---
  if (auto o = dyn_cast<FunctionConstantOp>(op)) return emitFunctionConstant(o);

  // --- Control flow (scf) ---
  if (auto o = dyn_cast<scf::ForOp>(op)) return emitScfFor(o);
  if (auto o = dyn_cast<scf::IfOp>(op))  return emitScfIf(o);
  if (isa<scf::YieldOp>(op)) return; // scf.yield is a no-op in MSL

  // --- Pack/Unpack ---
  if (isa<PackSnorm4x8Op>(op))     return emitPackOp(&op, "pack_float_to_snorm4x8");
  if (isa<PackUnorm4x8Op>(op))     return emitPackOp(&op, "pack_float_to_unorm4x8");
  if (isa<PackSnorm2x16Op>(op))    return emitPackOp(&op, "pack_float_to_snorm2x16");
  if (isa<PackUnorm2x16Op>(op))    return emitPackOp(&op, "pack_float_to_unorm2x16");
  if (isa<PackSrgbUnorm4x8Op>(op)) return emitPackOp(&op, "pack_float_to_srgb_unorm4x8");
  if (isa<PackUnorm10a2Op>(op))    return emitPackOp(&op, "pack_float_to_unorm10a2");
  if (isa<UnpackSnorm4x8ToFloatOp>(op))  return emitUnpackOp(&op, "unpack_snorm4x8_to_float");
  if (isa<UnpackUnorm4x8ToFloatOp>(op))  return emitUnpackOp(&op, "unpack_unorm4x8_to_float");
  if (isa<UnpackSnorm2x16ToFloatOp>(op)) return emitUnpackOp(&op, "unpack_snorm2x16_to_float");
  if (isa<UnpackUnorm2x16ToFloatOp>(op)) return emitUnpackOp(&op, "unpack_unorm2x16_to_float");
  if (isa<UnpackSrgbUnorm4x8ToFloatOp>(op)) return emitUnpackOp(&op, "unpack_unorm4x8_srgb_to_float");
  if (isa<UnpackUnorm10a2ToFloatOp>(op)) return emitUnpackOp(&op, "unpack_unorm10a2_to_float");

  // --- Matrix ---
  if (auto o = dyn_cast<MatMulOp>(op))       return emitMatMul(o);
  if (auto o = dyn_cast<TransposeOp>(op))    return emitTranspose(o);
  if (auto o = dyn_cast<DeterminantOp>(op))  return emitDeterminant(o);
  if (auto o = dyn_cast<SimdgroupMatLoadOp>(op))    return emitSimdgroupMatLoad(o);
  if (auto o = dyn_cast<SimdgroupMatStoreOp>(op))   return emitSimdgroupMatStore(o);
  if (auto o = dyn_cast<SimdgroupMatMulAccOp>(op))  return emitSimdgroupMatMulAcc(o);
  if (auto o = dyn_cast<MakeFilledSimdgroupMatOp>(op)) return emitMakeFilledSimdgroupMat(o);

  os << "    // UNHANDLED: " << op.getName().getStringRef() << "\n";
}

// ============================================================================
// Public API + registration
// ============================================================================

LogicalResult enigma::translateToMSL(ModuleOp module, llvm::raw_ostream &os) {
  MSLEmitter emitter(os);
  emitter.emitPreamble();
  module.walk([&](KernelOp k) { emitter.emitKernel(k); });
  module.walk([&](VertexOp v) { emitter.emitVertex(v); });
  module.walk([&](FragmentOp f) { emitter.emitFragment(f); });
  return success();
}

void enigma::registerToMSLTranslation() {
  static mlir::TranslateFromMLIRRegistration reg(
      "enigma-to-msl",
      "Translate Enigma dialect MLIR to Metal Shading Language",
      [](Operation *op, llvm::raw_ostream &os) -> LogicalResult {
        auto module = llvm::dyn_cast<ModuleOp>(op);
        if (!module) {
          op->emitError("enigma-to-msl expects a top-level 'builtin.module'");
          return failure();
        }
        return enigma::translateToMSL(module, os);
      },
      [](mlir::DialectRegistry &registry) {
        registry.insert<enigma::EnigmaDialect>();
        registry.insert<arith::ArithDialect>();
        registry.insert<memref::MemRefDialect>();
        registry.insert<func::FuncDialect>();
        registry.insert<scf::SCFDialect>();
      });
  (void)reg;
}

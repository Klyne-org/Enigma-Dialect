//===- MSLEmitter.cpp - Enigma -> MSL text emitter ------------------------===//
//
// WHAT THIS FILE IS
//   The visitor that walks an `enigma.kernel` op and prints equivalent
//   Metal Shading Language source to a stream. This is the single most
//   important file in the project: it is how Enigma IR actually becomes a
//   runnable GPU kernel.
//
// ARCHITECTURE NOTE — this is a KNOWN SHORTCUT
//   The emitter below is a big `if (auto x = dyn_cast<...>(op))` chain.
//   That works for a handful of ops but does NOT scale. The planned
//   production design is an `MSLEmittable` OpInterface declared in the
//   .td files, so each op implements `void emitMSL(MSLEmitter &)` on its
//   own class and the walker becomes a 5-line loop. Rewriting this once
//   the op count passes ~15 is a high-leverage move.
//
//   For now we stay with the dyn_cast chain to match the shape of the
//   old demo emitter, because:
//     1. It's familiar — you already have a working mental model of it.
//     2. It keeps the base small, so you can read end-to-end in one sitting.
//     3. Switching to OpInterface later is mechanical and low-risk once
//        the rest of the pipeline is green.
//
//   See the NEXT STEPS comment at the bottom of this file for the refactor
//   recipe when you're ready.
//
// HOW TO ADD SUPPORT FOR A NEW OP
//   1. Add an `else if (auto foo = dyn_cast<FooOp>(op)) emitFoo(foo);` in
//      emitOp() below.
//   2. Implement `emitFoo(FooOp op)` as a new private method.
//   3. Declare any new MSL features it needs (builtins, headers) in
//      emitPreamble or in the kernel signature builder.
//   4. Add a lit test in test/Target/MSL/.
//
// HOW THE THREAD-ID PLUMBING WORKS (IMPORTANT)
//   MSL doesn't let you "call" thread_position_in_grid as a function —
//   it must be declared as a kernel parameter with a `[[...]]` attribute.
//   So when we see `enigma.thread_position_in_grid x` in the IR, we:
//     - Remember to inject `uint3 _tpg [[thread_position_in_grid]]` into
//       the emitted kernel signature.
//     - Rewrite `%id = enigma.thread_position_in_grid x` to
//       `uint v3 = _tpg.x;` in the body.
//
//   The base implementation below only handles the 1D case (a single `uint
//   _tid`). To support full 3D, upgrade `_tid` to `uint3 _tpg` and switch
//   on the Dimension attribute. Listed as a NEXT STEP.
//
//===----------------------------------------------------------------------===//

#include "enigma/Target/MSL/TranslateToMSL.h"
#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Tools/mlir-translate/Translation.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/Support/raw_ostream.h"

using namespace mlir;
using namespace enigma;

namespace {

//===----------------------------------------------------------------------===//
// MSLEmitter — stateful walker that accumulates MSL source into a stream.
//===----------------------------------------------------------------------===//
//
// Not a public class: lives in an anonymous namespace because nothing
// outside this file should depend on its internals. The public entry
// points (translateToMSL, registerToMSLTranslation) at the bottom of the
// file are what the rest of the project calls.
class MSLEmitter {
  llvm::raw_ostream &os;

  /// Maps an MLIR SSA value (e.g. the result of an arith.addf) to the C
  /// identifier we chose for it in the emitted MSL ("v0", "v1", ...).
  /// Using small numeric names keeps the output diffable in lit tests.
  llvm::DenseMap<Value, std::string> valueNames;
  int nextVar = 0;

public:
  explicit MSLEmitter(llvm::raw_ostream &os) : os(os) {}

  //---------------------------------------------------------------------------
  // Name assignment
  //---------------------------------------------------------------------------
  // Give every SSA value a stable MSL identifier. First visit wins — later
  // lookups of the same value return the already-assigned name.
  llvm::StringRef getName(Value v) {
    auto it = valueNames.find(v);
    if (it != valueNames.end())
      return it->second;
    std::string name = "v" + std::to_string(nextVar++);
    valueNames[v] = name;
    return valueNames[v];
  }

  //---------------------------------------------------------------------------
  // Type mapping — MLIR types -> MSL type spellings
  //---------------------------------------------------------------------------
  // This handles just enough types for vector_add. Extend as you add
  // features: texture types, address-spaced memrefs, vector types, etc.
  llvm::StringRef getTypeString(Type type) {
    if (type.isF32())        return "float";
    if (type.isF16())        return "half";
    if (type.isInteger(32))  return "int";
    if (type.isInteger(16))  return "short";
    if (type.isInteger(8))   return "char";
    if (type.isIndex())      return "uint";
    // Fallback: pretend it's a float so the emitter keeps going and the
    // resulting MSL will fail to compile under xcrun metal, surfacing the
    // gap as a lit-test failure rather than a silent miscompile.
    return "float";
  }

  //---------------------------------------------------------------------------
  // Preamble — every MSL file needs these two lines.
  //---------------------------------------------------------------------------
  void emitPreamble() {
    os << "#include <metal_stdlib>\n";
    os << "using namespace metal;\n\n";
  }

  //---------------------------------------------------------------------------
  // Kernel — the entry point
  //---------------------------------------------------------------------------
  // Emits:
  //   kernel void <name>(
  //       device <elem>* v0 [[buffer(0)]],
  //       device <elem>* v1 [[buffer(1)]],
  //       ...
  //       uint _tid [[thread_position_in_grid]]
  //   ) {
  //       ... body ...
  //   }
  //
  // The `_tid` parameter is always emitted — the base demo assumes every
  // kernel needs thread-id access. A production emitter scans the body
  // first and only injects the builtins that are actually used.
  void emitKernel(KernelOp kernel) {
    os << "kernel void " << kernel.getSymName() << "(\n";

    auto funcType = kernel.getFunctionType();
    auto &entryBlock = kernel.getBody().front();

    for (unsigned i = 0, e = funcType.getNumInputs(); i < e; ++i) {
      Type argType = funcType.getInput(i);
      // Currently all kernel arguments are memrefs, emitted as
      // `device <elem>*` pointers with a buffer binding. When address
      // spaces land, this switch widens: constant/threadgroup/etc.
      if (auto memref = dyn_cast<MemRefType>(argType)) {
        llvm::StringRef elem = getTypeString(memref.getElementType());
        os << "    device " << elem << "* "
           << getName(entryBlock.getArgument(i))
           << " [[buffer(" << i << ")]]";
      } else {
        // Not yet supported — leave a visible marker that will fail the
        // MSL compiler so the gap becomes obvious.
        os << "    /* UNSUPPORTED ARG TYPE */";
      }
      os << ",\n";
    }

    os << "    uint _tid [[thread_position_in_grid]]\n";
    os << ") {\n";

    // Walk top-level ops in the kernel body. We do NOT recurse into
    // nested regions — that's fine for a flat vector-add but will need
    // extending when we add `scf.for` or structured control flow.
    for (Operation &op : entryBlock) {
      emitOp(op);
    }

    os << "}\n\n";
  }

  //---------------------------------------------------------------------------
  // Op dispatch — the dyn_cast chain we'll replace with an OpInterface
  //---------------------------------------------------------------------------
  void emitOp(Operation &op) {
    // Enigma dialect ops
    if (auto tid = dyn_cast<ThreadPositionInGridOp>(op))
      return emitThreadPositionInGrid(tid);
    if (auto barrier = dyn_cast<ThreadgroupBarrierOp>(op))
      return emitThreadgroupBarrier(barrier);
    if (isa<ReturnOp>(op))
      return; // void return — MSL falls off the end of the function

    // Upstream dialect ops we reuse. A production pipeline might do a
    // conversion pass first to lower these to enigma ops, but at this
    // stage reusing them directly keeps the emitter simple.
    if (auto load = dyn_cast<memref::LoadOp>(op))
      return emitLoad(load);
    if (auto store = dyn_cast<memref::StoreOp>(op))
      return emitStore(store);

    if (auto addf = dyn_cast<arith::AddFOp>(op))
      return emitBinOp(addf, "+");
    if (auto subf = dyn_cast<arith::SubFOp>(op))
      return emitBinOp(subf, "-");
    if (auto mulf = dyn_cast<arith::MulFOp>(op))
      return emitBinOp(mulf, "*");
    if (auto addi = dyn_cast<arith::AddIOp>(op))
      return emitBinOp(addi, "+");
    if (auto muli = dyn_cast<arith::MulIOp>(op))
      return emitBinOp(muli, "*");

    if (auto cst = dyn_cast<arith::ConstantOp>(op))
      return emitConstant(cst);

    // Unhandled — emit a comment so the output is still parseable and the
    // gap is obvious when the lit test fails.
    os << "    // UNHANDLED: " << op.getName().getStringRef() << "\n";
  }

  //---------------------------------------------------------------------------
  // Per-op emission methods
  //---------------------------------------------------------------------------
  //
  // Each of these corresponds to a one-line MSL translation. When refactored
  // to the OpInterface design, these become methods on the op classes
  // themselves, living next to the op definitions.

  void emitThreadPositionInGrid(ThreadPositionInGridOp op) {
    // TODO(base): only the 1D case is handled here. For 2D/3D, emit
    // `uint3 _tpg [[thread_position_in_grid]]` as the kernel param and
    // reference `_tpg.x` / `_tpg.y` / `_tpg.z` based on op.getDimension().
    os << "    uint " << getName(op.getResult()) << " = _tid;\n";
  }

  void emitThreadgroupBarrier(ThreadgroupBarrierOp op) {
    // The mem_flags attribute is currently ignored (we always emit
    // mem_threadgroup). When mem_flags becomes a proper EnumAttr, switch
    // on it here and emit the right `mem_flags::...` expression.
    (void)op;
    os << "    threadgroup_barrier(mem_flags::mem_threadgroup);\n";
  }

  void emitLoad(memref::LoadOp op) {
    llvm::StringRef ty = getTypeString(op.getResult().getType());
    os << "    " << ty << " " << getName(op.getResult()) << " = "
       << getName(op.getMemRef()) << "["
       << getName(op.getIndices()[0]) << "];\n";
  }

  void emitStore(memref::StoreOp op) {
    os << "    " << getName(op.getMemRef()) << "["
       << getName(op.getIndices()[0]) << "] = "
       << getName(op.getValue()) << ";\n";
  }

  /// Emits `<type> <name> = <lhs> <sym> <rhs>;` for any two-operand op.
  template <typename OpTy>
  void emitBinOp(OpTy op, llvm::StringRef sym) {
    llvm::StringRef ty = getTypeString(op.getResult().getType());
    os << "    " << ty << " " << getName(op.getResult()) << " = "
       << getName(op->getOperand(0)) << " " << sym << " "
       << getName(op->getOperand(1)) << ";\n";
  }

  void emitConstant(arith::ConstantOp op) {
    llvm::StringRef ty = getTypeString(op.getResult().getType());
    os << "    " << ty << " " << getName(op.getResult()) << " = ";
    if (auto intAttr = dyn_cast<IntegerAttr>(op.getValue()))
      os << intAttr.getInt();
    else if (auto floatAttr = dyn_cast<FloatAttr>(op.getValue()))
      os << floatAttr.getValueAsDouble();
    else
      os << "/*unsupported const*/0";
    os << ";\n";
  }
};

} // end anonymous namespace

//===----------------------------------------------------------------------===//
// Public entry points — declared in include/enigma/Target/MSL/TranslateToMSL.h
//===----------------------------------------------------------------------===//

LogicalResult enigma::translateToMSL(ModuleOp module, llvm::raw_ostream &os) {
  MSLEmitter emitter(os);
  emitter.emitPreamble();

  // `walk` visits every op in the module recursively. We only care about
  // top-level kernels here; once nested regions exist (e.g. enigma.kernel
  // inside a module inside a module), that's still fine because walk
  // descends automatically.
  module.walk([&](KernelOp kernel) { emitter.emitKernel(kernel); });

  return success();
}

void enigma::registerToMSLTranslation() {
  // TranslateFromMLIRRegistration self-registers with a global registry
  // on construction. Keeping it `static` means the registration happens
  // once per process, the first time this function runs.
  static mlir::TranslateFromMLIRRegistration reg(
      /*name=*/"enigma-to-msl",
      /*description=*/"Translate Enigma dialect MLIR to Metal Shading Language",
      /*function=*/
      [](mlir::Operation *op, llvm::raw_ostream &os) -> LogicalResult {
        auto module = llvm::dyn_cast<ModuleOp>(op);
        if (!module) {
          op->emitError("enigma-to-msl expects a top-level 'builtin.module'");
          return failure();
        }
        return enigma::translateToMSL(module, os);
      },
      /*dialectRegistration=*/
      [](mlir::DialectRegistry &registry) {
        // Any dialect that can appear in the input IR must be listed here,
        // otherwise the parser will fail before translation runs. These
        // are the four we need to represent vector_add.
        registry.insert<enigma::EnigmaDialect>();
        registry.insert<arith::ArithDialect>();
        registry.insert<memref::MemRefDialect>();
        registry.insert<func::FuncDialect>();
      });
  (void)reg; // silence unused-variable warnings in release builds
}

//===----------------------------------------------------------------------===//
// NEXT STEPS — evolving this file
//===----------------------------------------------------------------------===//
//
//  1. Refactor to an OpInterface.
//     Declare `MSLEmittable` in EnigmaOps.td. Add it as a trait on every
//     op. Move each `emitXxx` method onto the corresponding op class.
//     The dispatch function becomes:
//
//         if (auto e = dyn_cast<MSLEmittable>(&op)) {
//           e.emitMSL(*this);
//           continue;
//         }
//
//  2. Scan-then-emit for kernel signatures.
//     Currently we always inject `uint _tid [[thread_position_in_grid]]`.
//     Instead, do a pre-walk over the kernel body to find all
//     Enigma_ThreadIndexOps, collect the set of builtins they use, and
//     emit exactly those parameters.
//
//  3. Full 3D support.
//     Upgrade the injected parameter to `uint3` and reference `.x/.y/.z`
//     based on the op's Dimension attribute.
//
//  4. Address-space aware pointer emission.
//     Read the memref's memory-space attribute and emit `device /
//     constant / threadgroup / thread` accordingly.
//
//  5. Extract emitter state into a header.
//     Once the OpInterface refactor is done, move the MSLEmitter class
//     declaration into an include/enigma/Target/MSL/MSLEmitter.h header,
//     so op emission methods in other translation units can use it.
//
//===----------------------------------------------------------------------===//

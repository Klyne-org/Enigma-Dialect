#include "MetalDialect/MetalDialect.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Tools/mlir-translate/Translation.h"
#include "llvm/Support/raw_ostream.h"

using namespace mlir;

namespace {

class MSLEmitter {
  raw_ostream &os;
  DenseMap<Value, std::string> valueNames;
  int nextVar = 0;

public:
  MSLEmitter(raw_ostream &os) : os(os) {}

  StringRef getName(Value v) {
    auto it = valueNames.find(v);
    if (it != valueNames.end())
      return it->second;
    std::string name = "v" + std::to_string(nextVar++);
    valueNames[v] = name;
    return valueNames[v];
  }

  void emitPreamble() {
    os << "#include <metal_stdlib>\n";
    os << "using namespace metal;\n\n";
  }

  StringRef getTypeString(Type type) {
    if (type.isF32()) return "float";
    if (type.isF16()) return "half";
    if (type.isInteger(32)) return "int";
    if (type.isInteger(16)) return "short";
    if (type.isInteger(8)) return "char";
    if (type.isIndex()) return "uint";
    return "float";
  }

  void emitKernel(metal::KernelOp kernel) {
    os << "kernel void " << kernel.getSymName() << "(\n";

    auto funcType = kernel.getFunctionType();
    for (unsigned i = 0; i < funcType.getNumInputs(); ++i) {
      auto argType = funcType.getInput(i);
      if (auto memrefType = dyn_cast<MemRefType>(argType)) {
        auto elemType = getTypeString(memrefType.getElementType());
        os << "    device " << elemType << "* "
           << getName(kernel.getBody().front().getArgument(i))
           << " [[buffer(" << i << ")]]";
      }
      if (i < funcType.getNumInputs() - 1)
        os << ",\n";
      else
        os << ",\n";
    }

    os << "    uint _tid [[thread_position_in_grid]]\n";
    os << ") {\n";

    for (auto &op : kernel.getBody().front()) {
      emitOp(op);
    }

    os << "}\n\n";
  }

  void emitOp(Operation &op) {
    if (auto threadId = dyn_cast<metal::ThreadPositionInGridOp>(op))
      emitThreadId(threadId);
    else if (auto load = dyn_cast<memref::LoadOp>(op))
      emitLoad(load);
    else if (auto store = dyn_cast<memref::StoreOp>(op))
      emitStore(store);
    else if (auto addf = dyn_cast<arith::AddFOp>(op))
      emitBinOp(addf, "+");
    else if (auto mulf = dyn_cast<arith::MulFOp>(op))
      emitBinOp(mulf, "*");
    else if (auto subf = dyn_cast<arith::SubFOp>(op))
      emitBinOp(subf, "-");
    else if (auto addi = dyn_cast<arith::AddIOp>(op))
      emitBinOp(addi, "+");
    else if (auto muli = dyn_cast<arith::MulIOp>(op))
      emitBinOp(muli, "*");
    else if (auto barrier = dyn_cast<metal::ThreadgroupBarrierOp>(op))
      emitBarrier(barrier);
    else if (auto constant = dyn_cast<arith::ConstantOp>(op))
      emitConstant(constant);
    else if (isa<metal::ReturnOp>(op))
      ; // void return, nothing to emit
  }

  void emitThreadId(metal::ThreadPositionInGridOp op) {
    os << "    uint " << getName(op.getResult()) << " = _tid;\n";
  }

  void emitLoad(memref::LoadOp op) {
    auto resultType = getTypeString(op.getResult().getType());
    os << "    " << resultType << " " << getName(op.getResult())
       << " = " << getName(op.getMemRef())
       << "[" << getName(op.getIndices()[0]) << "];\n";
  }

  void emitStore(memref::StoreOp op) {
    os << "    " << getName(op.getMemRef())
       << "[" << getName(op.getIndices()[0]) << "] = "
       << getName(op.getValue()) << ";\n";
  }

  template <typename OpTy>
  void emitBinOp(OpTy op, StringRef symbol) {
    auto resultType = getTypeString(op.getResult().getType());
    os << "    " << resultType << " " << getName(op.getResult())
       << " = " << getName(op->getOperand(0))
       << " " << symbol << " "
       << getName(op->getOperand(1)) << ";\n";
  }

  void emitConstant(arith::ConstantOp op) {
    auto resultType = getTypeString(op.getResult().getType());
    os << "    " << resultType << " " << getName(op.getResult()) << " = ";
    if (auto intAttr = dyn_cast<IntegerAttr>(op.getValue()))
      os << intAttr.getInt();
    else if (auto floatAttr = dyn_cast<FloatAttr>(op.getValue()))
      os << floatAttr.getValueAsDouble();
    os << ";\n";
  }

  void emitBarrier(metal::ThreadgroupBarrierOp op) {
    os << "    threadgroup_barrier(mem_flags::mem_threadgroup);\n";
  }
};

} // namespace

// Registration function called from metal-translate main
void registerToMSLTranslation() {
  TranslateFromMLIRRegistration reg(
      "mlir-to-msl", "Translate Metal MLIR to Metal Shading Language",
      [](ModuleOp module, raw_ostream &os) {
        MSLEmitter emitter(os);
        emitter.emitPreamble();
        module.walk([&](metal::KernelOp kernel) {
          emitter.emitKernel(kernel);
        });
        return success();
      },
      [](DialectRegistry &registry) {
        registry.insert<metal::MetalDialect>();
        registry.insert<arith::ArithDialect>();
        registry.insert<memref::MemRefDialect>();
      });
}

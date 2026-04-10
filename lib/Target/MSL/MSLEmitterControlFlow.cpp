//===- MSLEmitterControlFlow.cpp - scf.for/if + function_constant --------===//

#include "enigma/Target/MSL/MSLEmitter.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
using namespace mlir;
using namespace enigma;

void MSLEmitter::emitFunctionConstant(FunctionConstantOp op) {
  std::string ty = getTypeString(op.getResult().getType());
  stream() << "    constant " << ty << " " << getName(op.getResult())
           << " [[function_constant(" << op.getIndex() << ")]];\n";
}

void MSLEmitter::emitScfFor(mlir::scf::ForOp op) {
  auto &os = stream();

  // Handle iter_args: declare loop-carried vars before the loop, initialized
  // to init values. Map block args to the same names.
  auto iterArgs = op.getInitArgs();
  auto regionIterArgs = op.getRegionIterArgs();
  std::vector<std::string> iterVarNames;
  for (unsigned i = 0; i < iterArgs.size(); ++i) {
    std::string vn = "v" + std::to_string(nextVarId());
    iterVarNames.push_back(vn);
    std::string ty = getTypeString(iterArgs[i].getType());
    os << "    " << ty << " " << vn << " = " << getName(iterArgs[i]) << ";\n";
    assignName(regionIterArgs[i], vn);
  }

  // Map loop results to the same variable names (after loop, vars hold final)
  for (unsigned i = 0; i < op.getNumResults(); ++i)
    assignName(op.getResult(i), iterVarNames[i]);

  std::string iv = "v" + std::to_string(nextVarId());
  assignName(op.getInductionVar(), iv);
  os << "    for (int " << iv << " = ";
  os << getName(op.getLowerBound()) << "; " << iv << " < "
     << getName(op.getUpperBound()) << "; " << iv << " += "
     << getName(op.getStep()) << ") {\n";

  // Emit body except the terminator (scf.yield)
  auto &bodyBlock = op.getBody()->getOperations();
  for (auto it = bodyBlock.begin(); it != bodyBlock.end(); ++it) {
    if (auto yieldOp = dyn_cast<scf::YieldOp>(*it)) {
      // scf.yield updates the loop-carried vars
      for (unsigned i = 0; i < yieldOp.getOperands().size(); ++i) {
        os << "    " << iterVarNames[i] << " = "
           << getName(yieldOp.getOperands()[i]) << ";\n";
      }
    } else {
      emitOp(*it);
    }
  }
  os << "    }\n";
}

void MSLEmitter::emitScfIf(mlir::scf::IfOp op) {
  auto &os = stream();
  os << "    if (" << getName(op.getCondition()) << ") {\n";
  for (Operation &thenOp : op.getThenRegion().front().without_terminator())
    emitOp(thenOp);
  os << "    }";
  if (!op.getElseRegion().empty()) {
    os << " else {\n";
    for (Operation &elseOp : op.getElseRegion().front().without_terminator())
      emitOp(elseOp);
    os << "    }";
  }
  os << "\n";
}

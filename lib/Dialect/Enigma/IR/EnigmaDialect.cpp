//===- EnigmaDialect.cpp - Enigma dialect implementation ------------------===//
//
// Dialect registration, op initialization, and custom assembly format
// implementations for enigma.kernel, enigma.vertex, and enigma.fragment.
//
//===----------------------------------------------------------------------===//

#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"

using namespace mlir;
using namespace enigma;

#include "enigma/Dialect/Enigma/IR/EnigmaDialect.cpp.inc"
#include "enigma/Dialect/Enigma/IR/EnigmaOpsEnums.cpp.inc"

#define GET_OP_CLASSES
#include "enigma/Dialect/Enigma/IR/EnigmaOps.cpp.inc"

void EnigmaDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "enigma/Dialect/Enigma/IR/EnigmaOps.cpp.inc"
      >();
}

// ============================================================================
// Shared parser/printer helpers for function-like ops
// ============================================================================

static void printFunctionLikeOp(OpAsmPrinter &printer, Operation *op,
                                StringRef symName, FunctionType funcType,
                                Region &body) {
  printer << " @" << symName << "(";
  auto &entryBlock = body.front();
  for (unsigned i = 0, e = funcType.getNumInputs(); i < e; ++i) {
    if (i > 0)
      printer << ", ";
    printer.printOperand(entryBlock.getArgument(i));
    printer << ": ";
    printer.printType(funcType.getInput(i));
  }
  printer << ")";

  if (funcType.getNumResults() > 0) {
    printer << " -> ";
    if (funcType.getNumResults() == 1) {
      printer.printType(funcType.getResult(0));
    } else {
      printer << "(";
      llvm::interleaveComma(funcType.getResults(), printer,
                            [&](Type t) { printer.printType(t); });
      printer << ")";
    }
  }
  printer << " ";
  printer.printRegion(body, /*printEntryBlockArgs=*/false);
}

static ParseResult parseFunctionLikeOp(OpAsmParser &parser,
                                       OperationState &result,
                                       bool hasResults) {
  StringAttr nameAttr;
  if (parser.parseSymbolName(nameAttr, "sym_name", result.attributes))
    return failure();

  SmallVector<OpAsmParser::Argument> args;
  SmallVector<Type> argTypes;

  if (parser.parseLParen())
    return failure();

  if (parser.parseOptionalRParen()) {
    do {
      OpAsmParser::Argument arg;
      Type argType;
      if (parser.parseArgument(arg) || parser.parseColon() ||
          parser.parseType(argType))
        return failure();
      arg.type = argType;
      args.push_back(arg);
      argTypes.push_back(argType);
    } while (succeeded(parser.parseOptionalComma()));

    if (parser.parseRParen())
      return failure();
  }

  SmallVector<Type> resultTypes;
  if (hasResults && succeeded(parser.parseOptionalArrow())) {
    if (parser.parseOptionalLParen()) {
      Type resultType;
      if (parser.parseType(resultType))
        return failure();
      resultTypes.push_back(resultType);
    } else {
      do {
        Type resultType;
        if (parser.parseType(resultType))
          return failure();
        resultTypes.push_back(resultType);
      } while (succeeded(parser.parseOptionalComma()));
      if (parser.parseRParen())
        return failure();
    }
  }

  auto funcType = FunctionType::get(parser.getContext(), argTypes, resultTypes);
  result.addAttribute("function_type", TypeAttr::get(funcType));

  auto *body = result.addRegion();
  if (parser.parseRegion(*body, args))
    return failure();

  return success();
}

// ============================================================================
// enigma.kernel — custom assembly format
// ============================================================================

void KernelOp::print(OpAsmPrinter &printer) {
  printFunctionLikeOp(printer, *this, getSymName(), getFunctionType(),
                      getBody());
}

ParseResult KernelOp::parse(OpAsmParser &parser, OperationState &result) {
  return parseFunctionLikeOp(parser, result, /*hasResults=*/false);
}

// ============================================================================
// enigma.vertex — custom assembly format
// ============================================================================

void VertexOp::print(OpAsmPrinter &printer) {
  printFunctionLikeOp(printer, *this, getSymName(), getFunctionType(),
                      getBody());
}

ParseResult VertexOp::parse(OpAsmParser &parser, OperationState &result) {
  return parseFunctionLikeOp(parser, result, /*hasResults=*/true);
}

// ============================================================================
// enigma.fragment — custom assembly format
// ============================================================================

void FragmentOp::print(OpAsmPrinter &printer) {
  printFunctionLikeOp(printer, *this, getSymName(), getFunctionType(),
                      getBody());
}

ParseResult FragmentOp::parse(OpAsmParser &parser, OperationState &result) {
  return parseFunctionLikeOp(parser, result, /*hasResults=*/true);
}

// ============================================================================
// enigma.vec_make — verifier
// ============================================================================

LogicalResult VecMakeOp::verify() {
  auto vecTy = llvm::cast<VectorType>(getResult().getType());
  int64_t n = vecTy.getNumElements();
  if (n < 1 || n > 4)
    return emitOpError("vec_make result vector width must be 1, 2, 3, or 4 "
                       "(got ") << n << ")";
  if (static_cast<int64_t>(getElems().size()) != n)
    return emitOpError("vec_make requires exactly ") << n
        << " scalar operands to build a " << vecTy << " (got "
        << getElems().size() << ")";
  Type elemTy = vecTy.getElementType();
  for (auto [idx, v] : llvm::enumerate(getElems())) {
    if (v.getType() != elemTy)
      return emitOpError("vec_make operand #") << idx
          << " type " << v.getType()
          << " does not match result element type " << elemTy;
  }
  return success();
}

// ============================================================================
// enigma.vec_extract — verifier
// ============================================================================

LogicalResult VecExtractOp::verify() {
  auto vecTy = llvm::cast<VectorType>(getInput().getType());
  int64_t n = vecTy.getNumElements();
  int32_t lane = getLane();
  if (lane < 0 || lane >= n)
    return emitOpError("vec_extract lane ") << lane
        << " out of range [0, " << n << ") for " << vecTy;
  if (getResult().getType() != vecTy.getElementType())
    return emitOpError("vec_extract result type ")
        << getResult().getType()
        << " does not match input element type " << vecTy.getElementType();
  return success();
}

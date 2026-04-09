#include "MetalDialect/MetalDialect.h"

#include "MetalDialect/MetalDialect.cpp.inc"
#include "MetalDialect/MetalOpsEnums.cpp.inc"

#define GET_OP_CLASSES
#include "MetalDialect/MetalOps.cpp.inc"

using namespace mlir;

void metal::MetalDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "MetalDialect/MetalOps.cpp.inc"
  >();
}

//===----------------------------------------------------------------------===//
// KernelOp custom assembly format
//===----------------------------------------------------------------------===//

// Print: metal.kernel @name(%arg0: type, ...) {body}
void metal::KernelOp::print(OpAsmPrinter &printer) {
  printer << " @" << getSymName() << "(";
  auto funcType = getFunctionType();
  auto &entryBlock = getBody().front();
  for (unsigned i = 0; i < funcType.getNumInputs(); ++i) {
    if (i > 0) printer << ", ";
    printer.printOperand(entryBlock.getArgument(i));
    printer << ": ";
    printer.printType(funcType.getInput(i));
  }
  printer << ") ";
  printer.printRegion(getBody(), /*printEntryBlockArgs=*/false);
}

// Parse: metal.kernel @name(%arg0: type, ...) {body}
ParseResult metal::KernelOp::parse(OpAsmParser &parser,
                                    OperationState &result) {
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

  auto funcType = FunctionType::get(parser.getContext(), argTypes, {});
  result.addAttribute("function_type", TypeAttr::get(funcType));

  auto *body = result.addRegion();
  if (parser.parseRegion(*body, args))
    return failure();

  return success();
}

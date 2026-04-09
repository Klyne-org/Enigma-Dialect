//===- EnigmaDialect.cpp - Enigma dialect implementation ------------------===//
//
// WHAT THIS FILE IS
//   The C++ implementation of the Enigma dialect. Nearly everything here is
//   generated — we just provide:
//
//     1. The `initialize()` hook that registers all ops with the dialect.
//     2. A custom parser / printer for `enigma.kernel`, because its
//        assembly format is too complex for tablegen's `assemblyFormat`
//        string DSL to express.
//
//   Everything else — op accessors, builders, trait checks — comes from
//   the tablegen-generated `EnigmaOps.cpp.inc`.
//
// HOW TO EXTEND
//   - New op with a standard assembly format: nothing to do here. Add the
//     op to EnigmaOps.td, set `assemblyFormat = "..."`, rebuild. Tablegen
//     handles everything.
//
//   - New op with a custom assembly format: add `hasCustomAssemblyFormat = 1`
//     in the .td, then implement `ThatOp::parse()` and `ThatOp::print()`
//     methods in this file, modeled on the KernelOp code below.
//
//   - New op with a custom verifier: add `hasVerifier = 1` in the .td,
//     then implement `ThatOp::verify()` in this file.
//
//===----------------------------------------------------------------------===//

#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"

using namespace mlir;
using namespace enigma;

//===----------------------------------------------------------------------===//
// Generated dialect & enum definitions
//===----------------------------------------------------------------------===//
//
// These two includes pull in the C++ definitions that tablegen produced.
// They must appear BEFORE the GET_OP_CLASSES include below, because the
// op definitions reference the dialect class and enum types.
#include "enigma/Dialect/Enigma/IR/EnigmaDialect.cpp.inc"
#include "enigma/Dialect/Enigma/IR/EnigmaOpsEnums.cpp.inc"

// GET_OP_CLASSES emits the op class *definitions* (parser/printer/verifier
// implementations), as opposed to GET_OP_CLASSES in the .h which emits
// declarations. Same macro name, different meaning based on which .inc
// file it precedes. (Yes, that's confusing — it's an MLIR convention.)
#define GET_OP_CLASSES
#include "enigma/Dialect/Enigma/IR/EnigmaOps.cpp.inc"

//===----------------------------------------------------------------------===//
// Dialect::initialize() — called once when the dialect is registered.
//===----------------------------------------------------------------------===//
//
// MLIR's dialect-registration mechanism is: when a context sees an op with
// prefix `enigma.`, it looks up the `EnigmaDialect` and calls
// `initialize()`. Our job here is to tell the dialect which ops belong to
// it, by calling `addOperations<...>()` with the full op list.
//
// The `GET_OP_LIST` macro expands to a comma-separated list of every op
// class in EnigmaOps.cpp.inc — so this stays correct automatically as we
// add ops. You never have to edit this list by hand.
void EnigmaDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "enigma/Dialect/Enigma/IR/EnigmaOps.cpp.inc"
      >();

  // NEXT STEPS: when we add custom dialect types, they are registered here
  // with a matching `addTypes<...>()` call. When we add attributes, same
  // with `addAttributes<...>()`. Keeping these calls together is what
  // lets the dialect parser know what spellings to recognize in .mlir text.
}

//===----------------------------------------------------------------------===//
// enigma.kernel — custom assembly format
//===----------------------------------------------------------------------===//
//
// TARGET SYNTAX
//   enigma.kernel @name(%arg0: memref<?xf32>, %arg1: memref<?xf32>) {
//     ... body ...
//     enigma.return
//   }
//
// Why custom instead of tablegen `assemblyFormat`: we need to parse the
// argument list AND create matching block arguments in the kernel body's
// entry block, in one pass. Tablegen's string-based assemblyFormat DSL
// doesn't support that — it can only plumb already-parsed values into an
// OperationState. So we drop into the C++ parser API.
//
// The parser code below is the minimal thing that works. It is not robust
// to things like attribute dictionaries on the kernel or empty arg lists
// with trailing commas — that's fine for the base. Harden as needed.
//===----------------------------------------------------------------------===//

void KernelOp::print(OpAsmPrinter &printer) {
  printer << " @" << getSymName() << "(";

  auto funcType = getFunctionType();
  auto &entryBlock = getBody().front();

  // Print "(%arg0: type0, %arg1: type1, ...)"
  for (unsigned i = 0, e = funcType.getNumInputs(); i < e; ++i) {
    if (i > 0)
      printer << ", ";
    printer.printOperand(entryBlock.getArgument(i));
    printer << ": ";
    printer.printType(funcType.getInput(i));
  }
  printer << ") ";

  // Print the body region. `printEntryBlockArgs=false` tells the printer
  // we already printed the block's arguments as the function signature,
  // so it shouldn't re-print them at the start of the block.
  printer.printRegion(getBody(), /*printEntryBlockArgs=*/false);
}

ParseResult KernelOp::parse(OpAsmParser &parser, OperationState &result) {
  // --- kernel name ----------------------------------------------------------
  // Parses `@vector_add` and stores it in the `sym_name` attribute.
  StringAttr nameAttr;
  if (parser.parseSymbolName(nameAttr, "sym_name", result.attributes))
    return failure();

  // --- argument list --------------------------------------------------------
  // We collect two parallel arrays: `args` feeds the parseRegion call
  // (which creates the block arguments) and `argTypes` feeds the
  // FunctionType we'll store in the `function_type` attribute.
  SmallVector<OpAsmParser::Argument> args;
  SmallVector<Type> argTypes;

  if (parser.parseLParen())
    return failure();

  // `parseOptionalRParen()` returns success if it consumed `)`. Counter-
  // intuitively, that means the condition below reads "if there was NOT an
  // immediate closing paren, parse the argument list." MLIR's parser API
  // uses success() to mean "yes this token was here" throughout.
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

  // --- function type attribute ----------------------------------------------
  // Enigma kernels always return void, so the result list is empty.
  auto funcType = FunctionType::get(parser.getContext(), argTypes, {});
  result.addAttribute("function_type", TypeAttr::get(funcType));

  // --- body region ----------------------------------------------------------
  // parseRegion will create the entry block with one argument per `args`
  // entry, using the names we parsed. That's why we collected them.
  auto *body = result.addRegion();
  if (parser.parseRegion(*body, args))
    return failure();

  return success();
}

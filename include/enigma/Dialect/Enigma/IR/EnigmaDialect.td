//===- EnigmaDialect.td - Enigma dialect definition --------*- tablegen -*-===//
//
// WHAT THIS FILE IS
//   This is the TableGen definition of the `enigma` dialect itself. A
//   "dialect" in MLIR is a namespace for a related group of ops, types, and
//   attributes. Every op you define in EnigmaOps.td belongs to this dialect.
//
//   TableGen (`.td`) files are a declarative DSL that `mlir-tblgen` reads to
//   *generate* C++ code at build time. You do not write boilerplate like
//   "parse this op, print this op, verify this op" by hand — you describe
//   the op in a .td file and let tablegen emit the C++ for you.
//
// HOW THIS FILE IS USED
//   CMake (via include/enigma/Dialect/Enigma/IR/CMakeLists.txt) invokes
//   mlir-tblgen on this file with the `-gen-dialect-decls` and
//   `-gen-dialect-defs` flags. That produces:
//
//     EnigmaDialect.h.inc   (included by EnigmaDialect.h)
//     EnigmaDialect.cpp.inc (included by EnigmaDialect.cpp)
//
//   These generated files contain the `class EnigmaDialect : public Dialect`
//   declaration and its registration plumbing.
//
// HOW TO EXTEND
//   - Add dependent dialects (e.g. if your ops use `memref` types, list the
//     memref dialect as a dependent).
//   - Add a useDefaultTypePrinterParser / useDefaultAttributePrinterParser
//     flag if you introduce custom dialect types/attributes (we'll do that
//     in a later step when adding address spaces and texture types).
//   - Add a `let extraClassDeclaration = [{ ... }];` block if you need
//     custom C++ methods on the dialect class.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_DIALECT_TD
#define ENIGMA_DIALECT_TD

// OpBase.td gives us the core TableGen classes: Dialect, Op, Type, Attr, etc.
// Without this include the rest of the file is meaningless.
include "mlir/IR/OpBase.td"

//===----------------------------------------------------------------------===//
// Enigma Dialect
//===----------------------------------------------------------------------===//

def Enigma_Dialect : Dialect {
  // The mnemonic that appears in MLIR text: `enigma.kernel`, `enigma.return`.
  // Keep it short — users will type this thousands of times.
  let name = "enigma";

  // The C++ namespace that the generated classes live in. We prefix with ::
  // to anchor it at global scope and avoid accidental nesting.
  let cppNamespace = "::enigma";

  let summary = "Dialect modeling Apple Metal compute & shading constructs";

  let description = [{
    The Enigma dialect represents Apple Metal GPU programs in MLIR form.
    Every op in this dialect maps to a concrete construct in the Metal
    Shading Language (MSL) or Metal host API, so that lowering from higher-
    level dialects (gpu, linalg, vector) can target Metal end-to-end.

    Coverage includes: compute/vertex/fragment entry points, thread indexing,
    synchronization barriers, threadgroup memory, SIMD group operations,
    atomics, GPU math built-ins, geometric/vector functions, texture
    operations, integer intrinsics, and type casts.
  }];

  // When we add custom types (like !enigma.texture2d<...>) we'll flip these
  // to 1. For now the dialect has no custom types, so we leave them off and
  // avoid having to implement printType/parseType methods.
  //
  // let useDefaultTypePrinterParser = 1;
  // let useDefaultAttributePrinterParser = 1;
}

//===----------------------------------------------------------------------===//
// Shared base class for all Enigma ops
//===----------------------------------------------------------------------===//
//
// Every op in EnigmaOps.td will inherit from `Enigma_Op<"name">` instead of
// the raw `Op<Enigma_Dialect, "name">`. That saves us from repeating
// `Enigma_Dialect` on every single op definition, and gives us a single
// place to attach cross-cutting traits later (e.g. a future MSLEmittable
// OpInterface that every op must implement).
class Enigma_Op<string mnemonic, list<Trait> traits = []>
    : Op<Enigma_Dialect, mnemonic, traits>;

#endif // ENIGMA_DIALECT_TD

//===- TranslateToMSL.h - Public API for Enigma->MSL translation *- C++ -*-===//
//
// WHAT THIS FILE IS
//   The public entry points for translating an `enigma`-dialect MLIR
//   module into MSL (Metal Shading Language) source text.
//
//   Two entry points are declared here:
//
//     1. translateToMSL(ModuleOp, raw_ostream&)
//          The programmatic API. Call this from C++ code that has an
//          MLIR module in memory and wants an MSL string out. This is
//          what Python bindings / JIT compilers / test harnesses call.
//
//     2. registerToMSLTranslation()
//          Registers the translation with MLIR's global translation
//          registry under the name "enigma-to-msl". After this is
//          called once at tool startup, `enigma-translate --enigma-to-msl
//          foo.mlir` works from the command line.
//
// WHY TWO ENTRY POINTS
//   mlir-translate's registry wants a global side-effecting registration
//   that is called during static initialization of a tool binary. But a
//   library that's linked from Python or from another C++ tool shouldn't
//   *require* that registry — it should be possible to call the emitter
//   directly. So we expose both: the registry hook for `enigma-translate`,
//   and the pure function for everything else.
//
// HOW TO EXTEND
//   - Add new emitters (e.g. to AIR IR, to SPIR-V, to a direct .metallib)
//     by declaring more `translateToX(ModuleOp, raw_ostream&)` functions
//     in their own headers under include/enigma/Target/X/.
//
//   - Add options to translateToMSL (e.g. target MSL version, whether to
//     emit debug info) by introducing an `MSLEmitterOptions` struct and
//     threading it through both entry points. Do not add boolean flags
//     one-by-one — future-you will thank you for the struct.
//
//===----------------------------------------------------------------------===//

#pragma once

#include "mlir/IR/BuiltinOps.h"    // ModuleOp
#include "mlir/Support/LogicalResult.h"

namespace llvm {
class raw_ostream;
} // namespace llvm

namespace enigma {

/// Emit MSL source for every `enigma.kernel` op in `module` to `os`.
/// Returns success() if every kernel was emitted cleanly.
mlir::LogicalResult translateToMSL(mlir::ModuleOp module,
                                   llvm::raw_ostream &os);

/// Register `--enigma-to-msl` with the global mlir-translate registry so
/// that `enigma-translate --enigma-to-msl foo.mlir` works. Safe to call
/// multiple times — the registry dedups by name.
void registerToMSLTranslation();

} // namespace enigma

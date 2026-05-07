// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- InitAll.h - Single registration entry point for Enigma -*- C++ -*-===//
//
// WHAT THIS FILE IS
//   The one place where every tool, Python binding, or embedded use of
//   Enigma calls to register "everything we've got" with an MLIRContext
//   or translation registry. There is exactly one such function per
//   category:
//
//     registerAllEnigmaDialects(DialectRegistry&)
//         Register all dialects we define (currently just `enigma`) plus
//         the upstream dialects we depend on (arith, memref, func). Call
//         this from any tool that parses .mlir input.
//
//     registerAllEnigmaPasses()
//         Register every pass we define. Currently empty — we have no
//         passes yet. Kept here so that the moment you add your first
//         pass (KernelOutlining, ArgumentBufferPacking, …) you have a
//         single hook to wire it into.
//
//     registerAllEnigmaTranslations()
//         Register every mlir-translate direction we support. Currently
//         just `enigma-to-msl`.
//
// WHY THIS MATTERS
//   Without an InitAll layer, every new tool has to remember to call
//   every registration hook by hand. That's how you end up in "works in
//   enigma-opt but not in enigma-translate" purgatory. By funnelling all
//   tools through this one layer, adding a new dialect or pass means
//   editing exactly one file — this one. Tools never touch it.
//
// HOW TO EXTEND
//   When you add a new dialect, add `registry.insert<YourDialect>();` to
//   registerAllEnigmaDialects. When you add a new pass, add its register
//   call to registerAllEnigmaPasses. When you add a new translation, add
//   its register call to registerAllEnigmaTranslations. That's it.
//
//===----------------------------------------------------------------------===//

#pragma once

namespace mlir {
class DialectRegistry;
} // namespace mlir

namespace enigma {

/// Register all dialects produced by this project + their upstream
/// dependencies, so that the DialectRegistry is ready to parse any .mlir
/// file the rest of the project might emit.
void registerAllEnigmaDialects(mlir::DialectRegistry &registry);

/// Register all passes defined by this project. Currently a no-op — it
/// exists so the wiring is already in place when you write your first pass.
void registerAllEnigmaPasses();

/// Register every mlir-translate translation direction (enigma-to-msl, and
/// future ones like enigma-to-metallib, enigma-to-air, etc.).
void registerAllEnigmaTranslations();

} // namespace enigma

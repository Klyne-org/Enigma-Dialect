// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- EnigmaDialect.h - Enigma dialect public header ----------*- C++ -*-===//
//
// WHAT THIS FILE IS
//   The public C++ header that downstream code (tools, translation,
//   conversion passes, Python bindings, user programs) includes to use the
//   Enigma dialect. One `#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"`
//   should be enough to construct ops, walk them, and pattern-match on
//   their types.
//
//   This file is *entirely* glue — the interesting declarations live in the
//   tablegen-generated .inc files. The reason to still have a hand-written
//   header is that the .inc files need certain MLIR types to be declared
//   before they are included (OpDefinition.h, BuiltinTypes.h, etc.), and
//   downstream users shouldn't have to remember the right include order.
//
// WHY `#pragma once` AND NOT INCLUDE GUARDS
//   `#pragma once` is universally supported by every compiler MLIR targets,
//   it's one line shorter, and it avoids header-guard naming collisions
//   that become annoying as the project grows. Upstream MLIR uses header
//   guards for historical reasons; we don't inherit that constraint.
//
// HOW TO EXTEND
//   When you add custom dialect types (e.g. !enigma.texture2d<...>),
//   add a matching `#include "enigma/Dialect/Enigma/IR/EnigmaTypes.h.inc"`
//   below the enums include and above the ops include. Type declarations
//   have to come before op declarations because ops reference types.
//
//===----------------------------------------------------------------------===//

#pragma once

// MLIR headers that the tablegen .inc files depend on. The order below is
// carefully chosen — each of the generated .inc files assumes these types
// are already visible. Modern MLIR (20+) also requires the bytecode
// interface header because every generated op class declares
// read/writeProperties methods that mention DialectBytecodeReader/Writer.
#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

// -----------------------------------------------------------------------------
// Dialect class declaration — generated from EnigmaDialect.td.
// -----------------------------------------------------------------------------
// This pulls in the `class EnigmaDialect : public Dialect { ... };` that
// tablegen emitted. It includes the dialect's constructor and the
// `initialize()` hook that we implement in EnigmaDialect.cpp.
#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h.inc"

// -----------------------------------------------------------------------------
// Enum types — generated from EnigmaOps.td enum blocks.
// -----------------------------------------------------------------------------
// Every I32EnumAttr declared in the .td (currently just Enigma_Dimension)
// produces a `enum class Dimension : uint32_t { x, y, z };` plus the
// string<->enum conversion helpers. Ops that take enum attributes
// reference these types, so this include must come before the op include.
#include "enigma/Dialect/Enigma/IR/EnigmaOpsEnums.h.inc"

// -----------------------------------------------------------------------------
// Op class declarations — generated from EnigmaOps.td op defs.
// -----------------------------------------------------------------------------
// The `GET_OP_CLASSES` macro tells the .inc file to emit just the class
// declarations (`class KernelOp : public Op<KernelOp, ...> { ... };`).
// The definitions (parser, printer, verifier) are emitted into the
// matching .cpp.inc and included from EnigmaDialect.cpp.
#define GET_OP_CLASSES
#include "enigma/Dialect/Enigma/IR/EnigmaOps.h.inc"

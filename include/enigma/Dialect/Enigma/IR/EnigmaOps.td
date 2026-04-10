//===- EnigmaOps.td - Master include for all Enigma ops ----*- tablegen -*-===//
//
// Pulls together every op category into a single tablegen entry point.
// CMake's mlir_tablegen invocation targets this file; it transitively
// includes all sub-modules and produces a unified set of .inc files.
//
// Module layout:
//   EnigmaEnums.td      — all enum attributes
//   EnigmaFuncOps.td    — kernel / vertex / fragment / return
//   EnigmaThreadOps.td  — thread indexing builtins
//   EnigmaSyncOps.td    — barriers + threadgroup memory
//   EnigmaSimdOps.td    — SIMD group operations
//   EnigmaAtomicOps.td  — atomic operations
//   EnigmaMathOps.td    — GPU math built-ins (float)
//   EnigmaIntOps.td     — integer intrinsics
//   EnigmaGeomOps.td    — geometric / vector functions
//   EnigmaTextureOps.td — texture read / write / sample
//   EnigmaCastOps.td    — type casts and packing
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_OPS_TD
#define ENIGMA_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/BuiltinAttributes.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/IR/EnumAttr.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// Enums first — other modules reference them.
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"

// Op modules — order does not matter since they are independent.
include "enigma/Dialect/Enigma/IR/EnigmaFuncOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaThreadOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaSyncOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaSimdOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaAtomicOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaMathOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaIntOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaGeomOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaTextureOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaCastOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaRelationalOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaQuadOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaControlFlowOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaPackOps.td"
include "enigma/Dialect/Enigma/IR/EnigmaMatrixOps.td"

#endif // ENIGMA_OPS_TD

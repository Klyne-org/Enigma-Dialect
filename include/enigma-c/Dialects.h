// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

#ifndef ENIGMA_C_DIALECTS_H
#define ENIGMA_C_DIALECTS_H

#include "mlir-c/IR.h"
#include "mlir-c/Support.h"

#ifdef __cplusplus
extern "C" {
#endif

MLIR_CAPI_EXPORTED MlirDialectHandle mlirGetDialectHandle__enigma__(void);

/// Translate an MLIR module containing enigma ops into MSL source text.
/// On success, invokes `callback(str, userData)` exactly once with the
/// emitted MSL text and returns success. Returns failure if the passed
/// operation is not a builtin.module or the emitter fails.
MLIR_CAPI_EXPORTED MlirLogicalResult
enigmaTranslateModuleToMSL(MlirOperation moduleOp,
                           MlirStringCallback callback, void *userData);

/// Run a minimal cleanup pipeline (canonicalize + CSE) on a module in place.
MLIR_CAPI_EXPORTED MlirLogicalResult
enigmaRunStandardPipeline(MlirOperation moduleOp);

#ifdef __cplusplus
}
#endif

#endif // ENIGMA_C_DIALECTS_H

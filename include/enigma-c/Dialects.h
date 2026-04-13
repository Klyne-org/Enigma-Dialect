#ifndef ENIGMA_C_DIALECTS_H
#define ENIGMA_C_DIALECTS_H

#include "mlir-c/IR.h"

#ifdef __cplusplus
extern "C" {
#endif

MLIR_CAPI_EXPORTED MlirDialectHandle mlirGetDialectHandle__enigma__(void);

#ifdef __cplusplus
}
#endif

#endif // ENIGMA_C_DIALECTS_H

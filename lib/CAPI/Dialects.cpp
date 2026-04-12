#include "enigma-c/Dialects.h"
#include "mlir/CAPI/Registration.h"
#include "enigma/Dialect/Enigma/IR/EnigmaDialect.h"

MLIR_DEFINE_CAPI_DIALECT_REGISTRATION(Enigma, enigma,
                                      ::enigma::EnigmaDialect)

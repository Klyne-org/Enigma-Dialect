#include "enigma-c/Dialects.h"
#include "mlir-c/Dialect/Arith.h"
#include "mlir-c/Dialect/Func.h"
#include "mlir-c/Dialect/MemRef.h"
#include "mlir/Bindings/Python/NanobindAdaptors.h"

namespace nb = nanobind;
using namespace mlir::python::nanobind_adaptors;

NB_MODULE(_mlirDialectsEnigma, m) {
  m.doc() = "Enigma dialect Python bindings";

  m.def(
      "register_dialect",
      [](MlirContext context, bool load) {
        MlirDialectHandle enigmaHandle = mlirGetDialectHandle__enigma__();
        mlirDialectHandleRegisterDialect(enigmaHandle, context);

        MlirDialectHandle arithHandle = mlirGetDialectHandle__arith__();
        mlirDialectHandleRegisterDialect(arithHandle, context);

        MlirDialectHandle memrefHandle = mlirGetDialectHandle__memref__();
        mlirDialectHandleRegisterDialect(memrefHandle, context);

        MlirDialectHandle funcHandle = mlirGetDialectHandle__func__();
        mlirDialectHandleRegisterDialect(funcHandle, context);

        if (load) {
          mlirDialectHandleLoadDialect(enigmaHandle, context);
          mlirDialectHandleLoadDialect(arithHandle, context);
          mlirDialectHandleLoadDialect(memrefHandle, context);
          mlirDialectHandleLoadDialect(funcHandle, context);
        }
      },
      nb::arg("context"), nb::arg("load") = true);
}

#include "enigma-c/Dialects.h"

#include "mlir-c/Dialect/Arith.h"
#include "mlir-c/Dialect/Func.h"
#include "mlir-c/Dialect/MemRef.h"
#include "mlir-c/Dialect/SCF.h"
#include "mlir-c/BuiltinAttributes.h"
#include "mlir-c/BuiltinTypes.h"
#include "mlir-c/IR.h"
#include "mlir-c/Support.h"
#include "mlir/Bindings/Python/NanobindAdaptors.h"

#include <stdexcept>
#include <string>

namespace nb = nanobind;
using namespace mlir::python::nanobind_adaptors;

static void appendToString(MlirStringRef ref, void *userData) {
  auto *buf = static_cast<std::string *>(userData);
  buf->append(ref.data, ref.length);
}

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

        MlirDialectHandle scfHandle = mlirGetDialectHandle__scf__();
        mlirDialectHandleRegisterDialect(scfHandle, context);

        if (load) {
          mlirDialectHandleLoadDialect(enigmaHandle, context);
          mlirDialectHandleLoadDialect(arithHandle, context);
          mlirDialectHandleLoadDialect(memrefHandle, context);
          mlirDialectHandleLoadDialect(funcHandle, context);
          mlirDialectHandleLoadDialect(scfHandle, context);
        }
      },
      nb::arg("context"), nb::arg("load") = true);

  m.def(
      "translate_to_msl",
      [](MlirOperation op) {
        std::string buffer;
        MlirLogicalResult r =
            enigmaTranslateModuleToMSL(op, appendToString, &buffer);
        if (!mlirLogicalResultIsSuccess(r)) {
          throw std::runtime_error(
              "translate_to_msl failed (module must be builtin.module "
              "and contain well-formed enigma IR)");
        }
        return buffer;
      },
      nb::arg("operation"),
      "Translate an enigma-dialect module to MSL source text.");

  m.def(
      "run_standard_pipeline",
      [](MlirOperation op) {
        MlirLogicalResult r = enigmaRunStandardPipeline(op);
        if (!mlirLogicalResultIsSuccess(r)) {
          throw std::runtime_error("run_standard_pipeline failed");
        }
      },
      nb::arg("operation"),
      "Run canonicalize + cse on the given module in-place.");

  m.def(
      "dimension_attr",
      [](MlirContext context, const std::string &axis) {
        uint32_t val;
        if (axis == "x") val = 0;
        else if (axis == "y") val = 1;
        else if (axis == "z") val = 2;
        else throw std::invalid_argument(
            "dimension_attr: axis must be 'x', 'y', or 'z'");
        MlirType i32 = mlirIntegerTypeGet(context, 32);
        return mlirIntegerAttrGet(i32, val);
      },
      nb::arg("context"), nb::arg("axis"),
      "Build the enigma Dimension enum attribute for 'x', 'y', or 'z' "
      "(a signless i32 IntegerAttr with value 0/1/2).");
}

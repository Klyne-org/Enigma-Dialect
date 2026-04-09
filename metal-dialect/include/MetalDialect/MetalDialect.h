#pragma once

#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "MetalDialect/MetalDialect.h.inc"

#include "MetalDialect/MetalOpsEnums.h.inc"

#define GET_OP_CLASSES
#include "MetalDialect/MetalOps.h.inc"

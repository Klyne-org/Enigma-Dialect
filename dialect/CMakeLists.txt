cmake_minimum_required(VERSION 3.20)
project(EnigmaDialect LANGUAGES CXX)

# Requires MLIR to be installed / findable
find_package(MLIR REQUIRED CONFIG)

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
include(TableGen)
include(AddMLIR)

# ── TableGen: generate C++ from .td files ────────────────────────────────

set(ENIGMA_TD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include/EnigmaDialect)

set(LLVM_TARGET_DEFINITIONS ${ENIGMA_TD_DIR}/EnigmaOps.td)

mlir_tablegen(EnigmaOps.h.inc    -gen-op-decls)
mlir_tablegen(EnigmaOps.cpp.inc  -gen-op-defs)
mlir_tablegen(EnigmaDialect.h.inc  -gen-dialect-decls)
mlir_tablegen(EnigmaDialect.cpp.inc  -gen-dialect-defs)
mlir_tablegen(EnigmaTypes.h.inc  -gen-typedef-decls)
mlir_tablegen(EnigmaTypes.cpp.inc  -gen-typedef-defs)

add_public_tablegen_target(EnigmaOpsIncGen)

# ── Dialect library ──────────────────────────────────────────────────────

# (Placeholder — C++ implementations will be added in lib/)

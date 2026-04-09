# =============================================================================
# tools/enigma-opt/CMakeLists.txt — the enigma-opt executable
# =============================================================================
#
# Links enigma-opt.cpp against MLIROptLib (which provides MlirOptMain),
# our InitAll library (which pulls in the dialect transitively), and the
# global MLIR dialect libraries so `-canonicalize`, `-cse`, etc. work.
# =============================================================================

# `GLOBAL PROPERTY MLIR_DIALECT_LIBS` is populated by every
# `add_mlir_dialect_library` call. Pulling it in here means enigma-opt
# automatically picks up every dialect registered anywhere in the project,
# including future ones you add.
get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)

add_llvm_executable(enigma-opt enigma-opt.cpp)

target_link_libraries(enigma-opt PRIVATE
  EnigmaInitAll
  ${dialect_libs}
  MLIROptLib
  MLIRParser
)

# Sanity check that every MLIR library enigma-opt references is actually
# linked. Catches "forgot to add X to LINK_LIBS" before it becomes a
# painful link error.
mlir_check_all_link_libraries(enigma-opt)

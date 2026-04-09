# =============================================================================
# include/enigma/Dialect/Enigma/IR/CMakeLists.txt — TableGen invocation
# =============================================================================
#
# WHAT THIS FILE DOES
#   Runs `mlir-tblgen` on EnigmaDialect.td / EnigmaOps.td to generate the
#   C++ headers that EnigmaDialect.h and EnigmaDialect.cpp include. The
#   generated files are placed in the build directory, not the source
#   tree — that's why the root CMakeLists adds both `include/` and
#   `${CMAKE_CURRENT_BINARY_DIR}/include` to the include path.
#
# WHAT GETS GENERATED
#   From EnigmaOps.td (which transitively includes EnigmaDialect.td),
#   mlir-tblgen produces six files:
#
#     EnigmaDialect.h.inc    | dialect class declaration
#     EnigmaDialect.cpp.inc  | dialect class definition + registration
#     EnigmaOps.h.inc        | one C++ class per op (declarations)
#     EnigmaOps.cpp.inc      | op parsers, printers, verifiers, builders
#     EnigmaOpsEnums.h.inc   | enum types declared in .td (e.g. Dimension)
#     EnigmaOpsEnums.cpp.inc | enum string<->value conversion + parsing
#
#   The "Gen" target below bundles them into a single CMake target that
#   other libraries can DEPENDS on, so that the tablegen step runs before
#   anything tries to compile a file that `#include`s the .inc files.
#
# HOW TO EXTEND
#   When you split EnigmaOps.td into multiple files (e.g. EnigmaDeviceOps.td,
#   EnigmaHostOps.td, EnigmaMemoryOps.td), add a block per file:
#
#     set(LLVM_TARGET_DEFINITIONS EnigmaDeviceOps.td)
#     mlir_tablegen(EnigmaDeviceOps.h.inc -gen-op-decls)
#     mlir_tablegen(EnigmaDeviceOps.cpp.inc -gen-op-defs)
#
#   and bundle them all into a single `add_public_tablegen_target()` at the
#   end, or one target per file. One target per file is slightly cleaner
#   and gives better incremental rebuilds.
# =============================================================================

# Tell mlir_tablegen() which .td file to feed into mlir-tblgen for the
# following commands. This is a CMake-level variable — the `mlir_tablegen()`
# calls below all read it implicitly.
set(LLVM_TARGET_DEFINITIONS EnigmaOps.td)

# Op declarations (header side) — one `class XxxOp : public Op<...>` per op.
mlir_tablegen(EnigmaOps.h.inc   -gen-op-decls)
# Op definitions (implementation side) — parsers, printers, verifiers.
mlir_tablegen(EnigmaOps.cpp.inc -gen-op-defs)

# Dialect class declarations and definition.
# The `-dialect=enigma` flag is required when the .td file transitively
# includes other dialects (our BuiltinAttributes / SideEffectInterfaces
# includes drag in the builtin dialect). Without it, mlir-tblgen errors
# with "when more than 1 dialect is present, one must be selected".
mlir_tablegen(EnigmaDialect.h.inc   -gen-dialect-decls -dialect=enigma)
mlir_tablegen(EnigmaDialect.cpp.inc -gen-dialect-defs  -dialect=enigma)

# Enum types declared in the .td (Enigma_Dimension → enigma::Dimension).
mlir_tablegen(EnigmaOpsEnums.h.inc   -gen-enum-decls)
mlir_tablegen(EnigmaOpsEnums.cpp.inc -gen-enum-defs)

# Bundle all the above into a named target. `add_public_tablegen_target`
# is an MLIR helper that sets up the dependency graph so any library that
# does `DEPENDS EnigmaDialectIncGen` will wait for these files before
# compiling. We'll reference this target from lib/Dialect/Enigma/IR/CMakeLists.txt.
add_public_tablegen_target(EnigmaDialectIncGen)

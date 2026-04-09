# =============================================================================
# lib/Dialect/Enigma/IR/CMakeLists.txt — the core dialect library
# =============================================================================
#
# WHAT THIS FILE DOES
#   Builds `libEnigmaDialect.a`, the static library that contains the
#   dialect class and all its op implementations. Every tool that uses the
#   Enigma dialect (enigma-opt, enigma-translate, future Python bindings)
#   links against this.
#
# WHY `add_mlir_dialect_library` INSTEAD OF `add_library`
#   `add_mlir_dialect_library` is an MLIR-provided helper that:
#     - Registers the library as a "dialect library" in an MLIR-wide
#       CMake property, so that `get_property(... MLIR_DIALECT_LIBS)` in
#       downstream tool CMakeLists will pick it up automatically.
#     - Sets up correct include paths and link-visibility rules.
#     - Applies the same compile flags MLIR itself is built with (warnings,
#       sanitizers, hidden visibility).
#
#   Using plain `add_library` here would compile the files fine but cause
#   mysterious "undefined dialect" errors in the tools later, because they
#   iterate over MLIR_DIALECT_LIBS to decide what to register.
#
# HOW TO EXTEND
#   When you add more .cpp files to this directory (e.g. EnigmaTypes.cpp,
#   EnigmaVerifier.cpp), list them between EnigmaDialect.cpp and DEPENDS.
#   Keep one source file per concern — don't put everything into one
#   giant EnigmaDialect.cpp.
# =============================================================================

add_mlir_dialect_library(EnigmaDialect
  # --- source files -----------------------------------------------------
  EnigmaDialect.cpp

  # --- additional include directories (none beyond the defaults) --------
  # ADDITIONAL_HEADER_DIRS
  #   ${CMAKE_CURRENT_SOURCE_DIR}/../../../../include/enigma/Dialect/Enigma/IR

  # --- build-order dependency on the tablegen step ----------------------
  # This is what guarantees mlir-tblgen runs BEFORE EnigmaDialect.cpp is
  # compiled. Without it, the build occasionally fails on clean rebuilds
  # because the .inc files don't exist yet when the .cpp is fed to clang.
  DEPENDS
  EnigmaDialectIncGen

  # --- libraries we need at link time -----------------------------------
  LINK_LIBS PUBLIC
  MLIRIR            # core MLIR IR types (Operation, Value, Type, Region, …)
  MLIRSupport       # LLVM-style support utilities
)

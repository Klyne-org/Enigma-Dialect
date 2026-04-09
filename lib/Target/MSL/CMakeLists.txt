# =============================================================================
# lib/Target/MSL/CMakeLists.txt — the MSL text emitter library
# =============================================================================
#
# WHAT THIS BUILDS
#   libEnigmaTargetMSL.a — a static library containing the MSLEmitter and
#   the mlir-translate registration hook. This is a "translation library"
#   in MLIR terminology: it lowers MLIR IR to a non-MLIR textual form.
#
# WHY `add_mlir_translation_library`
#   It's the same shape as `add_mlir_dialect_library` but registers into
#   the MLIR_TRANSLATION_LIBS global property instead of MLIR_DIALECT_LIBS.
#   Tools that want "all translation libraries" (like enigma-translate)
#   iterate that property — using the helper means you never have to list
#   them by hand.
#
# LINK DEPENDENCIES
#   The emitter pattern-matches on ops from several dialects, so we need
#   each of their libraries at link time. If you extend the emitter to
#   handle scf, vector, linalg, etc., add their libraries here too.
#
# HOW TO EXTEND
#   When you split the emitter into multiple files (MSLTypePrinter.cpp,
#   MSLExpressionPrinter.cpp, etc.), list them alongside MSLEmitter.cpp
#   below. When you add a second backend target (MetalLib compilation),
#   that goes in lib/Target/MetalLib/CMakeLists.txt with its own library.
# =============================================================================

add_mlir_translation_library(EnigmaTargetMSL
  # --- source files -----------------------------------------------------
  MSLEmitter.cpp

  # --- build-order dependency on tablegen -------------------------------
  # The emitter includes EnigmaDialect.h which transitively includes the
  # tablegen-generated .inc files. Same deal as the dialect library — if
  # we don't declare this, parallel builds sometimes compile MSLEmitter.cpp
  # before the .inc files are written.
  DEPENDS
  EnigmaDialectIncGen

  # --- libraries we need at link time -----------------------------------
  LINK_LIBS PUBLIC
  EnigmaDialect          # our own dialect library
  MLIRIR                 # ModuleOp, Operation, Value, …
  MLIRSupport            # LogicalResult, llvm utilities
  MLIRTranslateLib       # TranslateFromMLIRRegistration
  MLIRArithDialect       # we pattern-match on arith.addf, arith.constant, …
  MLIRMemRefDialect      # we pattern-match on memref.load / memref.store
  MLIRFuncDialect        # needed by the dialect registry callback
)

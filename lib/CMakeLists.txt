# =============================================================================
# lib/CMakeLists.txt — InitAll convenience library
# =============================================================================
#
# WHAT THIS BUILDS
#   libEnigmaInitAll.a — a thin library that wraps every registration
#   function in enigma/InitAll.h. Tools link this single library instead
#   of having to depend on each dialect / translation library separately.
#
# WHY NOT JUST PUT InitAll.cpp IN lib/Dialect/Enigma/IR/
#   Because InitAll depends on BOTH the dialect library AND the
#   translation library. If it lived in the dialect library, the dialect
#   would transitively need to link the translation library, which is a
#   layering violation: translation depends on dialect, never the other
#   way around. Giving InitAll its own thin library lets it depend on
#   both without polluting either.
#
# Note that this CMakeLists builds a sibling to the other lib/* trees
# (lib/Dialect/, lib/Target/). Those subdirectories are added directly
# from the root CMakeLists, so we do NOT recurse into them here.
# =============================================================================

add_mlir_library(EnigmaInitAll
  InitAll.cpp

  LINK_LIBS PUBLIC
  EnigmaDialect
  EnigmaTargetMSL
  MLIRIR
  MLIRSCFDialect
  MLIRSupport
)

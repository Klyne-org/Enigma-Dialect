# =============================================================================
# lib/Target/MSL/CMakeLists.txt — the MSL emitter library (modularized)
# =============================================================================

add_mlir_translation_library(EnigmaTargetMSL
  MSLEmitterCore.cpp
  MSLEmitterThread.cpp
  MSLEmitterSync.cpp
  MSLEmitterSimd.cpp
  MSLEmitterAtomic.cpp
  MSLEmitterMath.cpp
  MSLEmitterInt.cpp
  MSLEmitterGeom.cpp
  MSLEmitterTexture.cpp
  MSLEmitterCast.cpp
  MSLEmitterUpstream.cpp
  MSLEmitterRelational.cpp
  MSLEmitterQuad.cpp
  MSLEmitterControlFlow.cpp
  MSLEmitterPack.cpp
  MSLEmitterMatrix.cpp

  DEPENDS
  EnigmaDialectIncGen

  LINK_LIBS PUBLIC
  EnigmaDialect
  MLIRIR
  MLIRSupport
  MLIRTranslateLib
  MLIRArithDialect
  MLIRMemRefDialect
  MLIRFuncDialect
  MLIRSCFDialect
)

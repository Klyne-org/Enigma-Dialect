add_mlir_library(MetalDialect
  MetalDialect.cpp
  TranslateToMSL.cpp

  DEPENDS
  MetalDialectIncGen
)

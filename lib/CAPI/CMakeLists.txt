add_mlir_public_c_api_library(MLIREnigmaCAPI
  Dialects.cpp

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRCAPIIR
  EnigmaDialect
)

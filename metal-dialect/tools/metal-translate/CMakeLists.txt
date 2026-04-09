get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)

add_llvm_executable(metal-translate metal-translate.cpp)
target_link_libraries(metal-translate PRIVATE
  ${dialect_libs}
  MetalDialect
  MLIRTranslateLib
  MLIRParser
  MLIRArithDialect
  MLIRMemRefDialect
)

mlir_check_all_link_libraries(metal-translate)

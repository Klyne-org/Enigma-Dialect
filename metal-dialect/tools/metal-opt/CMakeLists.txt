get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)

add_llvm_executable(metal-opt metal-opt.cpp)
target_link_libraries(metal-opt PRIVATE
  ${dialect_libs}
  MetalDialect
  MLIROptLib
  MLIRParser
)

mlir_check_all_link_libraries(metal-opt)

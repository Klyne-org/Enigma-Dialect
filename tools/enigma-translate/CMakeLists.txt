# =============================================================================
# tools/enigma-translate/CMakeLists.txt — the enigma-translate executable
# =============================================================================
#
# enigma-translate needs:
#   - InitAll                  → the translation registration function
#   - EnigmaTargetMSL          → the actual MSL emitter (pulled in by InitAll,
#                                but listed explicitly for clarity)
#   - MLIRTranslateLib         → mlirTranslateMain()
#   - MLIRParser               → parse .mlir input files
#   - every dialect library    → otherwise parsing fails for anything but
#                                ops from the dialects we mention by name
# =============================================================================

get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)
get_property(translation_libs GLOBAL PROPERTY MLIR_TRANSLATION_LIBS)

add_llvm_executable(enigma-translate enigma-translate.cpp)

if(TARGET MLIR)
  target_link_libraries(enigma-translate PRIVATE
    EnigmaInitAll
    EnigmaTargetMSL
    MLIR
    MLIRParser
    MLIRTranslateLib
  )
else()
  target_link_libraries(enigma-translate PRIVATE
    EnigmaInitAll
    EnigmaTargetMSL
    ${dialect_libs}
    ${translation_libs}
    MLIRParser
    MLIRTranslateLib
  )
endif()

mlir_check_all_link_libraries(enigma-translate)

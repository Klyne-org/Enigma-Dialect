include(AddMLIRPython)

set(ENIGMA_PYTHON_ROOT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/python_packages/mlir_enigma")

declare_mlir_python_sources(EnigmaPythonSources)

declare_mlir_python_sources(EnigmaPythonSources.Dialects
  ADD_TO_PARENT EnigmaPythonSources)

declare_mlir_dialect_python_bindings(
  ADD_TO_PARENT EnigmaPythonSources.Dialects
  ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/mlir_enigma"
  TD_FILE dialects/EnigmaOps.td
  SOURCES
    dialects/enigma.py
  DIALECT_NAME enigma
)

declare_mlir_python_extension(EnigmaPythonSources.Extension
  MODULE_NAME _mlirDialectsEnigma
  ADD_TO_PARENT EnigmaPythonSources
  SOURCES
    EnigmaModule.cpp
  EMBED_CAPI_LINK_LIBS
    MLIREnigmaCAPI
    MLIRCAPITransforms
)

set(_source_components
  MLIRPythonSources.Core
  MLIRPythonSources.Dialects.builtin
  MLIRPythonSources.Dialects.func
  MLIRPythonSources.Dialects.memref
  MLIRPythonSources.Dialects.arith
  MLIRPythonExtension.Core
  EnigmaPythonSources
)

set(ENIGMA_PYTHON_INSTALL_PREFIX "mlir" CACHE STRING
  "Install-relative directory for the MLIR Python package (top-level import name).")

add_mlir_python_common_capi_library(EnigmaPythonCAPI
  INSTALL_COMPONENT EnigmaPythonModules
  INSTALL_DESTINATION "${ENIGMA_PYTHON_INSTALL_PREFIX}/_mlir_libs"
  OUTPUT_DIRECTORY "${ENIGMA_PYTHON_ROOT_PREFIX}/_mlir_libs"
  RELATIVE_INSTALL_ROOT "../../../.."
  DECLARED_SOURCES ${_source_components}
)

add_mlir_python_modules(EnigmaPythonModules
  ROOT_PREFIX "${ENIGMA_PYTHON_ROOT_PREFIX}"
  INSTALL_PREFIX "${ENIGMA_PYTHON_INSTALL_PREFIX}"
  DECLARED_SOURCES ${_source_components}
  COMMON_CAPI_LINK_LIBS
    EnigmaPythonCAPI
  MLIR_BINDINGS_PYTHON_NB_DOMAIN enigma
)

# Bundle the LLVM shared library + its zstd dep next to the extension modules
# so the installed wheel is self-contained. Paths are resolved at configure time.
find_library(ENIGMA_LIBLLVM NAMES LLVM libLLVM PATHS "${LLVM_LIBRARY_DIR}" NO_DEFAULT_PATH)
if(ENIGMA_LIBLLVM)
  install(FILES "${ENIGMA_LIBLLVM}"
    DESTINATION "${ENIGMA_PYTHON_INSTALL_PREFIX}/_mlir_libs"
    COMPONENT EnigmaPythonModules)
endif()

# zstd is a transitive dep of libLLVM.dylib on macOS (homebrew path).
# Resolve symlinks so we bundle the actual file, then rename on install.
foreach(_zstd_candidate
    "/opt/homebrew/opt/zstd/lib/libzstd.1.dylib"
    "/usr/local/opt/zstd/lib/libzstd.1.dylib")
  if(EXISTS "${_zstd_candidate}")
    get_filename_component(_zstd_real "${_zstd_candidate}" REALPATH)
    install(FILES "${_zstd_real}"
      DESTINATION "${ENIGMA_PYTHON_INSTALL_PREFIX}/_mlir_libs"
      RENAME "libzstd.1.dylib"
      COMPONENT EnigmaPythonModules)
    break()
  endif()
endforeach()

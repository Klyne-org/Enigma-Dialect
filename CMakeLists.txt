# =============================================================================
# Enigma Dialect — Root CMakeLists.txt
# =============================================================================
#
# WHAT THIS FILE DOES
#   This is the *only* CMakeLists.txt that users invoke directly (via
#   `cmake -S . -B build`). It is responsible for:
#
#     1. Finding a prebuilt MLIR/LLVM on the system (we do NOT rebuild MLIR —
#        that takes an hour. We depend on one the user already built).
#     2. Setting up the MLIR-provided CMake machinery (TableGen, AddMLIR, …).
#     3. Adding the subdirectories that actually build things.
#
#   The root CMake's job is wiring, not building. Every subdirectory owns its
#   own libraries/targets. This is the MLIR out-of-tree convention — see
#   llvm-project/mlir/examples/standalone for the canonical pattern.
#
# HOW TO BUILD
#   You need a prebuilt MLIR. The easiest way on macOS is:
#
#     brew install llvm                 # ships with MLIR
#     export MLIR_DIR=$(brew --prefix llvm)/lib/cmake/mlir
#     export LLVM_DIR=$(brew --prefix llvm)/lib/cmake/llvm
#
#   Or build LLVM/MLIR from source and point MLIR_DIR at
#   <build>/lib/cmake/mlir. Then from this directory:
#
#     cmake -S . -B build -G Ninja
#     ninja -C build
#     ninja -C build check-enigma       # runs the lit test suite
#
# HOW TO EXTEND
#   When you add a new top-level component (e.g. a new pass library, a Python
#   binding, a benchmark suite), add a line at the bottom of this file:
#
#     add_subdirectory(lib/Dialect/Enigma/Transforms)   # new passes
#     add_subdirectory(python)                          # Python bindings
#     add_subdirectory(benchmark)                       # microbenchmarks
#
#   Each subdirectory owns its own CMakeLists.txt. Never reach up into a
#   parent directory's CMake from a child.
# =============================================================================

cmake_minimum_required(VERSION 3.20)
project(enigma-dialect LANGUAGES C CXX)

# -----------------------------------------------------------------------------
# C++ standard. MLIR requires C++17 minimum; some recent MLIR versions want
# C++20. If you get build errors about `std::span` or similar, bump to 20.
# -----------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Emit compile_commands.json so clangd / VSCode can provide good completions.
# This single line is the single biggest quality-of-life improvement you can
# make to an MLIR project.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# -----------------------------------------------------------------------------
# Options — toggles users can flip at configure time
# -----------------------------------------------------------------------------
#
#   cmake -S . -B build -DENIGMA_ENABLE_METAL_RUNTIME=ON
#
# We gate the Metal-specific runtime (Objective-C++, Metal.framework) behind
# an option so that Linux contributors can still build and test the pure-IR
# parts of the project without a mac.
option(ENIGMA_ENABLE_METAL_RUNTIME
  "Build the Metal host runtime and enigma-runner (requires macOS + Metal.framework)"
  ${APPLE})

# -----------------------------------------------------------------------------
# Find MLIR and LLVM.
# -----------------------------------------------------------------------------
# `find_package(MLIR REQUIRED CONFIG)` looks for MLIRConfig.cmake. The user
# must have MLIR_DIR pointing at its directory. We print it so build logs
# show exactly which MLIR is being used — critical when debugging "works on
# my machine" bugs.
find_package(MLIR REQUIRED CONFIG)
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Using MLIR in: ${MLIR_DIR}")
message(STATUS "Using LLVM in: ${LLVM_DIR}")
message(STATUS "MLIR version:  ${MLIR_PACKAGE_VERSION}")

# MLIR ships CMake helper modules (AddMLIR.cmake, TableGen.cmake). Add them
# to the module path before include()ing them.
list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

include(TableGen)       # provides `tablegen()` + `add_public_tablegen_target()`
include(AddLLVM)        # provides `add_llvm_executable()` etc.
include(AddMLIR)        # provides `add_mlir_dialect_library()` etc.
include(HandleLLVMOptions)

# -----------------------------------------------------------------------------
# Global include directories.
# -----------------------------------------------------------------------------
# We need headers from three places:
#   1. MLIR + LLVM install              (${MLIR_INCLUDE_DIRS}, ${LLVM_INCLUDE_DIRS})
#   2. Our own source tree              (${CMAKE_CURRENT_SOURCE_DIR}/include)
#   3. Generated tablegen output        (${CMAKE_CURRENT_BINARY_DIR}/include)
#
# The third one is easy to miss: mlir_tablegen writes headers like
# `EnigmaOps.h.inc` into the *binary* directory, not the source tree. The
# source `#include "enigma/Dialect/Enigma/IR/EnigmaOps.h.inc"` needs both
# roots on the include path for the resolver to find them.
include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${MLIR_INCLUDE_DIRS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)

# -----------------------------------------------------------------------------
# Subdirectories.
# -----------------------------------------------------------------------------
# Order matters: tablegen (include/) must be added BEFORE libraries that
# depend on the generated headers (lib/).
add_subdirectory(include/enigma/Dialect/Enigma/IR)   # tablegen-only
add_subdirectory(lib/Dialect/Enigma/IR)              # dialect C++ library
add_subdirectory(lib/Target/MSL)                     # MSL emitter library
add_subdirectory(lib)                                # InitAll convenience lib
add_subdirectory(tools/enigma-opt)                   # enigma-opt binary
add_subdirectory(tools/enigma-translate)             # enigma-translate binary

# Metal runtime + enigma-runner are gated — only built on mac with Metal.
if(ENIGMA_ENABLE_METAL_RUNTIME)
  add_subdirectory(tools/enigma-runner)
endif()

# Tests are always configured so `ninja check-enigma` works on every platform.
add_subdirectory(test)

# -----------------------------------------------------------------------------
# Developer hint on configure success
# -----------------------------------------------------------------------------
message(STATUS "")
message(STATUS "Enigma configured. Next:")
message(STATUS "  ninja -C ${CMAKE_BINARY_DIR}")
message(STATUS "  ninja -C ${CMAKE_BINARY_DIR} check-enigma")
message(STATUS "")

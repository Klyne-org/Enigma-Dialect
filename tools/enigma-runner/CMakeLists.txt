# =============================================================================
# tools/enigma-runner/CMakeLists.txt — macOS-only host runner
# =============================================================================
#
# This file is only ever add_subdirectory'd when ENIGMA_ENABLE_METAL_RUNTIME
# is ON (see the gate in the root CMakeLists.txt). So we can assume APPLE
# here and link against Metal.framework unconditionally.
#
# The compile flag `-fobjc-arc` enables Automatic Reference Counting, which
# is how the `@autoreleasepool` block and all those `id<...>` smart-
# pointer-ish patterns in enigma-runner.mm work without leaks.
# =============================================================================

add_executable(enigma-runner enigma-runner.mm)

# Objective-C++ compile settings. Without ARC the .mm code leaks every
# Metal object it creates.
set_target_properties(enigma-runner PROPERTIES
  COMPILE_FLAGS "-fobjc-arc"
)

# Link against the Apple frameworks we need. `find_library` produces
# absolute paths to each framework's directory; that's the idiomatic way
# to link frameworks from CMake on macOS.
find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

target_link_libraries(enigma-runner PRIVATE
  ${METAL_FRAMEWORK}
  ${FOUNDATION_FRAMEWORK}
)

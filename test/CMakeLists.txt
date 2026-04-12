# =============================================================================
# test/CMakeLists.txt — lit test suite configuration
# =============================================================================
#
# WHAT THIS DOES
#   Sets up the `check-enigma` build target that runs every .mlir file
#   under this directory through `llvm-lit`. Each .mlir has special
#   `// RUN:` and `// CHECK:` comments that lit / FileCheck interpret as
#   a test spec.
#
# WHY LIT
#   lit + FileCheck is the canonical MLIR regression-testing setup. It
#   gives you:
#     - Textual, diffable expected output
#     - Fast, parallel execution
#     - Trivial to add a new test: drop a .mlir in the right folder
#     - Clean integration with `ninja` (`ninja check-enigma`)
#
# HOW TO RUN
#   ninja -C build check-enigma
#   # or for verbose output
#   ninja -C build check-enigma -v
#   # or to run a single test manually
#   llvm-lit -v build/test/Target/MSL/vector_add.mlir
#
# HOW TO EXTEND
#   To add a new test category: make a new subdir under test/ (e.g.
#   test/Dialect/Enigma/ for round-trip tests) and drop .mlir files in.
#   Lit picks them up automatically via lit.cfg.py's file discovery.
# =============================================================================

# Configure the lit site config by substituting CMake variables into the
# .in template. The resulting lit.site.cfg.py is what lit actually reads
# when invoked; it in turn imports the source-tree lit.cfg.py.
configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
  MAIN_CONFIG
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
)

# List of targets that must be built before `check-enigma` runs.
# Without this, you could accidentally run tests against a stale
# enigma-translate or enigma-opt.
set(ENIGMA_TEST_DEPENDS
  FileCheck
  count
  not
  enigma-opt
  enigma-translate
)

add_lit_testsuite(check-enigma "Running the Enigma regression tests"
  ${CMAKE_CURRENT_BINARY_DIR}
  DEPENDS ${ENIGMA_TEST_DEPENDS}
)

set_target_properties(check-enigma PROPERTIES FOLDER "Tests")

add_lit_testsuites(ENIGMA ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS ${ENIGMA_TEST_DEPENDS}
)

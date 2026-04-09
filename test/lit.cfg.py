# =============================================================================
# test/lit.cfg.py — Lit test discovery + substitution config
# =============================================================================
#
# WHAT THIS FILE DOES
#   This is the lit config. It tells llvm-lit:
#     - What file extensions are tests (`.mlir`)
#     - Where the test sources live
#     - Where the test binaries (enigma-opt, enigma-translate) live
#     - What `%enigma-opt` and friends mean inside `// RUN:` lines
#
#   `llvm-lit` is the script runner — you don't invoke it directly in
#   daily development, you run `ninja check-enigma`. But under the hood,
#   ninja invokes lit, and lit reads THIS file to know what to do.
#
# THE CRITICAL LINE IS `substitutions`
#   When a .mlir file says `// RUN: enigma-translate --enigma-to-msl %s`,
#   lit rewrites `enigma-translate` to the absolute path of the built
#   binary before running the command. That substitution list below is
#   where that mapping lives.
#
# HOW TO EXTEND
#   When you add a new tool (e.g. enigma-runner in lit integration tests),
#   append to `tool_dirs` and `tools` below.
# =============================================================================

import os
import lit.formats
import lit.util

from lit.llvm import llvm_config
from lit.llvm.subst import ToolSubst
from lit.llvm.subst import FindTool

# -----------------------------------------------------------------------------
# Core config
# -----------------------------------------------------------------------------
config.name = "Enigma"
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)

# Which file extensions lit should consider tests. Everything else in
# the test tree is ignored (READMEs, support files, fixtures, etc.).
config.suffixes = [".mlir"]

# The source-tree and build-tree roots for the test suite. These are
# filled in by the substitution in lit.site.cfg.py.in.
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.enigma_obj_root, "test")

# -----------------------------------------------------------------------------
# Environment + path setup
# -----------------------------------------------------------------------------
# Teach llvm_config where the MLIR tools live so built-ins like
# `FileCheck`, `not`, and `count` can be found automatically.
llvm_config.with_system_environment(["HOME", "USER", "PATH", "TERM"])
llvm_config.use_default_substitutions()

# Exclude directories that shouldn't be walked for test files.
config.excludes = ["CMakeLists.txt", "lit.cfg.py", "lit.site.cfg.py"]

# -----------------------------------------------------------------------------
# Tool substitutions
# -----------------------------------------------------------------------------
# This is where `enigma-opt` and `enigma-translate` in .mlir RUN lines
# get turned into paths to the binaries we just built.
tool_dirs = [
    config.enigma_tools_dir,
    config.llvm_tools_dir,
]

tools = [
    "enigma-opt",
    "enigma-translate",
    "mlir-opt",         # available for cross-checks against upstream
    "mlir-translate",
]

llvm_config.add_tool_substitutions(tools, tool_dirs)

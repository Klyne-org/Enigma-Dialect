#!/usr/bin/env python3
"""Generate PDF documentation for the Metal MLIR Dialect project."""

from fpdf import FPDF

class DocPDF(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(120, 120, 120)
            self.cell(0, 10, "Metal MLIR Dialect - Technical Documentation", align="C")
            self.ln(5)
            self.set_draw_color(200, 200, 200)
            self.line(10, self.get_y(), 200, self.get_y())
            self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def title_page(self):
        self.add_page()
        self.ln(60)
        self.set_font("Helvetica", "B", 32)
        self.set_text_color(30, 30, 30)
        self.cell(0, 15, "Metal MLIR Dialect", align="C")
        self.ln(20)
        self.set_font("Helvetica", "", 16)
        self.set_text_color(80, 80, 80)
        self.cell(0, 10, "Technical Documentation", align="C")
        self.ln(12)
        self.set_font("Helvetica", "I", 12)
        self.cell(0, 10, "A Custom MLIR Dialect for Apple Silicon GPU Compute", align="C")
        self.ln(30)
        self.set_draw_color(60, 60, 60)
        self.line(60, self.get_y(), 150, self.get_y())
        self.ln(15)
        self.set_font("Helvetica", "", 11)
        self.set_text_color(100, 100, 100)
        self.cell(0, 8, "Pipeline: MLIR -> Metal Shading Language -> GPU Binary -> Apple Silicon", align="C")
        self.ln(8)
        self.cell(0, 8, "Target: Apple M-series GPUs via Metal API", align="C")
        self.ln(8)
        self.cell(0, 8, "Built against: LLVM/MLIR 22.1.2 (Homebrew)", align="C")

    def section_title(self, title):
        self.set_font("Helvetica", "B", 18)
        self.set_text_color(20, 60, 120)
        self.ln(6)
        self.cell(0, 12, title)
        self.ln(4)
        self.set_draw_color(20, 60, 120)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(8)

    def subsection_title(self, title):
        self.set_font("Helvetica", "B", 13)
        self.set_text_color(40, 40, 40)
        self.ln(3)
        self.cell(0, 10, title)
        self.ln(8)

    def body_text(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def code_block(self, code, title=None):
        if title:
            self.set_font("Helvetica", "BI", 9)
            self.set_text_color(80, 80, 80)
            self.cell(0, 6, title)
            self.ln(5)
        self.set_fill_color(240, 240, 245)
        self.set_draw_color(200, 200, 210)
        x = self.get_x()
        y = self.get_y()
        self.set_font("Courier", "", 8.5)
        self.set_text_color(30, 30, 30)
        lines = code.strip().split("\n")
        block_height = len(lines) * 4.5 + 6
        if y + block_height > 270:
            self.add_page()
            y = self.get_y()
        self.rect(10, y, 190, block_height, style="DF")
        self.set_xy(13, y + 3)
        for line in lines:
            safe = line.replace("\t", "    ")
            self.cell(0, 4.5, safe)
            self.ln(4.5)
        self.ln(4)

    def bullet(self, text, bold_prefix=None):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(30, 30, 30)
        x = self.get_x()
        self.cell(5, 5.5, "-")
        if bold_prefix:
            self.set_font("Helvetica", "B", 10)
            self.write(5.5, bold_prefix + " ")
            self.set_font("Helvetica", "", 10)
            self.write(5.5, text)
        else:
            self.write(5.5, text)
        self.ln(7)

    def table_row(self, cols, widths, bold=False, header=False):
        if header:
            self.set_font("Helvetica", "B", 9)
            self.set_fill_color(20, 60, 120)
            self.set_text_color(255, 255, 255)
        elif bold:
            self.set_font("Helvetica", "B", 9)
            self.set_fill_color(248, 248, 252)
            self.set_text_color(30, 30, 30)
        else:
            self.set_font("Helvetica", "", 9)
            self.set_fill_color(255, 255, 255)
            self.set_text_color(30, 30, 30)
        for i, (col, w) in enumerate(zip(cols, widths)):
            self.cell(w, 7, col, border=1, fill=True)
        self.ln()


def build_pdf():
    pdf = DocPDF()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)

    # =========================================================================
    # TITLE PAGE
    # =========================================================================
    pdf.title_page()

    # =========================================================================
    # TABLE OF CONTENTS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("Table of Contents")
    toc = [
        "1. Project Overview",
        "2. Architecture & Pipeline",
        "3. Directory Structure",
        "4. Build System (CMakeLists.txt)",
        "5. Dialect Definition (TableGen)",
        "    5.1 MetalDialect.td - Dialect Registration",
        "    5.2 MetalOps.td - Operation Definitions",
        "6. C++ Implementation",
        "    6.1 MetalDialect.h - Header",
        "    6.2 MetalDialect.cpp - Dialect & KernelOp Parser/Printer",
        "7. MSL Translation (TranslateToMSL.cpp)",
        "8. Tools",
        "    8.1 metal-opt - IR Optimizer/Validator",
        "    8.2 metal-translate - MSL Code Generator",
        "9. GPU Runtime (runner.mm)",
        "10. Test Kernel (vector_add.mlir)",
        "11. End-to-End Pipeline Walkthrough",
        "12. How to Extend",
    ]
    for item in toc:
        indent = item.startswith("    ")
        pdf.set_font("Helvetica", "" if indent else "B", 10 if indent else 11)
        pdf.set_text_color(30, 30, 30)
        label = item.strip()
        pdf.cell(0, 7, ("    " if indent else "") + label)
        pdf.ln(7)

    # =========================================================================
    # 1. PROJECT OVERVIEW
    # =========================================================================
    pdf.add_page()
    pdf.section_title("1. Project Overview")
    pdf.body_text(
        "This project implements a custom MLIR dialect called 'metal' that targets Apple Silicon GPUs "
        "via Apple's Metal API. It provides an end-to-end compilation pipeline that takes GPU compute "
        "kernels written in MLIR, translates them to Metal Shading Language (MSL), compiles to GPU "
        "binary, and executes on the Apple GPU."
    )
    pdf.body_text(
        "The key insight is that Apple's GPU ISA is not public - unlike NVIDIA's PTX or AMD's ISA. "
        "So instead of emitting raw GPU instructions, we emit MSL source code and let Apple's "
        "proprietary compiler (xcrun metal) handle the final compilation to GPU binary."
    )
    pdf.subsection_title("Why This Exists")
    pdf.body_text(
        "MLIR has mature GPU backends for NVIDIA (nvvm/nvgpu -> PTX), AMD (rocdl/amdgpu -> AMDGCN), "
        "and Intel (gpu -> SPIR-V). Apple Metal has NO official MLIR dialect. This project fills that gap "
        "by providing a Metal dialect that maps Metal GPU concepts into MLIR's type system and "
        "operation framework."
    )
    pdf.subsection_title("What It Does")
    pdf.bullet("Defines Metal-specific MLIR operations (kernel, thread_position_in_grid, barrier, etc.)")
    pdf.bullet("Parses and validates Metal MLIR programs via 'metal-opt'")
    pdf.bullet("Translates Metal MLIR to valid MSL source code via 'metal-translate'")
    pdf.bullet("Compiles MSL to GPU binary (.metallib) using Apple's toolchain")
    pdf.bullet("Executes GPU compute on Apple Silicon and verifies results")

    # =========================================================================
    # 2. ARCHITECTURE
    # =========================================================================
    pdf.add_page()
    pdf.section_title("2. Architecture & Pipeline")
    pdf.body_text("The compilation pipeline has 5 stages:")
    pdf.ln(3)
    pdf.code_block(
        "Stage 1: MLIR (Metal dialect)\n"
        "  |  metal.kernel, metal.thread_position_in_grid, memref.load/store, arith ops\n"
        "  |  [metal-opt validates]\n"
        "  v\n"
        "Stage 2: Metal Shading Language (.metal)\n"
        "  |  Valid MSL source code with kernel void, [[buffer(N)]], etc.\n"
        "  |  [metal-translate --mlir-to-msl]\n"
        "  v\n"
        "Stage 3: Apple Intermediate Representation (.air)\n"
        "  |  Apple's proprietary IR format\n"
        "  |  [xcrun -sdk macosx metal -c]\n"
        "  v\n"
        "Stage 4: GPU Binary (.metallib)\n"
        "  |  Loadable GPU binary\n"
        "  |  [xcrun -sdk macosx metallib]\n"
        "  v\n"
        "Stage 5: Execution on Apple GPU\n"
        "     Metal API loads .metallib, dispatches compute, reads results\n"
        "     [runtime/runner.mm]",
        "End-to-End Pipeline"
    )
    pdf.body_text(
        "Stages 1-2 are what this project implements. Stages 3-4 use Apple's standard toolchain. "
        "Stage 5 uses Apple's Metal API via Objective-C++."
    )

    pdf.subsection_title("Metal Concept Mapping")
    widths = [55, 65, 70]
    pdf.table_row(["Metal Concept", "MLIR Op", "MSL Output"], widths, header=True)
    rows = [
        ["kernel void", "metal.kernel @name(...)", "kernel void name(...)"],
        ["thread_position_in_grid", "metal.thread_position_in_grid x", "_tid.x"],
        ["threadgroup_barrier", "metal.threadgroup_barrier 3", "threadgroup_barrier(...)"],
        ["device float* [[buffer]]", "memref<?xf32> argument", "device float* v [[buffer(N)]]"],
        ["return (void)", "metal.return", "(implicit)"],
        ["a + b", "arith.addf %a, %b : f32", "float v = v0 + v1;"],
        ["buf[id]", "memref.load %buf[%id]", "v0[v1]"],
    ]
    for row in rows:
        pdf.table_row(row, widths)

    # =========================================================================
    # 3. DIRECTORY STRUCTURE
    # =========================================================================
    pdf.add_page()
    pdf.section_title("3. Directory Structure")
    pdf.code_block(
        "metal-dialect/\n"
        "|-- CMakeLists.txt                     # Top-level build config\n"
        "|-- include/\n"
        "|   +-- MetalDialect/\n"
        "|       |-- CMakeLists.txt             # TableGen targets\n"
        "|       |-- MetalDialect.td            # Dialect registration\n"
        "|       |-- MetalOps.td                # Operation definitions\n"
        "|       +-- MetalDialect.h             # C++ header\n"
        "|-- lib/\n"
        "|   +-- MetalDialect/\n"
        "|       |-- CMakeLists.txt             # Library build\n"
        "|       |-- MetalDialect.cpp           # Dialect + KernelOp parser/printer\n"
        "|       +-- TranslateToMSL.cpp         # MSL code emitter\n"
        "|-- tools/\n"
        "|   |-- metal-opt/\n"
        "|   |   |-- CMakeLists.txt             # Tool build\n"
        "|   |   +-- metal-opt.cpp              # MLIR optimizer/validator\n"
        "|   +-- metal-translate/\n"
        "|       |-- CMakeLists.txt             # Tool build\n"
        "|       +-- metal-translate.cpp        # MLIR-to-MSL translator\n"
        "|-- runtime/\n"
        "|   |-- runner.mm                      # Obj-C++ GPU host program\n"
        "|   |-- kernel.metal                   # Generated MSL source\n"
        "|   |-- kernel.air                     # Compiled AIR\n"
        "|   +-- kernel.metallib                # GPU binary\n"
        "|-- test/\n"
        "|   +-- vector_add.mlir                # Test kernel\n"
        "+-- build/                             # CMake build output",
        "Project Layout"
    )

    pdf.subsection_title("What Each Layer Does")
    pdf.bullet("include/ - Declarative definitions. TableGen (.td) files declare what ops exist, their arguments, results, and traits. The C++ header pulls in auto-generated code.", bold_prefix="include/")
    pdf.bullet("lib/ - Imperative implementation. The dialect initialization, custom parser/printer for KernelOp, and the MSL emitter that walks IR and outputs text.", bold_prefix="lib/")
    pdf.bullet("tools/ - Executables. metal-opt validates IR, metal-translate converts IR to MSL.", bold_prefix="tools/")
    pdf.bullet("runtime/ - GPU execution. Objective-C++ program that loads .metallib and dispatches compute work to the GPU.", bold_prefix="runtime/")
    pdf.bullet("test/ - MLIR input files for testing the pipeline.", bold_prefix="test/")

    # =========================================================================
    # 4. BUILD SYSTEM
    # =========================================================================
    pdf.add_page()
    pdf.section_title("4. Build System (CMakeLists.txt)")
    pdf.body_text(
        "The project uses CMake with Ninja and links against Homebrew's pre-built LLVM/MLIR. "
        "This is an 'out-of-tree' build - the dialect lives outside the LLVM source tree."
    )
    pdf.code_block(
        'cmake_minimum_required(VERSION 3.20)\n'
        'project(metal-dialect LANGUAGES C CXX)\n'
        'set(CMAKE_CXX_STANDARD 17)\n'
        '\n'
        'find_package(MLIR REQUIRED CONFIG)    # Find MLIR CMake config\n'
        'find_package(LLVM REQUIRED CONFIG)    # Find LLVM CMake config\n'
        '\n'
        '# Import MLIR/LLVM CMake helpers\n'
        'include(TableGen)                     # For mlir_tablegen()\n'
        'include(AddLLVM)                      # For add_llvm_executable()\n'
        'include(AddMLIR)                      # For add_mlir_library()\n'
        '\n'
        '# Include paths for LLVM headers + our headers + generated headers\n'
        'include_directories(${LLVM_INCLUDE_DIRS})\n'
        'include_directories(${MLIR_INCLUDE_DIRS})\n'
        'include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)\n'
        'include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)',
        "Top-level CMakeLists.txt (annotated)"
    )

    pdf.subsection_title("How to Build")
    pdf.code_block(
        'cd metal-dialect\n'
        '\n'
        '# Configure (point to Homebrew LLVM)\n'
        'cmake -S . -B build -G Ninja \\\n'
        '  -DMLIR_DIR="$(brew --prefix llvm)/lib/cmake/mlir" \\\n'
        '  -DLLVM_DIR="$(brew --prefix llvm)/lib/cmake/llvm"\n'
        '\n'
        '# Build\n'
        'cmake --build build',
        "Build Commands"
    )
    pdf.body_text(
        "The build produces two executables: build/tools/metal-opt/metal-opt and "
        "build/tools/metal-translate/metal-translate."
    )

    pdf.subsection_title("TableGen CMakeLists (include/MetalDialect/CMakeLists.txt)")
    pdf.body_text(
        "This file runs mlir-tblgen to auto-generate C++ code from .td files:"
    )
    pdf.code_block(
        'set(LLVM_TARGET_DEFINITIONS MetalOps.td)\n'
        'mlir_tablegen(MetalOps.h.inc -gen-op-decls)       # Op class declarations\n'
        'mlir_tablegen(MetalOps.cpp.inc -gen-op-defs)      # Op class definitions\n'
        'mlir_tablegen(MetalDialect.h.inc -gen-dialect-decls) # Dialect class decl\n'
        'mlir_tablegen(MetalDialect.cpp.inc -gen-dialect-defs) # Dialect class def\n'
        'mlir_tablegen(MetalOpsEnums.h.inc -gen-enum-decls)   # Enum decls\n'
        'mlir_tablegen(MetalOpsEnums.cpp.inc -gen-enum-defs)  # Enum defs\n'
        'add_public_tablegen_target(MetalDialectIncGen)',
        "TableGen Code Generation"
    )
    pdf.body_text(
        "These .inc files contain hundreds of lines of auto-generated C++ - parser/printer "
        "boilerplate, verifier logic, accessor methods, etc. You never edit them; you edit "
        "the .td files and regenerate."
    )

    # =========================================================================
    # 5. DIALECT DEFINITION (TABLEGEN)
    # =========================================================================
    pdf.add_page()
    pdf.section_title("5. Dialect Definition (TableGen)")
    pdf.body_text(
        "TableGen is LLVM's domain-specific language for declaratively defining operations, "
        "types, and attributes. You describe WHAT your ops look like; the build system generates "
        "the C++ code that implements parsing, printing, verification, and accessors."
    )

    pdf.subsection_title("5.1 MetalDialect.td - Dialect Registration")
    pdf.code_block(
        'include "mlir/IR/OpBase.td"\n'
        'include "mlir/Interfaces/SideEffectInterfaces.td"\n'
        '\n'
        'def Metal_Dialect : Dialect {\n'
        '  let name = "metal";           // Ops will be: metal.kernel, metal.return, ...\n'
        '  let cppNamespace = "::metal"; // C++ namespace for generated code\n'
        '  let description = "Dialect for Apple Metal GPU compute";\n'
        '}',
        "MetalDialect.td"
    )
    pdf.body_text(
        'This registers "metal" as a dialect name. Every op in this dialect will be prefixed '
        'with "metal." in MLIR syntax. The cppNamespace means all generated C++ classes live '
        'in the ::metal namespace.'
    )

    pdf.subsection_title("5.2 MetalOps.td - Operation Definitions")
    pdf.body_text(
        "This file defines all the operations in the Metal dialect. Let's walk through each one."
    )

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "Dimension Enum")
    pdf.ln(8)
    pdf.code_block(
        'def Metal_DimX : I32EnumAttrCase<"x", 0>;\n'
        'def Metal_DimY : I32EnumAttrCase<"y", 1>;\n'
        'def Metal_DimZ : I32EnumAttrCase<"z", 2>;\n'
        '\n'
        'def Metal_Dimension : I32EnumAttr<"Dimension", "GPU dimension",\n'
        '    [Metal_DimX, Metal_DimY, Metal_DimZ]> {\n'
        '  let cppNamespace = "::metal";\n'
        '}'
    )
    pdf.body_text(
        "GPU threads are organized in 3D grids. This enum represents which axis (x, y, z) "
        "a thread index op refers to. Maps directly to Metal's uint3 thread position."
    )

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "KernelOp - GPU Entry Point")
    pdf.ln(8)
    pdf.code_block(
        'def Metal_KernelOp : Metal_Op<"kernel", [IsolatedFromAbove]> {\n'
        '  let summary = "Metal compute kernel function";\n'
        '  let arguments = (ins\n'
        '    StrAttr:$sym_name,                    // Kernel name (@vector_add)\n'
        '    TypeAttrOf<FunctionType>:$function_type // (memref, memref) -> ()\n'
        '  );\n'
        '  let regions = (region AnyRegion:$body);   // The kernel body\n'
        '  let hasCustomAssemblyFormat = 1;          // Custom parser/printer in C++\n'
        '}'
    )
    pdf.body_text(
        'IsolatedFromAbove means the kernel body cannot reference SSA values defined outside '
        'it - just like a real GPU kernel which runs independently. The sym_name becomes the '
        'function name in MSL. The function_type describes buffer argument types. '
        'hasCustomAssemblyFormat = 1 means we write our own parse/print methods in C++ '
        '(see MetalDialect.cpp) instead of using a declarative format string.'
    )

    pdf.add_page()
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "Thread Index Ops")
    pdf.ln(8)
    pdf.code_block(
        'def Metal_ThreadPositionInGridOp : Metal_Op<\n'
        '    "thread_position_in_grid", [Pure]> {\n'
        '  let summary = "Get thread position in grid (global thread id)";\n'
        '  let arguments = (ins Metal_Dimension:$dimension);\n'
        '  let results = (outs Index:$result);\n'
        '  let assemblyFormat = "$dimension attr-dict";\n'
        '}'
    )
    pdf.body_text(
        "This is the most important op - it gives each GPU thread its unique ID. [Pure] means "
        "it has no side effects (it just reads a hardware register). It takes a dimension (x/y/z) "
        "and returns an Index value."
    )
    pdf.body_text(
        "In Metal Shading Language, this maps to [[thread_position_in_grid]]. "
        "In CUDA terms, this is blockIdx.x * blockDim.x + threadIdx.x."
    )
    pdf.body_text(
        "The three other thread ops (threadgroup_position_in_grid, thread_position_in_threadgroup, "
        "threads_per_threadgroup) follow the same pattern and map to Metal's "
        "[[threadgroup_position_in_grid]], [[thread_position_in_threadgroup]], and "
        "[[threads_per_threadgroup]] attributes respectively."
    )

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, "Barrier and Return Ops")
    pdf.ln(8)
    pdf.code_block(
        'def Metal_ThreadgroupBarrierOp : Metal_Op<"threadgroup_barrier", []> {\n'
        '  let arguments = (ins I32Attr:$mem_flags);  // 0=none, 1=device, 2=threadgroup, 3=both\n'
        '  let assemblyFormat = "$mem_flags attr-dict";\n'
        '}\n'
        '\n'
        'def Metal_ReturnOp : Metal_Op<"return", [Terminator]> {\n'
        '  let assemblyFormat = "attr-dict";\n'
        '}'
    )
    pdf.body_text(
        "The barrier synchronizes threads within a threadgroup - all threads must reach the "
        "barrier before any can proceed. [Terminator] on ReturnOp tells MLIR this op ends a block."
    )

    # =========================================================================
    # 6. C++ IMPLEMENTATION
    # =========================================================================
    pdf.add_page()
    pdf.section_title("6. C++ Implementation")

    pdf.subsection_title("6.1 MetalDialect.h - The Header")
    pdf.code_block(
        '#pragma once\n'
        '#include "mlir/IR/Dialect.h"\n'
        '#include "mlir/IR/OpDefinition.h"\n'
        '#include "mlir/IR/Builders.h"\n'
        '#include "mlir/IR/BuiltinTypes.h"\n'
        '#include "mlir/Bytecode/BytecodeOpInterface.h"\n'
        '#include "mlir/Interfaces/SideEffectInterfaces.h"\n'
        '#include "mlir/Interfaces/InferTypeOpInterface.h"\n'
        '\n'
        '#include "MetalDialect/MetalDialect.h.inc"    // Generated dialect class\n'
        '#include "MetalDialect/MetalOpsEnums.h.inc"    // Generated Dimension enum\n'
        '\n'
        '#define GET_OP_CLASSES\n'
        '#include "MetalDialect/MetalOps.h.inc"         // Generated op classes',
        "MetalDialect.h"
    )
    pdf.body_text(
        "This header does very little manually - it just includes the auto-generated .h.inc files "
        "that TableGen produced. The #define GET_OP_CLASSES before MetalOps.h.inc tells the "
        "generated code to emit actual class definitions (KernelOp, ThreadPositionInGridOp, etc.)."
    )

    pdf.subsection_title("6.2 MetalDialect.cpp - Dialect Initialization + KernelOp Parser")
    pdf.body_text(
        "This file has two responsibilities: initializing the dialect (registering all ops) "
        "and providing the custom parse/print methods for KernelOp."
    )
    pdf.code_block(
        'void metal::MetalDialect::initialize() {\n'
        '  addOperations<\n'
        '#define GET_OP_LIST\n'
        '#include "MetalDialect/MetalOps.cpp.inc"   // Expands to: KernelOp, ThreadPosi...\n'
        '  >();\n'
        '}',
        "Dialect Initialization"
    )
    pdf.body_text(
        "GET_OP_LIST expands to a comma-separated list of all op classes. addOperations() "
        "registers them with the MLIR context so the parser recognizes metal.* ops."
    )

    pdf.code_block(
        '// How MLIR text like this gets parsed:\n'
        '//   metal.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>) {\n'
        '//     ...\n'
        '//   }\n'
        '\n'
        'ParseResult metal::KernelOp::parse(OpAsmParser &parser, OperationState &result) {\n'
        '  // 1. Parse kernel name: @vector_add\n'
        '  StringAttr nameAttr;\n'
        '  parser.parseSymbolName(nameAttr, "sym_name", result.attributes);\n'
        '\n'
        '  // 2. Parse arguments: (%a: memref<?xf32>, %b: memref<?xf32>)\n'
        '  SmallVector<OpAsmParser::Argument> args;\n'
        '  SmallVector<Type> argTypes;\n'
        '  parser.parseLParen();\n'
        '  do {\n'
        '    // Parse each: %name : type\n'
        '    OpAsmParser::Argument arg;\n'
        '    Type argType;\n'
        '    parser.parseArgument(arg);\n'
        '    parser.parseColon();\n'
        '    parser.parseType(argType);\n'
        '    arg.type = argType;\n'
        '    args.push_back(arg);\n'
        '  } while (succeeded(parser.parseOptionalComma()));\n'
        '  parser.parseRParen();\n'
        '\n'
        '  // 3. Build function type and parse body region\n'
        '  auto funcType = FunctionType::get(parser.getContext(), argTypes, {});\n'
        '  result.addAttribute("function_type", TypeAttr::get(funcType));\n'
        '  auto *body = result.addRegion();\n'
        '  parser.parseRegion(*body, args);\n'
        '}',
        "KernelOp Parser (simplified)"
    )

    # =========================================================================
    # 7. MSL TRANSLATION
    # =========================================================================
    pdf.add_page()
    pdf.section_title("7. MSL Translation (TranslateToMSL.cpp)")
    pdf.body_text(
        "This is the core of the code generation. The MSLEmitter class walks the MLIR IR tree "
        "and outputs valid Metal Shading Language source code. It's registered as a translation "
        "pass that can be invoked with --mlir-to-msl."
    )

    pdf.subsection_title("How It Works")
    pdf.body_text(
        "The emitter uses a simple pattern: visit each MLIR operation, check its type via "
        "dyn_cast<>, and emit the corresponding MSL text. SSA values (%0, %1, ...) are mapped "
        "to C variable names (v0, v1, ...) via a DenseMap."
    )
    pdf.code_block(
        'class MSLEmitter {\n'
        '  raw_ostream &os;                         // Output stream\n'
        '  DenseMap<Value, std::string> valueNames;  // %0 -> "v0", %1 -> "v1"\n'
        '  int nextVar = 0;                          // Counter for variable names\n'
        '\n'
        '  StringRef getName(Value v) {\n'
        '    // Lazily assign a name: first time we see a value, assign "vN"\n'
        '    auto it = valueNames.find(v);\n'
        '    if (it != valueNames.end()) return it->second;\n'
        '    std::string name = "v" + std::to_string(nextVar++);\n'
        '    valueNames[v] = name;\n'
        '    return valueNames[v];\n'
        '  }\n'
        '};',
        "Variable Name Tracking"
    )

    pdf.subsection_title("Kernel Emission")
    pdf.body_text("When the emitter encounters a metal.kernel op, it:")
    pdf.bullet("Emits 'kernel void <name>(' as the function signature")
    pdf.bullet("For each memref argument, emits 'device float* vN [[buffer(N)]]'")
    pdf.bullet("Adds 'uint _tid [[thread_position_in_grid]]' as the last parameter")
    pdf.bullet("Walks all ops in the kernel body and emits each one")

    pdf.subsection_title("Op-to-MSL Mapping")
    pdf.code_block(
        'void emitOp(Operation &op) {\n'
        '  if (auto threadId = dyn_cast<metal::ThreadPositionInGridOp>(op))\n'
        '    // metal.thread_position_in_grid x  ->  uint v0 = _tid;\n'
        '    os << "    uint " << getName(op) << " = _tid;\\n";\n'
        '\n'
        '  else if (auto load = dyn_cast<memref::LoadOp>(op))\n'
        '    // memref.load %buf[%id]  ->  float v1 = v0[v2];\n'
        '    os << "    float " << getName(result) << " = " << getName(buf)\n'
        '       << "[" << getName(idx) << "];\\n";\n'
        '\n'
        '  else if (auto addf = dyn_cast<arith::AddFOp>(op))\n'
        '    // arith.addf %a, %b  ->  float v3 = v1 + v2;\n'
        '    os << "    float " << getName(result) << " = " << getName(lhs)\n'
        '       << " + " << getName(rhs) << ";\\n";\n'
        '\n'
        '  else if (auto store = dyn_cast<memref::StoreOp>(op))\n'
        '    // memref.store %val, %buf[%id]  ->  v0[v2] = v3;\n'
        '    os << "    " << getName(buf) << "[" << getName(idx) << "] = "\n'
        '       << getName(val) << ";\\n";\n'
        '}',
        "Operation Dispatch (simplified)"
    )

    pdf.subsection_title("Registration")
    pdf.code_block(
        'void registerToMSLTranslation() {\n'
        '  TranslateFromMLIRRegistration reg(\n'
        '    "mlir-to-msl",       // CLI flag: --mlir-to-msl\n'
        '    "Translate Metal MLIR to Metal Shading Language",\n'
        '    [](ModuleOp module, raw_ostream &os) {\n'
        '      MSLEmitter emitter(os);\n'
        '      emitter.emitPreamble();            // #include <metal_stdlib>\n'
        '      module.walk([&](metal::KernelOp kernel) {\n'
        '        emitter.emitKernel(kernel);       // Emit each kernel\n'
        '      });\n'
        '      return success();\n'
        '    },\n'
        '    [](DialectRegistry &registry) { ... } // Register needed dialects\n'
        '  );\n'
        '}',
        "Translation Registration"
    )

    # =========================================================================
    # 8. TOOLS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("8. Tools")

    pdf.subsection_title("8.1 metal-opt - IR Optimizer/Validator")
    pdf.code_block(
        'int main(int argc, char **argv) {\n'
        '  mlir::DialectRegistry registry;\n'
        '  registry.insert<metal::MetalDialect>();    // Our dialect\n'
        '  registry.insert<mlir::arith::ArithDialect>(); // For arith.addf, etc.\n'
        '  registry.insert<mlir::memref::MemRefDialect>(); // For memref.load/store\n'
        '  registry.insert<mlir::func::FuncDialect>();     // For func.func\n'
        '\n'
        '  return mlir::asMainReturnCode(\n'
        '    mlir::MlirOptMain(argc, argv, "Metal MLIR optimizer\\n", registry));\n'
        '}',
        "metal-opt.cpp"
    )
    pdf.body_text(
        "metal-opt is a customized version of mlir-opt that knows about the Metal dialect. "
        "It can parse, validate, and print Metal IR. It also supports all built-in MLIR passes "
        "(--canonicalize, --cse, etc.) for any standard dialect ops used inside kernels."
    )
    pdf.body_text("Usage:  ./build/tools/metal-opt/metal-opt test/vector_add.mlir")

    pdf.subsection_title("8.2 metal-translate - MSL Code Generator")
    pdf.code_block(
        'int main(int argc, char **argv) {\n'
        '  registerToMSLTranslation();  // Register --mlir-to-msl\n'
        '  return failed(\n'
        '    mlir::mlirTranslateMain(argc, argv, "Metal MLIR translator\\n"));\n'
        '}',
        "metal-translate.cpp"
    )
    pdf.body_text(
        "metal-translate converts Metal MLIR into MSL source code. The registerToMSLTranslation() "
        "call (from TranslateToMSL.cpp) makes the --mlir-to-msl flag available."
    )
    pdf.body_text(
        "Usage:  ./build/tools/metal-translate/metal-translate --mlir-to-msl test/vector_add.mlir -o kernel.metal"
    )

    # =========================================================================
    # 9. GPU RUNTIME
    # =========================================================================
    pdf.add_page()
    pdf.section_title("9. GPU Runtime (runner.mm)")
    pdf.body_text(
        "The runtime is an Objective-C++ program that uses Apple's Metal API to load the compiled "
        "GPU binary and execute the kernel. It's the 'host' side of GPU compute."
    )
    pdf.subsection_title("Execution Steps")
    pdf.bullet("Get GPU device via MTLCreateSystemDefaultDevice()", bold_prefix="Step 1:")
    pdf.bullet("Load .metallib file via [device newLibraryWithURL:]", bold_prefix="Step 2:")
    pdf.bullet("Look up kernel function by name via [library newFunctionWithName:]", bold_prefix="Step 3:")
    pdf.bullet("Create compute pipeline via [device newComputePipelineStateWithFunction:]", bold_prefix="Step 4:")
    pdf.bullet("Allocate input data on CPU (two float arrays: [0..1023] and [0,2,4..2046])", bold_prefix="Step 5:")
    pdf.bullet("Create Metal buffers with MTLResourceStorageModeShared (unified memory on Apple Silicon - no CPU<->GPU copy needed!)", bold_prefix="Step 6:")
    pdf.bullet("Create command queue, command buffer, and compute encoder", bold_prefix="Step 7:")
    pdf.bullet("Bind pipeline and buffers to encoder at indices 0, 1, 2 (matching [[buffer(N)]])", bold_prefix="Step 8:")
    pdf.bullet("Dispatch 1024 threads in a 1D grid", bold_prefix="Step 9:")
    pdf.bullet("Commit and wait for GPU completion", bold_prefix="Step 10:")
    pdf.bullet("Read results directly from shared buffer and verify a[i] + b[i] == result[i]", bold_prefix="Step 11:")

    pdf.subsection_title("Key Detail: Unified Memory")
    pdf.body_text(
        "On Apple Silicon, CPU and GPU share the same physical memory. Using "
        "MTLResourceStorageModeShared means the Metal buffer IS the CPU buffer - no copying. "
        "After the GPU finishes, you read results directly with [bufOut contents]. This is a "
        "major advantage over discrete GPUs (NVIDIA/AMD) where you must explicitly copy data "
        "between CPU and GPU memory."
    )

    pdf.subsection_title("Compile & Run")
    pdf.code_block(
        '# Compile the Objective-C++ runner\n'
        'clang++ -framework Metal -framework Foundation \\\n'
        '        -std=c++17 -ObjC++ runner.mm -o runner\n'
        '\n'
        '# Run with a metallib\n'
        './runner kernel.metallib',
        "Runtime Build"
    )

    # =========================================================================
    # 10. TEST KERNEL
    # =========================================================================
    pdf.add_page()
    pdf.section_title("10. Test Kernel (vector_add.mlir)")
    pdf.code_block(
        'module {\n'
        '  metal.kernel @vector_add(\n'
        '      %a: memref<?xf32>,     // Input buffer A (device float*)\n'
        '      %b: memref<?xf32>,     // Input buffer B (device float*)\n'
        '      %out: memref<?xf32>    // Output buffer  (device float*)\n'
        '  ) {\n'
        '    // Get this thread\'s global index\n'
        '    %id = metal.thread_position_in_grid x\n'
        '\n'
        '    // Load a[id] and b[id]\n'
        '    %va = memref.load %a[%id] : memref<?xf32>\n'
        '    %vb = memref.load %b[%id] : memref<?xf32>\n'
        '\n'
        '    // Compute sum\n'
        '    %sum = arith.addf %va, %vb : f32\n'
        '\n'
        '    // Store result[id] = sum\n'
        '    memref.store %sum, %out[%id] : memref<?xf32>\n'
        '\n'
        '    metal.return\n'
        '  }\n'
        '}',
        "test/vector_add.mlir (annotated)"
    )
    pdf.body_text("This translates to the following MSL:")
    pdf.code_block(
        '#include <metal_stdlib>\n'
        'using namespace metal;\n'
        '\n'
        'kernel void vector_add(\n'
        '    device float* v0 [[buffer(0)]],\n'
        '    device float* v1 [[buffer(1)]],\n'
        '    device float* v2 [[buffer(2)]],\n'
        '    uint _tid [[thread_position_in_grid]]\n'
        ') {\n'
        '    uint v3 = _tid;\n'
        '    float v4 = v0[v3];\n'
        '    float v5 = v1[v3];\n'
        '    float v6 = v4 + v5;\n'
        '    v2[v3] = v6;\n'
        '}',
        "Generated MSL Output"
    )

    # =========================================================================
    # 11. END-TO-END WALKTHROUGH
    # =========================================================================
    pdf.add_page()
    pdf.section_title("11. End-to-End Pipeline Walkthrough")
    pdf.code_block(
        '# Step 1: Validate the Metal MLIR\n'
        './build/tools/metal-opt/metal-opt test/vector_add.mlir\n'
        '\n'
        '# Step 2: Translate to MSL source code\n'
        './build/tools/metal-translate/metal-translate \\\n'
        '    --mlir-to-msl test/vector_add.mlir -o runtime/kernel.metal\n'
        '\n'
        '# Step 3: Compile MSL -> AIR (Apple Intermediate Representation)\n'
        'xcrun -sdk macosx metal -c runtime/kernel.metal -o runtime/kernel.air\n'
        '\n'
        '# Step 4: Link AIR -> metallib (GPU binary)\n'
        'xcrun -sdk macosx metallib runtime/kernel.air -o runtime/kernel.metallib\n'
        '\n'
        '# Step 5: Execute on GPU\n'
        './runtime/runner runtime/kernel.metallib',
        "Full Pipeline Commands"
    )
    pdf.body_text("Expected output:")
    pdf.code_block(
        'Using device: Apple M4\n'
        '\n'
        'Results (first 10):\n'
        '  0 + 0 = 0\n'
        '  1 + 2 = 3\n'
        '  2 + 4 = 6\n'
        '  3 + 6 = 9\n'
        '  4 + 8 = 12\n'
        '  5 + 10 = 15\n'
        '  6 + 12 = 18\n'
        '  7 + 14 = 21\n'
        '  8 + 16 = 24\n'
        '  9 + 18 = 27\n'
        '\n'
        'Verification: PASSED (0 errors out of 1024)',
        "GPU Output"
    )
    pdf.body_text(
        "The runtime creates two arrays: A = [0, 1, 2, ..., 1023] and B = [0, 2, 4, ..., 2046]. "
        "The kernel computes A[i] + B[i] for all 1024 elements in parallel on the GPU. "
        "Each GPU thread handles one element."
    )

    # =========================================================================
    # 12. HOW TO EXTEND
    # =========================================================================
    pdf.add_page()
    pdf.section_title("12. How to Extend")

    pdf.subsection_title("Adding a New Op")
    pdf.body_text("To add a new operation (e.g. metal.grid_size):")
    pdf.bullet("Add the op definition to MetalOps.td with arguments, results, and format")
    pdf.bullet("Rebuild (cmake --build build) - TableGen auto-generates C++ code")
    pdf.bullet("Add MSL emission for the op in TranslateToMSL.cpp's emitOp() method")
    pdf.bullet("Write a test .mlir file that uses the new op")

    pdf.subsection_title("Adding New Kernel Types")
    pdf.body_text(
        "The current emitter supports 1D kernels with float buffers. To extend:"
    )
    pdf.bullet("2D/3D grids: emit uint3 _tid and use _tid.x, _tid.y, _tid.z in emitThreadId()")
    pdf.bullet("Integer buffers: update emitKernel() to handle memref<?xi32> -> device int*")
    pdf.bullet("Shared memory: add threadgroup address space support for threadgroup float* in MSL")
    pdf.bullet("Loops: handle scf.for by emitting MSL for-loops")
    pdf.bullet("Conditionals: handle scf.if by emitting MSL if/else")

    pdf.subsection_title("Adding a Lowering Pass (gpu -> metal)")
    pdf.body_text(
        "To lower from MLIR's generic gpu dialect to this Metal dialect, write a ConversionPass "
        "that rewrites gpu.thread_id -> metal.thread_position_in_grid, gpu.barrier -> "
        "metal.threadgroup_barrier, etc. Register it in metal-opt with PassRegistration<>."
    )

    pdf.subsection_title("Data Flow Diagram")
    pdf.code_block(
        '  .td files          mlir-tblgen        .h.inc / .cpp.inc\n'
        '  (you write)   -->  (auto-generates)   (you never edit)\n'
        '       |                                       |\n'
        '       v                                       v\n'
        '  MetalDialect.cpp  <---  includes  <---  MetalDialect.h\n'
        '  (you write)                             (you write)\n'
        '       |\n'
        '       v\n'
        '  libMetalDialect.a  -->  metal-opt (validate IR)\n'
        '       |              -->  metal-translate (emit MSL)\n'
        '       v\n'
        '  kernel.metal  -->  xcrun metal  -->  kernel.metallib  -->  runner (GPU)',
        "Build & Data Flow"
    )

    # =========================================================================
    # OUTPUT
    # =========================================================================
    output_path = "/Users/tanmay/Desktop/mlx-stuff/mlir-stuff/metal-dialect/Metal_Dialect_Documentation.pdf"
    pdf.output(output_path)
    print(f"PDF generated: {output_path}")

if __name__ == "__main__":
    build_pdf()

//===- EnigmaOps.td - Enigma dialect operations -----------*- tablegen -*-===//
//
// WHAT THIS FILE IS
//   The op catalogue for the `enigma` dialect. Every op users can write in
//   `.mlir` source — `enigma.kernel`, `enigma.return`,
//   `enigma.thread_position_in_grid`, … — is defined here.
//
//   TableGen generates, for each op def:
//     - A C++ class (e.g. `enigma::KernelOp`)
//     - Its parser and printer
//     - Its verifier
//     - Its builder methods
//     - Its accessor methods for operands, results, attributes, regions
//
//   You write ~20 lines of declarative .td and get ~300 lines of C++ for
//   free. That's the entire point of TableGen.
//
// HOW TO ADD A NEW OP — the recipe
//   1. Decide the op's name (e.g. "simd_sum")
//   2. Decide its operands (inputs), results (outputs), attributes, regions
//   3. Pick the right Traits (Pure? Terminator? IsolatedFromAbove?)
//   4. Write the def block below, following the pattern of existing ops
//   5. Add an emission case in lib/Target/MSL/MSLEmitter.cpp
//   6. Add a lit test in test/
//   7. Rebuild — mlir-tblgen regenerates everything
//
//   A good rule of thumb: if you can't describe your op as "1 line of MSL",
//   it's probably too big and should be split.
//
// WHY THIS FILE IS CURRENTLY SMALL
//   We start with only the ops needed for the vector_add demo. This is
//   deliberate — every op we add is extra surface area to test, verify, and
//   emit. We grow the catalogue one vertical slice at a time: get vector_add
//   working end-to-end, then add threadgroup memory, then simdgroup ops,
//   etc. See docs/project-structure.md §"Build order".
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_OPS_TD
#define ENIGMA_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/BuiltinAttributes.td"
include "mlir/IR/EnumAttr.td"
include "mlir/Interfaces/SideEffectInterfaces.td"  // gives us `Pure`, etc.

//===----------------------------------------------------------------------===//
// Dimension enum — x / y / z axis selector for thread-position ops
//===----------------------------------------------------------------------===//
//
// Metal's thread-position builtins (thread_position_in_grid, etc.) return a
// `uint3`. In MLIR we model that as "give me the i'th component", where i
// is a dimension enum. This is the same shape as upstream `gpu.thread_id`
// which takes a `gpu::Dimension` attribute.
//
// Each case has a string spelling (`x`) and an integer value (`0`). The
// enum gets a full C++ class `enigma::Dimension` generated for it.
def Enigma_DimX : I32EnumAttrCase<"x", 0>;
def Enigma_DimY : I32EnumAttrCase<"y", 1>;
def Enigma_DimZ : I32EnumAttrCase<"z", 2>;

def Enigma_Dimension : I32EnumAttr<"Dimension",
    "GPU dimension index (x/y/z)",
    [Enigma_DimX, Enigma_DimY, Enigma_DimZ]> {
  let cppNamespace = "::enigma";
}

//===----------------------------------------------------------------------===//
// enigma.kernel — a Metal compute kernel function
//===----------------------------------------------------------------------===//
//
// This op wraps a region of IR that will become the body of a `kernel void`
// function in MSL. It is the main "container" op of the dialect — every
// other op exists to live inside a kernel body.
//
// Traits:
//   - IsolatedFromAbove: the kernel body cannot reference SSA values
//     defined outside the kernel. This is essential because a GPU kernel
//     runs in a completely different address space from the host — there
//     is literally nothing to reference.
//
// Design shortcut: we currently represent the kernel signature as a
// `FunctionType` attribute and use a custom assembly format. In a fuller
// production dialect we would implement the `FunctionOpInterface` so the
// kernel behaves like a proper function symbol (callable, discoverable via
// symbol lookup, etc.). See the NEXT STEPS comment at the bottom of the file.
def Enigma_KernelOp : Enigma_Op<"kernel", [IsolatedFromAbove]> {
  let summary = "Metal compute kernel function";

  let description = [{
    An `enigma.kernel` op defines a GPU compute entry point. Its body is a
    single region containing the instructions that will execute on the GPU.
    The body may only reference its own block arguments (the kernel's
    parameters) and values defined within the body itself.

    Example:
    ```mlir
    enigma.kernel @vector_add(%a: memref<?xf32>,
                              %b: memref<?xf32>,
                              %c: memref<?xf32>) {
      %i = enigma.thread_position_in_grid x
      %va = memref.load %a[%i] : memref<?xf32>
      %vb = memref.load %b[%i] : memref<?xf32>
      %vc = arith.addf %va, %vb : f32
      memref.store %vc, %c[%i] : memref<?xf32>
      enigma.return
    }
    ```
  }];

  let arguments = (ins
    // `sym_name` is the kernel's name. In MSL this becomes the function
    // name that the host looks up with `newFunctionWithName:`. Must be a
    // valid C identifier.
    StrAttr:$sym_name,
    // `function_type` stores the argument types. We wrap them in a
    // FunctionType so standard MLIR utilities (printer, verifier) can
    // understand the kernel's signature.
    TypeAttrOf<FunctionType>:$function_type
  );

  // Single region holding the kernel body. "AnyRegion" means we don't
  // constrain what ops live inside it — any valid MLIR op is allowed.
  let regions = (region AnyRegion:$body);

  // We can't use assemblyFormat here because the parser needs to create
  // block arguments for the kernel body at the same time as parsing the
  // signature — TableGen's assemblyFormat can't express that. So we drop
  // into C++ and implement parse() / print() by hand in EnigmaDialect.cpp.
  let hasCustomAssemblyFormat = 1;
}

//===----------------------------------------------------------------------===//
// enigma.return — terminator for an enigma.kernel body
//===----------------------------------------------------------------------===//
//
// Metal compute kernels always return `void`, so this op takes no operands
// and has no results. It exists purely to mark the end of the kernel body.
// MLIR requires every block to have a terminator, and we can't use
// `func.return` because our kernel op isn't a `func.func`.
//
// NEXT STEPS: when we add vertex/fragment shaders, those *can* return
// values (position, color). At that point we'll either generalize this op
// to carry operands, or add `enigma.vertex_return` / `enigma.fragment_return`
// as separate terminators. Favor the latter — it keeps verification simple.
def Enigma_ReturnOp : Enigma_Op<"return", [Terminator]> {
  let summary = "Return from an enigma.kernel (void)";
  let assemblyFormat = "attr-dict";
}

//===----------------------------------------------------------------------===//
// Thread-indexing builtins
//===----------------------------------------------------------------------===//
//
// These four ops mirror Metal's thread-position builtins. In MSL they are
// *implicit* — you declare a kernel parameter with a `[[...]]` attribute
// like `uint tid [[thread_position_in_grid]]` and Metal fills it in at
// dispatch time.
//
// In our dialect we model them as explicit ops returning an `index`. The
// MSL emitter is responsible for recognizing these ops, injecting the
// right `[[...]]` parameter into the emitted kernel signature, and
// rewriting uses of the op result to reference that parameter.
//
// They are all marked `Pure` because calling the same builtin twice in the
// same thread yields the same result, with no side effects. This lets
// canonicalization fold duplicate calls automatically.
//
// DESIGN NOTE: we use a single class template here because these ops are
// structurally identical. If they ever diverge (e.g. one needs a verifier,
// another needs extra attributes) split them into separate defs.
class Enigma_ThreadIndexOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure]> {
  let summary = doc;
  let arguments = (ins Enigma_Dimension:$dimension);
  let results = (outs Index:$result);
  let assemblyFormat = "$dimension attr-dict";
}

def Enigma_ThreadPositionInGridOp
    : Enigma_ThreadIndexOp<"thread_position_in_grid",
        "Global thread id — position of this thread within the entire grid">;

def Enigma_ThreadgroupPositionInGridOp
    : Enigma_ThreadIndexOp<"threadgroup_position_in_grid",
        "Block id — position of this threadgroup within the grid">;

def Enigma_ThreadPositionInThreadgroupOp
    : Enigma_ThreadIndexOp<"thread_position_in_threadgroup",
        "Local thread id — position within the containing threadgroup">;

def Enigma_ThreadsPerThreadgroupOp
    : Enigma_ThreadIndexOp<"threads_per_threadgroup",
        "Block dim — number of threads per threadgroup">;

//===----------------------------------------------------------------------===//
// enigma.threadgroup_barrier — synchronization within a threadgroup
//===----------------------------------------------------------------------===//
//
// Corresponds directly to `threadgroup_barrier(mem_flags::...)` in MSL.
// All threads in a threadgroup must hit this op before any of them
// proceeds past it, and memory writes before the barrier become visible
// to other threads after the barrier.
//
// The `mem_flags` attribute is currently a bare I32Attr — in production we
// should make it an `EnumAttr` with named cases (`none`, `device`,
// `threadgroup`, `texture`) so misuse is caught by the verifier. That's
// listed as a NEXT STEP below.
//
// Not marked `Pure` because barriers have observable side effects (they
// synchronize threads).
def Enigma_ThreadgroupBarrierOp : Enigma_Op<"threadgroup_barrier", []> {
  let summary = "Metal threadgroup_barrier — synchronize threads in a threadgroup";
  let arguments = (ins I32Attr:$mem_flags);
  let assemblyFormat = "$mem_flags attr-dict";
}

//===----------------------------------------------------------------------===//
// NEXT STEPS — what to add here and in what order
//===----------------------------------------------------------------------===//
//
// The ops above are just enough to compile vector_add. To grow toward full
// MSL coverage, add the following in order. Each slice should be one PR
// with new ops, new emitter cases, and new lit tests.
//
//   1. Address-space aware memref types.
//      Add an EnigmaAddressSpaceAttr (device/constant/threadgroup/thread)
//      and teach the emitter to print the right MSL qualifier.
//
//   2. Threadgroup memory allocation op.
//      `enigma.threadgroup_alloc` returning a memref in address space
//      `threadgroup`. Needed for reductions, scans, convolution tiles.
//
//   3. Simdgroup reduction ops.
//      `enigma.simd_sum`, `simd_max`, `simd_ballot`, `simd_broadcast`.
//      These map 1:1 to MSL builtins.
//
//   4. Atomic ops.
//      `enigma.atomic_fetch_add` etc. with a memory-order enum attribute.
//
//   5. Texture types and ops.
//      `!enigma.texture2d<f32, sample>`, `enigma.texture_sample`, etc.
//      This is where custom dialect types first become necessary.
//
//   6. Argument buffer type + packing op.
//      `!enigma.argument_buffer<...>`, `enigma.arg_buffer_pack`.
//
//   7. Graphics stages (vertex/fragment).
//      `enigma.vertex`, `enigma.fragment` ops with stage_in / stage_out
//      attribute handling.
//
// For each slice, remember the loop:
//   hand-write the MSL you want → design the op → write the .td block here
//   → add emitter case → add lit test → run xcrun metal as oracle → commit.
//
//===----------------------------------------------------------------------===//

#endif // ENIGMA_OPS_TD

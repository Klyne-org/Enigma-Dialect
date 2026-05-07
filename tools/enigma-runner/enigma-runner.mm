// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- enigma-runner.mm - Load a metallib and launch a kernel on GPU -----===//
//
// WHAT THIS BINARY IS
//   A small host-side driver that uses the actual Metal API (on macOS)
//   to:
//     1. Load a compiled .metallib file.
//     2. Look up a kernel function inside it.
//     3. Allocate some test buffers with known data.
//     4. Dispatch the kernel on the GPU.
//     5. Read back the results and print them.
//
//   The goal is to close the final loop of the Enigma pipeline:
//
//     .mlir  --enigma-translate-->  .metal text
//            --xcrun metal-->       .air
//            --xcrun metallib-->    .metallib
//            --enigma-runner-->     actually runs on the GPU
//
//   Without this tool, the emitter is un-verified — you could be emitting
//   MSL that compiles but produces wrong results, and never know. The
//   runner is how we catch that.
//
// CURRENT SCOPE — DELIBERATELY SMALL
//   This is a base tailored for the `vector_add(a, b, c)` kernel shape:
//   three float buffers, 1D grid, compute-only. That's enough to prove
//   the whole pipeline works end-to-end.
//
//   Generalizing it (arbitrary kernel names, arbitrary buffer layouts,
//   arbitrary grids) is the kind of work where the right answer is "make
//   this a proper libEnigmaRuntime with a C API, then a tiny CLI on top."
//   That refactor is listed at the bottom of this file as a NEXT STEP.
//
// WHY Objective-C++ (.mm)
//   The Metal API is Objective-C. C++ can call into it but only through
//   files with the .mm extension, which lets clang mix ObjC and C++. This
//   file is the only ObjC++ file in the project; everything else is pure
//   C++ so it stays cross-platform.
//
// BUILDING
//   This tool is only built when ENIGMA_ENABLE_METAL_RUNTIME is ON (the
//   root CMakeLists defaults that to ON on macOS, OFF otherwise). Linux
//   contributors can still build and lit-test the rest of the project;
//   only full integration tests require macOS.
//
// RUNNING
//   enigma-runner path/to/kernel.metallib [kernel_name]
//
//   kernel_name defaults to "vector_add".
//
//===----------------------------------------------------------------------===//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {

// Size of the test buffers. 1024 is enough to be non-trivial and small
// enough that printing a few results is readable. Tune freely.
constexpr int kCount = 1024;

// Pretty-print a libdispatch / Metal error and bail. We treat every error
// here as fatal because there's nothing this runner can reasonably
// recover from — the kernel either ran or it didn't.
[[noreturn]] void fatal(const char *what, NSError *err = nil) {
  if (err) {
    fprintf(stderr, "enigma-runner: %s: %s\n", what,
            [[err localizedDescription] UTF8String]);
  } else {
    fprintf(stderr, "enigma-runner: %s\n", what);
  }
  std::exit(1);
}

} // namespace

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    // -----------------------------------------------------------------------
    // 1. Parse arguments.
    // -----------------------------------------------------------------------
    if (argc < 2) {
      fprintf(stderr,
              "usage: enigma-runner <path/to/kernel.metallib> [kernel_name]\n"
              "       defaults: kernel_name = vector_add\n");
      return 2;
    }
    NSString *libPath = [NSString stringWithUTF8String:argv[1]];
    NSString *kernelName =
        (argc > 2) ? [NSString stringWithUTF8String:argv[2]] : @"vector_add";

    // -----------------------------------------------------------------------
    // 2. Pick the default GPU.
    // -----------------------------------------------------------------------
    // On Apple Silicon this is the integrated GPU. On Intel Macs it may
    // be a discrete card. Either works for compute.
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device)
      fatal("no Metal device available on this machine");
    printf("enigma-runner: using device '%s'\n",
           [[device name] UTF8String]);

    // -----------------------------------------------------------------------
    // 3. Load the .metallib we were given.
    // -----------------------------------------------------------------------
    // Typical production tools would load from a bundled resource; we
    // just accept a path because the runner is a dev tool, not a shipped
    // product.
    NSError *err = nil;
    NSURL *libURL = [NSURL fileURLWithPath:libPath];
    id<MTLLibrary> library = [device newLibraryWithURL:libURL error:&err];
    if (!library)
      fatal("failed to load metallib", err);

    // -----------------------------------------------------------------------
    // 4. Look up the kernel function and build a compute pipeline.
    // -----------------------------------------------------------------------
    id<MTLFunction> function = [library newFunctionWithName:kernelName];
    if (!function) {
      fprintf(stderr, "enigma-runner: kernel '%s' not found in metallib\n",
              [kernelName UTF8String]);
      return 1;
    }

    id<MTLComputePipelineState> pipeline =
        [device newComputePipelineStateWithFunction:function error:&err];
    if (!pipeline)
      fatal("failed to create compute pipeline", err);

    // -----------------------------------------------------------------------
    // 5. Allocate host-side test data.
    // -----------------------------------------------------------------------
    // We only test the classic vector-add input pattern right now:
    //   a[i] = i        b[i] = 2*i     expected out[i] = 3*i
    // Extending the runner to more kernels is a NEXT STEP.
    float *hostA = (float *)std::malloc(kCount * sizeof(float));
    float *hostB = (float *)std::malloc(kCount * sizeof(float));
    for (int i = 0; i < kCount; ++i) {
      hostA[i] = (float)i;
      hostB[i] = (float)(i * 2);
    }

    // -----------------------------------------------------------------------
    // 6. Create Metal buffers.
    // -----------------------------------------------------------------------
    // MTLResourceStorageModeShared means "host and GPU share the same
    // memory pages." On Apple Silicon this is zero-copy. On Intel Macs
    // with discrete GPUs this incurs a sync, but still works.
    id<MTLBuffer> bufA = [device newBufferWithBytes:hostA
                                             length:kCount * sizeof(float)
                                            options:MTLResourceStorageModeShared];
    id<MTLBuffer> bufB = [device newBufferWithBytes:hostB
                                             length:kCount * sizeof(float)
                                            options:MTLResourceStorageModeShared];
    id<MTLBuffer> bufOut = [device newBufferWithLength:kCount * sizeof(float)
                                               options:MTLResourceStorageModeShared];

    // -----------------------------------------------------------------------
    // 7. Build and submit a command buffer.
    // -----------------------------------------------------------------------
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];

    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:bufA   offset:0 atIndex:0];  // [[buffer(0)]]
    [encoder setBuffer:bufB   offset:0 atIndex:1];  // [[buffer(1)]]
    [encoder setBuffer:bufOut offset:0 atIndex:2];  // [[buffer(2)]]

    // Dispatch kCount threads. We let Metal pick a reasonable threadgroup
    // size by clamping to the pipeline's max.
    MTLSize grid = MTLSizeMake(kCount, 1, 1);
    NSUInteger maxPerGroup = [pipeline maxTotalThreadsPerThreadgroup];
    MTLSize group = MTLSizeMake(MIN(maxPerGroup, (NSUInteger)kCount), 1, 1);
    [encoder dispatchThreads:grid threadsPerThreadgroup:group];
    [encoder endEncoding];

    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // -----------------------------------------------------------------------
    // 8. Read the results back and verify.
    // -----------------------------------------------------------------------
    const float *result = (const float *)[bufOut contents];
    printf("enigma-runner: first 10 results:\n");
    for (int i = 0; i < 10; ++i) {
      printf("  %4d: %.1f + %.1f = %.1f\n", i, hostA[i], hostB[i], result[i]);
    }

    int errors = 0;
    for (int i = 0; i < kCount; ++i) {
      if (result[i] != hostA[i] + hostB[i])
        ++errors;
    }
    printf("enigma-runner: %s (%d / %d mismatches)\n",
           errors == 0 ? "PASSED" : "FAILED", errors, kCount);

    std::free(hostA);
    std::free(hostB);
    return errors == 0 ? 0 : 1;
  }
}

//===----------------------------------------------------------------------===//
// NEXT STEPS — evolving the runner
//===----------------------------------------------------------------------===//
//
//   1. Split into a reusable `libEnigmaRuntime` library + a thin CLI.
//      Right now the runner is ~150 lines of mixed concerns. In production
//      every step should be a library function:
//
//         enigma::createDevice()
//         enigma::loadLibrary(path)
//         enigma::createPipeline(library, kernelName)
//         enigma::Buffer::fromHost(data, size)
//         enigma::dispatch(pipeline, buffers, grid, threadgroup)
//
//      Those functions become the C API for Python bindings and the
//      embedded use cases. enigma-runner.mm shrinks to ~20 lines that
//      just parses argv and calls them.
//
//   2. Make the test data shape configurable.
//      Today it assumes exactly three float buffers of length 1024. A
//      slightly more general runner would take a tiny JSON or flat-text
//      "test plan" that says: for each buffer, what type, what size,
//      what initial data, and what expected output. That unlocks reusing
//      the runner for every new kernel we add to the lit suite.
//
//   3. Integration-test driver mode.
//      Add a flag `--expected path/to/expected.bin` that compares the
//      output buffer byte-for-byte against a file. Then we can make each
//      integration test a simple `enigma-runner kernel.metallib
//      kernel_name --expected out.bin` invocation inside lit.
//
//   4. Timing + occupancy reporting.
//      Metal exposes command-buffer GPU time via
//      `[cmdBuf GPUStartTime/GPUEndTime]`. Printing that on every run
//      gives you a cheap perf regression signal.
//
//===----------------------------------------------------------------------===//

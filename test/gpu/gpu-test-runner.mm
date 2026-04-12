// gpu-test-runner.mm — End-to-end GPU test runner for Enigma dialect kernels.
//
// Compiles inline or loads .metallib, dispatches kernels with known inputs,
// verifies outputs match expected values.
//
// Usage: gpu-test-runner <path-to.metallib> <test-name>
//
// Test names: vector_add, scale_constant, math_sqrt, threadgroup_copy,
//             atomic_count, saxpy, negate, clamp_test

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static constexpr int N = 1024;
static constexpr float EPS = 1e-3f;

struct TestResult {
  std::string name;
  int errors;
  int total;
};

static id<MTLDevice> device;
static id<MTLCommandQueue> queue;

static id<MTLBuffer> makeFloatBuf(const std::vector<float> &data) {
  return [device newBufferWithBytes:data.data()
                             length:data.size() * sizeof(float)
                            options:MTLResourceStorageModeShared];
}

static id<MTLBuffer> makeIntBuf(const std::vector<int32_t> &data) {
  return [device newBufferWithBytes:data.data()
                             length:data.size() * sizeof(int32_t)
                            options:MTLResourceStorageModeShared];
}

static id<MTLBuffer> makeEmptyFloat(int count) {
  return [device newBufferWithLength:count * sizeof(float)
                             options:MTLResourceStorageModeShared];
}

static id<MTLBuffer> makeEmptyInt(int count) {
  return [device newBufferWithLength:count * sizeof(int32_t)
                             options:MTLResourceStorageModeShared];
}

static void dispatch(id<MTLComputePipelineState> pipeline,
                     NSArray<id<MTLBuffer>> *buffers, int threadCount,
                     int groupSize = 0) {
  id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
  id<MTLComputeCommandEncoder> enc = [cmdBuf computeCommandEncoder];
  [enc setComputePipelineState:pipeline];
  for (NSUInteger i = 0; i < buffers.count; i++)
    [enc setBuffer:buffers[i] offset:0 atIndex:i];

  NSUInteger gs = groupSize > 0 ? groupSize
                    : MIN([pipeline maxTotalThreadsPerThreadgroup],
                          (NSUInteger)threadCount);
  [enc dispatchThreads:MTLSizeMake(threadCount, 1, 1)
      threadsPerThreadgroup:MTLSizeMake(gs, 1, 1)];
  [enc endEncoding];
  [cmdBuf commit];
  [cmdBuf waitUntilCompleted];
}

static int verifyFloat(id<MTLBuffer> buf, const std::vector<float> &expected,
                       const char *name) {
  const float *out = (const float *)[buf contents];
  int errs = 0;
  for (int i = 0; i < (int)expected.size(); i++) {
    if (std::fabs(out[i] - expected[i]) > EPS) {
      if (errs < 5)
        printf("    MISMATCH %s[%d]: got %.4f, expected %.4f\n", name, i,
               out[i], expected[i]);
      errs++;
    }
  }
  return errs;
}

static int verifyInt(id<MTLBuffer> buf, const std::vector<int32_t> &expected,
                     const char *name) {
  const int32_t *out = (const int32_t *)[buf contents];
  int errs = 0;
  for (int i = 0; i < (int)expected.size(); i++) {
    if (out[i] != expected[i]) {
      if (errs < 5)
        printf("    MISMATCH %s[%d]: got %d, expected %d\n", name, i, out[i],
               expected[i]);
      errs++;
    }
  }
  return errs;
}

// ============================================================================
// Test implementations
// ============================================================================

static TestResult test_vector_add(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"vector_add"];
  if (!fn) return {"vector_add", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> a(N), b(N), expected(N);
  for (int i = 0; i < N; i++) { a[i] = i; b[i] = i * 2; expected[i] = i * 3; }

  auto bufA = makeFloatBuf(a), bufB = makeFloatBuf(b);
  auto bufC = makeEmptyFloat(N);
  dispatch(pipe, @[bufA, bufB, bufC], N);

  int errs = verifyFloat(bufC, expected, "c");
  return {"vector_add", errs, N};
}

static TestResult test_scale_constant(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"scale_constant"];
  if (!fn) return {"scale_constant", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> weights(N), expected(N);
  for (int i = 0; i < N; i++) { weights[i] = i; expected[i] = i * 2; }

  auto bufW = makeFloatBuf(weights);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufW, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"scale_constant", errs, N};
}

static TestResult test_math_sqrt(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"math_sqrt"];
  if (!fn) return {"math_sqrt", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> in(N), expected(N);
  for (int i = 0; i < N; i++) {
    in[i] = (float)((i + 1) * (i + 1));
    expected[i] = (float)(i + 1);
  }

  auto bufIn = makeFloatBuf(in);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufIn, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"math_sqrt", errs, N};
}

static TestResult test_threadgroup_copy(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"threadgroup_copy"];
  if (!fn) return {"threadgroup_copy", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  int count = 256; // must match threadgroup_alloc size
  std::vector<float> in(count), expected(count);
  for (int i = 0; i < count; i++) { in[i] = i * 10.0f; expected[i] = i * 10.0f; }

  auto bufIn = makeFloatBuf(in);
  auto bufOut = makeEmptyFloat(count);
  dispatch(pipe, @[bufIn, bufOut], count, 256);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"threadgroup_copy", errs, count};
}

static TestResult test_atomic_count(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"atomic_count"];
  if (!fn) return {"atomic_count", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<int32_t> data(N, 0);
  std::vector<int32_t> count(1, 0);

  auto bufData = makeIntBuf(data);
  auto bufCount = makeIntBuf(count);
  dispatch(pipe, @[bufData, bufCount], N);

  std::vector<int32_t> expected = {N};
  int errs = verifyInt(bufCount, expected, "count");
  return {"atomic_count", errs, 1};
}

static TestResult test_saxpy(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"saxpy"];
  if (!fn) return {"saxpy", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> a_buf = {2.0f};
  std::vector<float> x(N), y(N), expected(N);
  for (int i = 0; i < N; i++) {
    x[i] = (float)i;
    y[i] = 100.0f;
    expected[i] = 2.0f * i + 100.0f;
  }

  // pad a_buf to at least N so Metal doesn't complain about buffer size
  a_buf.resize(N, 2.0f);

  auto bufA = makeFloatBuf(a_buf);
  auto bufX = makeFloatBuf(x);
  auto bufY = makeFloatBuf(y);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufA, bufX, bufY, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"saxpy", errs, N};
}

static TestResult test_negate(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"negate"];
  if (!fn) return {"negate", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> in(N), expected(N);
  for (int i = 0; i < N; i++) { in[i] = i + 1; expected[i] = -(i + 1); }

  auto bufIn = makeFloatBuf(in);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufIn, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"negate", errs, N};
}

static TestResult test_clamp(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"clamp_test"];
  if (!fn) return {"clamp_test", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> in(N), expected(N);
  for (int i = 0; i < N; i++) {
    in[i] = (float)i / (N / 4.0f) - 1.0f; // range ~ [-1, 3]
    expected[i] = std::fmin(std::fmax(in[i], 0.0f), 1.0f);
  }

  auto bufIn = makeFloatBuf(in);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufIn, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"clamp_test", errs, N};
}

// --- New tests for Phase 2 features ---

static TestResult test_select(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"select_test"];
  if (!fn) return {"select_test", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> a(N), b(N), expected(N);
  for (int i = 0; i < N; i++) {
    a[i] = -1.0f;
    b[i] = (float)i;
    // cond = b[i] >= 0 → true for all, so select picks b[i]
    expected[i] = (float)i;
  }

  auto bufA = makeFloatBuf(a), bufB = makeFloatBuf(b);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufA, bufB, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"select_test", errs, N};
}

static TestResult test_iclamp(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"iclamp_test"];
  if (!fn) return {"iclamp_test", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<int32_t> in(N), expected(N);
  for (int i = 0; i < N; i++) {
    in[i] = i - 50;
    expected[i] = std::max(0, std::min(in[i], 100));
  }

  auto bufIn = makeIntBuf(in);
  auto bufOut = makeEmptyInt(N);
  dispatch(pipe, @[bufIn, bufOut], N);

  int errs = verifyInt(bufOut, expected, "out");
  return {"iclamp_test", errs, N};
}

static TestResult test_for_loop(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"for_loop_test"];
  if (!fn) return {"for_loop_test", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  // Every thread computes sum(0..9) = 45.0
  std::vector<float> expected(N, 45.0f);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"for_loop_test", errs, N};
}

static TestResult test_isnan_check(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"isnan_check"];
  if (!fn) return {"isnan_check", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<float> in(N, 0.0f), expected(N, 0.0f);
  in[0] = NAN;     expected[0] = 1.0f;
  in[1] = 1.0f;    expected[1] = 0.0f;
  in[2] = INFINITY; expected[2] = 0.0f;
  in[3] = 0.0f;    expected[3] = 0.0f;

  auto bufIn = makeFloatBuf(in);
  auto bufOut = makeEmptyFloat(N);
  dispatch(pipe, @[bufIn, bufOut], N);

  int errs = verifyFloat(bufOut, expected, "out");
  return {"isnan_check", errs, N};
}

static TestResult test_imin_imax(id<MTLLibrary> lib) {
  NSError *err;
  id<MTLFunction> fn = [lib newFunctionWithName:@"imin_imax_test"];
  if (!fn) return {"imin_imax_test", 1, 1};
  auto pipe = [device newComputePipelineStateWithFunction:fn error:&err];

  std::vector<int32_t> a(N), expected(N);
  for (int i = 0; i < N; i++) {
    a[i] = i * 3 - 50;
    expected[i] = std::max(0, std::min(a[i], 100));
  }

  auto bufA = makeIntBuf(a);
  auto bufOut = makeEmptyInt(N);
  dispatch(pipe, @[bufA, bufOut], N);

  int errs = verifyInt(bufOut, expected, "out");
  return {"imin_imax_test", errs, N};
}

// ============================================================================
// Main
// ============================================================================

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc < 2) {
      fprintf(stderr,
        "usage: gpu-test-runner <metallib-path> [test-name|all]\n"
        "  tests: vector_add, scale_constant, math_sqrt, threadgroup_copy,\n"
        "         atomic_count, saxpy, negate, clamp_test, all\n");
      return 2;
    }

    device = MTLCreateSystemDefaultDevice();
    if (!device) { fprintf(stderr, "No Metal device\n"); return 1; }
    queue = [device newCommandQueue];
    printf("GPU: %s\n\n", [[device name] UTF8String]);

    NSString *libPath = [NSString stringWithUTF8String:argv[1]];
    NSError *err;
    id<MTLLibrary> lib = [device newLibraryWithURL:[NSURL fileURLWithPath:libPath]
                                             error:&err];
    if (!lib) {
      fprintf(stderr, "Failed to load %s: %s\n", argv[1],
              [[err localizedDescription] UTF8String]);
      return 1;
    }

    std::string testName = (argc > 2) ? argv[2] : "all";
    std::vector<TestResult> results;

    auto run = [&](const char *name, TestResult(*fn)(id<MTLLibrary>)) {
      if (testName == "all" || testName == name)
        results.push_back(fn(lib));
    };

    run("vector_add",       test_vector_add);
    run("scale_constant",   test_scale_constant);
    run("math_sqrt",        test_math_sqrt);
    run("threadgroup_copy", test_threadgroup_copy);
    run("atomic_count",     test_atomic_count);
    run("saxpy",            test_saxpy);
    run("negate",           test_negate);
    run("clamp_test",       test_clamp);
    run("select_test",      test_select);
    run("iclamp_test",      test_iclamp);
    run("for_loop_test",    test_for_loop);
    run("isnan_check",      test_isnan_check);
    run("imin_imax_test",   test_imin_imax);

    // Print summary
    printf("─────────────────────────────────────────\n");
    printf("%-22s %s\n", "TEST", "RESULT");
    printf("─────────────────────────────────────────\n");
    int totalFail = 0;
    for (auto &r : results) {
      bool pass = (r.errors == 0);
      printf("%-22s %s", r.name.c_str(), pass ? "PASS" : "FAIL");
      if (!pass) printf("  (%d/%d mismatches)", r.errors, r.total);
      printf("\n");
      if (!pass) totalFail++;
    }
    printf("─────────────────────────────────────────\n");
    printf("%zu tests, %d passed, %d failed\n",
           results.size(), (int)results.size() - totalFail, totalFail);

    return totalFail == 0 ? 0 : 1;
  }
}

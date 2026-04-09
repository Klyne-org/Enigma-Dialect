#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        const int COUNT = 1024;

        // 1. Get the GPU device
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            fprintf(stderr, "Metal is not supported on this device\n");
            return 1;
        }
        printf("Using device: %s\n", [[device name] UTF8String]);

        // 2. Load the compiled shader library
        NSError* error = nil;
        NSString* libPath = @"kernel.metallib";
        if (argc > 1) {
            libPath = [NSString stringWithUTF8String:argv[1]];
        }
        NSURL* libURL = [NSURL fileURLWithPath:libPath];
        id<MTLLibrary> library = [device newLibraryWithURL:libURL error:&error];
        if (!library) {
            fprintf(stderr, "Failed to load metallib: %s\n",
                    [[error localizedDescription] UTF8String]);
            return 1;
        }

        // 3. Get the kernel function
        id<MTLFunction> function = [library newFunctionWithName:@"vector_add"];
        if (!function) {
            fprintf(stderr, "Failed to find kernel function 'vector_add'\n");
            return 1;
        }

        // 4. Create compute pipeline
        id<MTLComputePipelineState> pipeline =
            [device newComputePipelineStateWithFunction:function error:&error];
        if (!pipeline) {
            fprintf(stderr, "Failed to create pipeline: %s\n",
                    [[error localizedDescription] UTF8String]);
            return 1;
        }

        // 5. Prepare input data
        float* hostA = (float*)malloc(COUNT * sizeof(float));
        float* hostB = (float*)malloc(COUNT * sizeof(float));
        for (int i = 0; i < COUNT; i++) {
            hostA[i] = (float)i;
            hostB[i] = (float)(i * 2);
        }

        // 6. Create Metal buffers (shared memory — no CPU<->GPU copy on Apple Silicon!)
        id<MTLBuffer> bufA = [device newBufferWithBytes:hostA
                                      length:COUNT * sizeof(float)
                                      options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufB = [device newBufferWithBytes:hostB
                                      length:COUNT * sizeof(float)
                                      options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufOut = [device newBufferWithLength:COUNT * sizeof(float)
                                       options:MTLResourceStorageModeShared];

        // 7. Create command queue and command buffer
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];

        // 8. Set pipeline and buffers
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:bufA offset:0 atIndex:0];
        [encoder setBuffer:bufB offset:0 atIndex:1];
        [encoder setBuffer:bufOut offset:0 atIndex:2];

        // 9. Dispatch threads
        MTLSize gridSize = MTLSizeMake(COUNT, 1, 1);
        NSUInteger maxThreads = [pipeline maxTotalThreadsPerThreadgroup];
        MTLSize threadgroupSize = MTLSizeMake(
            MIN(maxThreads, (NSUInteger)COUNT), 1, 1);

        [encoder dispatchThreads:gridSize
            threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];

        // 10. Execute and wait
        [cmdBuf commit];
        [cmdBuf waitUntilCompleted];

        // 11. Read results
        float* result = (float*)[bufOut contents];
        printf("\nResults (first 10):\n");
        for (int i = 0; i < 10; i++) {
            printf("  %d + %d = %.0f\n", i, i * 2, result[i]);
        }

        // Verify
        int errors = 0;
        for (int i = 0; i < COUNT; i++) {
            float expected = hostA[i] + hostB[i];
            if (result[i] != expected) errors++;
        }
        printf("\nVerification: %s (%d errors out of %d)\n",
               errors == 0 ? "PASSED" : "FAILED", errors, COUNT);

        free(hostA);
        free(hostB);
    }
    return 0;
}

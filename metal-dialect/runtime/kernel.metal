#include <metal_stdlib>
using namespace metal;

kernel void vector_add(
    device float* v0 [[buffer(0)]],
    device float* v1 [[buffer(1)]],
    device float* v2 [[buffer(2)]],
    uint _tid [[thread_position_in_grid]]
) {
    uint v3 = _tid;
    float v4 = v0[v3];
    float v5 = v1[v3];
    float v6 = v4 + v5;
    v2[v3] = v6;
}


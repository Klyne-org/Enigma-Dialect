// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void vec_k(
module {
  enigma.kernel @vec_k(%a: memref<?xf32>, %b: memref<?xf32>) {
    %i  = enigma.thread_position_in_grid x
    %x  = memref.load %a[%i] : memref<?xf32>

    // CHECK: float3 {{.*}} = float3({{.*}}, {{.*}}, {{.*}});
    %v3 = enigma.vec_make %x, %x, %x : f32, f32, f32 -> vector<3xf32>

    // CHECK: float {{.*}} = {{v[0-9]+}}.x;
    %y  = enigma.vec_extract %v3, 0 : vector<3xf32> -> f32
    memref.store %y, %b[%i] : memref<?xf32>
    enigma.return
  }

  // CHECK-LABEL: kernel void vec_widths(
  enigma.kernel @vec_widths(%out: memref<?xf32>) {
    %i  = enigma.thread_position_in_grid x
    %a  = arith.constant 1.0 : f32
    %b  = arith.constant 2.0 : f32
    %c  = arith.constant 3.0 : f32
    %d  = arith.constant 4.0 : f32

    // CHECK: float2 {{.*}} = float2({{.*}}, {{.*}});
    %v2 = enigma.vec_make %a, %b : f32, f32 -> vector<2xf32>
    // CHECK: float4 {{.*}} = float4({{.*}}, {{.*}}, {{.*}}, {{.*}});
    %v4 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>

    // CHECK: float {{.*}} = {{v[0-9]+}}.y;
    %y2 = enigma.vec_extract %v2, 1 : vector<2xf32> -> f32
    // CHECK: float {{.*}} = {{v[0-9]+}}.w;
    %w4 = enigma.vec_extract %v4, 3 : vector<4xf32> -> f32

    %sum = arith.addf %y2, %w4 : f32
    memref.store %sum, %out[%i] : memref<?xf32>
    enigma.return
  }

  // CHECK-LABEL: kernel void vec_int(
  enigma.kernel @vec_int(%out: memref<?xi32>) {
    %i  = enigma.thread_position_in_grid x
    %a  = arith.constant 7 : i32
    %b  = arith.constant 8 : i32
    // CHECK: int2 {{.*}} = int2({{.*}}, {{.*}});
    %vi = enigma.vec_make %a, %b : i32, i32 -> vector<2xi32>
    // CHECK: int {{.*}} = {{v[0-9]+}}.y;
    %r  = enigma.vec_extract %vi, 1 : vector<2xi32> -> i32
    memref.store %r, %out[%i] : memref<?xi32>
    enigma.return
  }
}

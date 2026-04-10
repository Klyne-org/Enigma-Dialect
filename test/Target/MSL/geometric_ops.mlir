// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void geom_test(
module {
  enigma.kernel @geom_test(%buf: memref<?xf32>) {
    %v3 = arith.constant dense<[1.0, 0.0, 0.0]> : vector<3xf32>
    %n3 = arith.constant dense<[0.0, 1.0, 0.0]> : vector<3xf32>
    %eta = arith.constant 1.5 : f32

    // CHECK: dot(
    %d = enigma.dot %v3, %n3 : vector<3xf32> -> f32
    // CHECK: cross(
    %cr = enigma.cross %v3, %n3 : vector<3xf32>
    // CHECK: length(
    %l = enigma.length %v3 : vector<3xf32> -> f32
    // CHECK: distance(
    %dist = enigma.distance %v3, %n3 : vector<3xf32> -> f32
    // CHECK: normalize(
    %nm = enigma.normalize %v3 : vector<3xf32>
    // CHECK: reflect(
    %ref = enigma.reflect %v3, %n3 : vector<3xf32>
    // CHECK: refract(
    %rfr = enigma.refract %v3, %n3, %eta : vector<3xf32>, f32
    // CHECK: faceforward(
    %ff = enigma.faceforward %n3, %v3, %n3 : vector<3xf32>

    enigma.return
  }
}

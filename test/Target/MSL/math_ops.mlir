// RUN: enigma-translate --enigma-to-msl %s | FileCheck %s

// CHECK: #include <metal_stdlib>
// CHECK: using namespace metal;

// CHECK-LABEL: kernel void math_test(
module {
  enigma.kernel @math_test(%buf: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %buf[%id] : memref<?xf32>
    %w = memref.load %buf[%id] : memref<?xf32>

    // --- Unary ---
    // CHECK: abs(
    %a = enigma.abs %v : f32
    // CHECK: sin(
    %s = enigma.sin %v : f32
    // CHECK: cos(
    %c = enigma.cos %v : f32
    // CHECK: sqrt(
    %sq = enigma.sqrt %v : f32
    // CHECK: rsqrt(
    %rsq = enigma.rsqrt %v : f32
    // CHECK: exp(
    %ex = enigma.exp %v : f32
    // CHECK: log(
    %lg = enigma.log %v : f32
    // CHECK: saturate(
    %sat = enigma.saturate %v : f32
    // CHECK: fract(
    %fr = enigma.fract %v : f32
    // CHECK: tanh(
    %th = enigma.tanh %v : f32

    // --- Binary ---
    // CHECK: fmin(
    %mn = enigma.fmin %v, %w : f32
    // CHECK: fmax(
    %mx = enigma.fmax %v, %w : f32
    // CHECK: pow(
    %pw = enigma.pow %v, %w : f32

    // --- Ternary ---
    %z = memref.load %buf[%id] : memref<?xf32>
    // CHECK: clamp(
    %cl = enigma.clamp %v, %w, %z : f32
    // CHECK: fma(
    %fm = enigma.fma %v, %w, %z : f32
    // CHECK: mix(
    %mi = enigma.mix %v, %w, %z : f32
    // CHECK: smoothstep(
    %ss = enigma.smoothstep %v, %w, %z : f32

    memref.store %a, %buf[%id] : memref<?xf32>
    enigma.return
  }
}

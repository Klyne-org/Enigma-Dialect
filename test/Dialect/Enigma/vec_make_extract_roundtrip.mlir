// RUN: enigma-opt %s | enigma-opt | FileCheck %s

// CHECK-LABEL: func.func @roundtrip_vec_make_extract
func.func @roundtrip_vec_make_extract(%a: f32, %b: f32, %c: f32, %d: f32) -> f32 {
  // CHECK: enigma.vec_make %{{.*}}, %{{.*}} : f32, f32 -> vector<2xf32>
  %v2 = enigma.vec_make %a, %b : f32, f32 -> vector<2xf32>
  // CHECK: enigma.vec_make %{{.*}}, %{{.*}}, %{{.*}} : f32, f32, f32 -> vector<3xf32>
  %v3 = enigma.vec_make %a, %b, %c : f32, f32, f32 -> vector<3xf32>
  // CHECK: enigma.vec_make %{{.*}}, %{{.*}}, %{{.*}}, %{{.*}} : f32, f32, f32, f32 -> vector<4xf32>
  %v4 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
  // CHECK: enigma.vec_extract %{{.*}}, 0 : vector<3xf32> -> f32
  %y0 = enigma.vec_extract %v3, 0 : vector<3xf32> -> f32
  // CHECK: enigma.vec_extract %{{.*}}, 2 : vector<3xf32> -> f32
  %y2 = enigma.vec_extract %v3, 2 : vector<3xf32> -> f32
  return %y2 : f32
}

// CHECK-LABEL: func.func @roundtrip_vec_int
func.func @roundtrip_vec_int(%a: i32, %b: i32) -> i32 {
  // CHECK: enigma.vec_make %{{.*}}, %{{.*}} : i32, i32 -> vector<2xi32>
  %vi = enigma.vec_make %a, %b : i32, i32 -> vector<2xi32>
  // CHECK: enigma.vec_extract %{{.*}}, 1 : vector<2xi32> -> i32
  %y  = enigma.vec_extract %vi, 1 : vector<2xi32> -> i32
  return %y : i32
}

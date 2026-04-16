// RUN: enigma-opt %s -split-input-file -verify-diagnostics

// -----
// Wrong operand count: vector<3xf32> needs 3 scalar operands.
func.func @bad_count(%x: f32) {
  // expected-error @+1 {{'enigma.vec_make' op vec_make requires exactly 3}}
  %v = enigma.vec_make %x, %x : f32, f32 -> vector<3xf32>
  return
}

// -----
// Width > 4 is rejected.
func.func @bad_width(%x: f32) {
  // expected-error @+1 {{'enigma.vec_make' op vec_make result vector width must be 1, 2, 3, or 4}}
  %v = enigma.vec_make %x, %x, %x, %x, %x : f32, f32, f32, f32, f32 -> vector<5xf32>
  return
}

// -----
// Operand element type must match vector element type.
func.func @bad_elem_type(%x: f32, %y: i32) {
  // expected-error @+1 {{'enigma.vec_make' op vec_make operand #1}}
  %v = enigma.vec_make %x, %y : f32, i32 -> vector<2xf32>
  return
}

// -----
// Out-of-range lane index.
func.func @bad_lane(%x: vector<3xf32>) {
  // expected-error @+1 {{'enigma.vec_extract' op vec_extract lane 3 out of range}}
  %y = enigma.vec_extract %x, 3 : vector<3xf32> -> f32
  return
}

// -----
// Negative lane.
func.func @neg_lane(%x: vector<3xf32>) {
  // expected-error @+1 {{'enigma.vec_extract' op vec_extract lane -1 out of range}}
  %y = enigma.vec_extract %x, -1 : vector<3xf32> -> f32
  return
}

// -----
// Result element type mismatch.
func.func @bad_extract_type(%x: vector<3xf32>) {
  // expected-error @+1 {{'enigma.vec_extract' op vec_extract result type}}
  %y = enigma.vec_extract %x, 0 : vector<3xf32> -> i32
  return
}

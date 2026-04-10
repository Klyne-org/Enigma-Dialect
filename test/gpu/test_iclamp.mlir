// GPU test: out[i] = clamp(in[i], 0, 100)
// Input: in[i] = i - 50  (range: -50 to 973)
// Expect: out[i] = max(0, min(in[i], 100))
module {
  enigma.kernel @iclamp_test(%in: memref<?xi32>, %out: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xi32>
    %lo = arith.constant 0 : i32
    %hi = arith.constant 100 : i32
    %r = enigma.iclamp %v, %lo, %hi : i32
    memref.store %r, %out[%id] : memref<?xi32>
    enigma.return
  }
}

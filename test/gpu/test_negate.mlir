// GPU test: out[i] = -in[i]
// Input:  in[i] = i + 1
// Expect: out[i] = -(i + 1)
module {
  enigma.kernel @negate(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %neg = arith.negf %v : f32
    memref.store %neg, %out[%id] : memref<?xf32>
    enigma.return
  }
}

// GPU test: out[i] = weights[i] * 2.0  (constant address space read)
// Input:  weights[i] = i (constant buffer)
// Expect: out[i] = 2*i
module {
  enigma.kernel @scale_constant(%weights: memref<?xf32, 1>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %w = memref.load %weights[%id] : memref<?xf32, 1>
    %sum = arith.addf %w, %w : f32
    memref.store %sum, %out[%id] : memref<?xf32>
    enigma.return
  }
}

// GPU test: out[i] = sqrt(in[i])
// Input:  in[i] = (i+1)*(i+1)   i.e. 1, 4, 9, 16, 25, ...
// Expect: out[i] = i+1           i.e. 1, 2, 3, 4, 5, ...
module {
  enigma.kernel @math_sqrt(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %r = enigma.sqrt %v : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

// GPU test: out[i] = isnan(in[i]) ? 1.0 : 0.0
// Input: in[0]=NaN, in[1]=1.0, in[2]=inf, in[3]=0.0, ...
// Expect: out[0]=1, out[1]=0, out[2]=0, out[3]=0, ...
module {
  enigma.kernel @isnan_check(%in: memref<?xf32>, %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %v = memref.load %in[%id] : memref<?xf32>
    %is_nan = enigma.isnan %v : f32
    %one = arith.constant 1.0 : f32
    %zero = arith.constant 0.0 : f32
    %r = enigma.select %zero, %one, %is_nan : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

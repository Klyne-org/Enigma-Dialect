// GPU test: a[i] + b[i] = c[i]
// Input:  a[i] = i,  b[i] = 2*i
// Expect: c[i] = 3*i
module {
  enigma.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>, %c: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %va = memref.load %a[%id] : memref<?xf32>
    %vb = memref.load %b[%id] : memref<?xf32>
    %vc = arith.addf %va, %vb : f32
    memref.store %vc, %c[%id] : memref<?xf32>
    enigma.return
  }
}

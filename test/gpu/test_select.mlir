// GPU test: out[i] = select(a[i], b[i], cond[i])
// Input: a[i]=i, b[i]=100+i, cond[i] = (i%2==0) stored as i1 buffer trick
// We use a simpler test: a[i]=0, b[i]=i, cond=true → out[i]=i
module {
  enigma.kernel @select_test(%a: memref<?xf32>, %b: memref<?xf32>,
                             %out: memref<?xf32>) {
    %id = enigma.thread_position_in_grid x
    %va = memref.load %a[%id] : memref<?xf32>
    %vb = memref.load %b[%id] : memref<?xf32>
    %zero = arith.constant 0.0 : f32
    %cond = arith.cmpf uge, %vb, %zero : f32
    %r = enigma.select %va, %vb, %cond : f32
    memref.store %r, %out[%id] : memref<?xf32>
    enigma.return
  }
}

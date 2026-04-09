module {
  metal.kernel @vector_add(%a: memref<?xf32>, %b: memref<?xf32>, %out: memref<?xf32>) {
    %id = metal.thread_position_in_grid x
    %va = memref.load %a[%id] : memref<?xf32>
    %vb = memref.load %b[%id] : memref<?xf32>
    %sum = arith.addf %va, %vb : f32
    memref.store %sum, %out[%id] : memref<?xf32>
    metal.return
  }
}

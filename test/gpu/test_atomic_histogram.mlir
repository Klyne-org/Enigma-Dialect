// GPU test: count occurrences of value 0 using atomics
// Input:  data[i] = 0 for all i,  count[0] = 0
// Expect: count[0] = N  (every thread increments)
module {
  enigma.kernel @atomic_count(%data: memref<?xi32>, %count: memref<?xi32>) {
    %id = enigma.thread_position_in_grid x
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : i32
    %old = enigma.atomic_fetch_add %count[%c0], %c1 relaxed : memref<?xi32>, i32
    enigma.return
  }
}

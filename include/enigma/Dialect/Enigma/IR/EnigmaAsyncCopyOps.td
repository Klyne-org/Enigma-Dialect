//===- EnigmaAsyncCopyOps.td - Async copy (AIR intrinsics) -*- tablegen -*-===//
//
// Apple GPU simdgroup async copy. Each op maps 1-to-1 to an `air.*` intrinsic
// that the MSL emitter writes as a `__asm("...")` extern at translation time.
//
// Direction is encoded by op:
//   _d2t  = device     -> threadgroup
//   _t2d  = threadgroup -> device
//
// Events:
//   Each async copy returns an i64 SSA value that opaquely represents the
//   `thread _simdgroup_event_t*` returned by the AIR intrinsic. The wait op
//   takes a variadic list of these events and lowers to
//   `__metal_wait_simdgroup_events(N, events)`.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_ASYNC_COPY_OPS_TD
#define ENIGMA_ASYNC_COPY_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// 1D copies — flat contiguous blocks
// ============================================================================

def Enigma_AsyncCopy1dD2TOp : Enigma_Op<"async_copy_1d_d2t", []> {
  let summary = "Async copy 1D: device -> threadgroup (air.simdgroup_async_copy_1d.p3i8.p1i8)";
  let description = [{
    Schedules an asynchronous 1D copy of `num_elements` elements of element
    type `T` from a `device T*` source to a `threadgroup T*` destination.

    Returns an opaque event handle (i64) that must later be passed to
    `enigma.async_copy_wait` to synchronize.

    Emits the AIR intrinsic `air.simdgroup_async_copy_1d.p3i8.p1i8` via a
    raw `__asm("...")` extern at MSL translation time.
  }];
  let arguments = (ins
    AnyMemRef:$dst,          // threadgroup destination
    Index:$dst_offset,
    AnyMemRef:$src,          // device source
    Index:$src_offset,
    Index:$num_elements
  );
  let results = (outs I64:$event);
  let assemblyFormat = [{
    $dst `[` $dst_offset `]` `from` $src `[` $src_offset `]` `,` $num_elements
    attr-dict `:` type($dst) `,` type($src)
  }];
}

def Enigma_AsyncCopy1dT2DOp : Enigma_Op<"async_copy_1d_t2d", []> {
  let summary = "Async copy 1D: threadgroup -> device (air.simdgroup_async_copy_1d.p1i8.p3i8)";
  let description = [{
    Writeback direction: threadgroup -> device. See `async_copy_1d_d2t`.
    Emits `air.simdgroup_async_copy_1d.p1i8.p3i8`.
  }];
  let arguments = (ins
    AnyMemRef:$dst,          // device destination
    Index:$dst_offset,
    AnyMemRef:$src,          // threadgroup source
    Index:$src_offset,
    Index:$num_elements
  );
  let results = (outs I64:$event);
  let assemblyFormat = [{
    $dst `[` $dst_offset `]` `from` $src `[` $src_offset `]` `,` $num_elements
    attr-dict `:` type($dst) `,` type($src)
  }];
}

// ============================================================================
// 2D copies — rectangular tiles with row strides
// ============================================================================
//
// Lower to:
//   __metal_simdgroup_async_copy_2d(
//     sizeof(T), alignof(T),
//     dst, dst_elements_per_row, 1,
//     ulong2(tile_cols, tile_rows),
//     src, src_elements_per_row, 1,
//     ulong2(tile_cols, tile_rows),
//     long2(0), 0);
//
// The `tile_cols`, `tile_rows`, and elements-per-row are passed as Index
// SSA values so they may be runtime-dynamic.

def Enigma_AsyncCopy2dD2TOp : Enigma_Op<"async_copy_2d_d2t", []> {
  let summary = "Async copy 2D tile: device -> threadgroup (air.simdgroup_async_copy_2d.p3i8.p1i8)";
  let description = [{
    Asynchronously copies a `tile_cols x tile_rows` rectangle of element
    type `T` from `device` memory at row stride `src_elements_per_row` into
    `threadgroup` memory at row stride `dst_elements_per_row`, with arbitrary
    base offsets in flat elements on each side.

    Returns an opaque i64 event handle. Synchronize with `enigma.async_copy_wait`.

    Emits `air.simdgroup_async_copy_2d.p3i8.p1i8`.
  }];
  let arguments = (ins
    AnyMemRef:$dst,                      // threadgroup
    Index:$dst_offset,
    Index:$dst_elements_per_row,
    AnyMemRef:$src,                      // device
    Index:$src_offset,
    Index:$src_elements_per_row,
    Index:$tile_cols,
    Index:$tile_rows
  );
  let results = (outs I64:$event);
}

def Enigma_AsyncCopy2dT2DOp : Enigma_Op<"async_copy_2d_t2d", []> {
  let summary = "Async copy 2D tile: threadgroup -> device (air.simdgroup_async_copy_2d.p1i8.p3i8)";
  let description = [{
    Writeback direction for 2D async copy: threadgroup -> device.
    Emits `air.simdgroup_async_copy_2d.p1i8.p3i8`.
  }];
  let arguments = (ins
    AnyMemRef:$dst,                      // device
    Index:$dst_offset,
    Index:$dst_elements_per_row,
    AnyMemRef:$src,                      // threadgroup
    Index:$src_offset,
    Index:$src_elements_per_row,
    Index:$tile_cols,
    Index:$tile_rows
  );
  let results = (outs I64:$event);
}

// ============================================================================
// Wait — synchronize on a list of in-flight events
// ============================================================================

def Enigma_AsyncCopyWaitOp : Enigma_Op<"async_copy_wait", []> {
  let summary = "Block until the listed async-copy events complete (air.wait_simdgroup_events)";
  let description = [{
    Lowers to `__metal_wait_simdgroup_events(N, events)`.

    ```mlir
    enigma.async_copy_wait %ev0, %ev1
    ```
  }];
  let arguments = (ins Variadic<I64>:$events);
  let assemblyFormat = "$events attr-dict";
}

#endif // ENIGMA_ASYNC_COPY_OPS_TD

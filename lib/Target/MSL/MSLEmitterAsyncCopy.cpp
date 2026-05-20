// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Klyne Research

//===- MSLEmitterAsyncCopy.cpp - Apple GPU async copy emission ------------===//
//
// Emits MSL for the simdgroup async-copy ops by writing the AIR intrinsic
// string directly via `__asm("air.*")` extern declarations at translation
// time. This avoids any reliance on Apple's `<metal_simdgroup>` async copy
// surface (which is undocumented and shifts between toolchain versions).
//
// The full list of intrinsics wrapped:
//   air.simdgroup_async_copy_1d.p3i8.p1i8   device      -> threadgroup, 1D
//   air.simdgroup_async_copy_1d.p1i8.p3i8   threadgroup -> device,     1D
//   air.simdgroup_async_copy_2d.p3i8.p1i8   device      -> threadgroup, 2D
//   air.simdgroup_async_copy_2d.p1i8.p3i8   threadgroup -> device,     2D
//   air.wait_simdgroup_events               wait/sync
//
// The preamble (extern decls + templated wrappers) is emitted exactly once
// per kernel that uses any of these ops. The event SSA value (i64 in MLIR)
// is named like any other emitter value; the emitted MSL stores
// `thread _simdgroup_event_t*` and reinterpret_casts to ulong (i64) at the
// boundary so the type system is satisfied without exposing the opaque
// struct to other ops.
//
//===----------------------------------------------------------------------===//

#include "enigma/Target/MSL/MSLEmitter.h"
using namespace mlir;
using namespace enigma;

// Emit the file-scope preamble: opaque event struct + extern decls bound to
// AIR intrinsics via __asm("..."). Must be at file scope so the struct type
// has external linkage; emitting it inside a kernel body produces
// "type does not have linkage" errors from Apple's metal frontend.
//
// Only emits if *some* kernel in the module touches an async-copy op.
void MSLEmitter::emitAsyncCopyFileScopeIfNeeded(ModuleOp module) {
  bool needed = false;
  module.walk([&](Operation *op) {
    if (isa<AsyncCopy1dD2TOp>(op) || isa<AsyncCopy1dT2DOp>(op) ||
        isa<AsyncCopy2dD2TOp>(op) || isa<AsyncCopy2dT2DOp>(op) ||
        isa<AsyncCopyWaitOp>(op))
      needed = true;
  });
  if (!needed) return;

  os << "// ---- enigma async copy: AIR intrinsics (asm-bound) ----\n";
  os << "struct _enigma_async_event_t;\n";
  os << "thread _enigma_async_event_t* __enigma_async_copy_1d_d2t(\n"
        "    ulong elem_size, ulong elem_align,\n"
        "    threadgroup void* dst, const device void* src,\n"
        "    ulong num_elements)\n"
        "    __asm(\"air.simdgroup_async_copy_1d.p3i8.p1i8\");\n";
  os << "thread _enigma_async_event_t* __enigma_async_copy_1d_t2d(\n"
        "    ulong elem_size, ulong elem_align,\n"
        "    device void* dst, const threadgroup void* src,\n"
        "    ulong num_elements)\n"
        "    __asm(\"air.simdgroup_async_copy_1d.p1i8.p3i8\");\n";
  os << "thread _enigma_async_event_t* __enigma_async_copy_2d_d2t(\n"
        "    ulong elem_size, ulong elem_align,\n"
        "    threadgroup void* dst, ulong dst_elements_per_row, ulong, ulong2 dst_tile,\n"
        "    const device void* src, ulong src_elements_per_row, ulong, ulong2 src_tile,\n"
        "    long2 offset, int flags)\n"
        "    __asm(\"air.simdgroup_async_copy_2d.p3i8.p1i8\");\n";
  os << "thread _enigma_async_event_t* __enigma_async_copy_2d_t2d(\n"
        "    ulong elem_size, ulong elem_align,\n"
        "    device void* dst, ulong dst_elements_per_row, ulong, ulong2 dst_tile,\n"
        "    const threadgroup void* src, ulong src_elements_per_row, ulong, ulong2 src_tile,\n"
        "    long2 offset, int flags)\n"
        "    __asm(\"air.simdgroup_async_copy_2d.p1i8.p3i8\");\n";
  os << "void __enigma_wait_async_events(\n"
        "    int count, thread _enigma_async_event_t** events)\n"
        "    __asm(\"air.wait_simdgroup_events\");\n";
  os << "// ---- end enigma async copy preamble ----\n\n";
}

// Resolve the element type of a memref operand for sizeof/alignof.
static std::string elemTypeOf(MSLEmitter &e, Value v) {
  auto m = cast<MemRefType>(v.getType());
  return e.getTypeString(m.getElementType());
}

// Emit a single SSA name for the i64 event result. We hold the event in
// a `thread _enigma_async_event_t*` and reinterpret it as an i64 (ulong)
// whenever the dialect-level type says i64.
void MSLEmitter::emitAsyncCopy1dD2T(AsyncCopy1dD2TOp op) {
  std::string evName = "ev" + std::to_string(nextVarId());
  std::string evt = elemTypeOf(*this, op.getDst());
  assignName(op.getEvent(), evName);
  stream() << "    thread _enigma_async_event_t* " << evName
           << " = __enigma_async_copy_1d_d2t(\n"
           << "        sizeof(" << evt << "), alignof(" << evt << "),\n"
           << "        (threadgroup void*)(" << getName(op.getDst())
           << " + " << getName(op.getDstOffset()) << "),\n"
           << "        (const device void*)(" << getName(op.getSrc())
           << " + " << getName(op.getSrcOffset()) << "),\n"
           << "        ulong(" << getName(op.getNumElements()) << "));\n";
}

void MSLEmitter::emitAsyncCopy1dT2D(AsyncCopy1dT2DOp op) {
  std::string evName = "ev" + std::to_string(nextVarId());
  std::string evt = elemTypeOf(*this, op.getDst());
  assignName(op.getEvent(), evName);
  stream() << "    thread _enigma_async_event_t* " << evName
           << " = __enigma_async_copy_1d_t2d(\n"
           << "        sizeof(" << evt << "), alignof(" << evt << "),\n"
           << "        (device void*)(" << getName(op.getDst())
           << " + " << getName(op.getDstOffset()) << "),\n"
           << "        (const threadgroup void*)(" << getName(op.getSrc())
           << " + " << getName(op.getSrcOffset()) << "),\n"
           << "        ulong(" << getName(op.getNumElements()) << "));\n";
}

void MSLEmitter::emitAsyncCopy2dD2T(AsyncCopy2dD2TOp op) {
  std::string evName = "ev" + std::to_string(nextVarId());
  std::string evt = elemTypeOf(*this, op.getDst());
  assignName(op.getEvent(), evName);
  stream() << "    thread _enigma_async_event_t* " << evName
           << " = __enigma_async_copy_2d_d2t(\n"
           << "        sizeof(" << evt << "), alignof(" << evt << "),\n"
           << "        (threadgroup void*)(" << getName(op.getDst())
           << " + " << getName(op.getDstOffset()) << "),\n"
           << "        ulong(" << getName(op.getDstElementsPerRow()) << "), 1,\n"
           << "        ulong2(ulong(" << getName(op.getTileCols()) << "), ulong("
           << getName(op.getTileRows()) << ")),\n"
           << "        (const device void*)(" << getName(op.getSrc())
           << " + " << getName(op.getSrcOffset()) << "),\n"
           << "        ulong(" << getName(op.getSrcElementsPerRow()) << "), 1,\n"
           << "        ulong2(ulong(" << getName(op.getTileCols()) << "), ulong("
           << getName(op.getTileRows()) << ")),\n"
           << "        long2(0), 0);\n";
}

void MSLEmitter::emitAsyncCopy2dT2D(AsyncCopy2dT2DOp op) {
  std::string evName = "ev" + std::to_string(nextVarId());
  std::string evt = elemTypeOf(*this, op.getDst());
  assignName(op.getEvent(), evName);
  stream() << "    thread _enigma_async_event_t* " << evName
           << " = __enigma_async_copy_2d_t2d(\n"
           << "        sizeof(" << evt << "), alignof(" << evt << "),\n"
           << "        (device void*)(" << getName(op.getDst())
           << " + " << getName(op.getDstOffset()) << "),\n"
           << "        ulong(" << getName(op.getDstElementsPerRow()) << "), 1,\n"
           << "        ulong2(ulong(" << getName(op.getTileCols()) << "), ulong("
           << getName(op.getTileRows()) << ")),\n"
           << "        (const threadgroup void*)(" << getName(op.getSrc())
           << " + " << getName(op.getSrcOffset()) << "),\n"
           << "        ulong(" << getName(op.getSrcElementsPerRow()) << "), 1,\n"
           << "        ulong2(ulong(" << getName(op.getTileCols()) << "), ulong("
           << getName(op.getTileRows()) << ")),\n"
           << "        long2(0), 0);\n";
}

void MSLEmitter::emitAsyncCopyWait(AsyncCopyWaitOp op) {
  auto evs = op.getEvents();
  std::string arrName = "evs" + std::to_string(nextVarId());
  stream() << "    thread _enigma_async_event_t* " << arrName << "[]"
           << " = { ";
  for (unsigned i = 0; i < evs.size(); ++i) {
    if (i) stream() << ", ";
    stream() << getName(evs[i]);
  }
  stream() << " };\n";
  stream() << "    __enigma_wait_async_events(" << evs.size() << ", "
           << arrName << ");\n";
}

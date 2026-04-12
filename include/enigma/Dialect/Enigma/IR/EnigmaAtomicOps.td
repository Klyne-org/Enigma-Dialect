//===- EnigmaAtomicOps.td - Atomic operations --------------*- tablegen -*-===//
//
// Metal atomics operating on device or threadgroup memory. Each takes a
// memory_order attribute. Maps to atomic_*_explicit() in MSL.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_ATOMIC_OPS_TD
#define ENIGMA_ATOMIC_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"

def Enigma_AtomicLoadOp : Enigma_Op<"atomic_load", []> {
  let summary = "Atomic load from memory — atomic_load_explicit";
  let arguments = (ins AnyMemRef:$memref, Variadic<Index>:$indices,
                       Enigma_MemoryOrder:$memory_order);
  let results = (outs AnyTypeOf<[AnyInteger, AnyFloat]>:$result);
  let assemblyFormat = "$memref `[` $indices `]` $memory_order attr-dict `:` type($memref) `->` type($result)";
}

def Enigma_AtomicStoreOp : Enigma_Op<"atomic_store", []> {
  let summary = "Atomic store to memory — atomic_store_explicit";
  let arguments = (ins AnyTypeOf<[AnyInteger, AnyFloat]>:$value,
                       AnyMemRef:$memref, Variadic<Index>:$indices,
                       Enigma_MemoryOrder:$memory_order);
  let assemblyFormat = "$value `,` $memref `[` $indices `]` $memory_order attr-dict `:` type($value) `,` type($memref)";
}

def Enigma_AtomicExchangeOp : Enigma_Op<"atomic_exchange",
    [AllTypesMatch<["value", "result"]>]> {
  let summary = "Atomic exchange — swap value, return old";
  let arguments = (ins AnyMemRef:$memref, Variadic<Index>:$indices,
                       AnyTypeOf<[AnyInteger, AnyFloat]>:$value,
                       Enigma_MemoryOrder:$memory_order);
  let results = (outs AnyTypeOf<[AnyInteger, AnyFloat]>:$result);
  let assemblyFormat = "$memref `[` $indices `]` `,` $value $memory_order attr-dict `:` type($memref) `,` type($value)";
}

def Enigma_AtomicCompareExchangeWeakOp : Enigma_Op<"atomic_compare_exchange_weak",
    [AllTypesMatch<["expected", "desired"]>]> {
  let summary = "Atomic compare-and-swap (weak) — returns i1 success";
  let arguments = (ins AnyMemRef:$memref, Variadic<Index>:$indices,
                       AnyTypeOf<[AnyInteger, AnyFloat]>:$expected,
                       AnyTypeOf<[AnyInteger, AnyFloat]>:$desired,
                       Enigma_MemoryOrder:$success_order,
                       Enigma_MemoryOrder:$failure_order);
  let results = (outs I1:$result);
  let assemblyFormat = "$memref `[` $indices `]` `,` $expected `,` $desired $success_order $failure_order attr-dict `:` type($memref) `,` type($expected)";
}

// ============================================================================
// Fetch-and-modify atomics — shared base class
// ============================================================================

class Enigma_AtomicRMWOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [AllTypesMatch<["value", "result"]>]> {
  let summary = doc;
  let arguments = (ins AnyMemRef:$memref, Variadic<Index>:$indices,
                       AnyTypeOf<[AnyInteger, AnyFloat]>:$value,
                       Enigma_MemoryOrder:$memory_order);
  let results = (outs AnyTypeOf<[AnyInteger, AnyFloat]>:$result);
  let assemblyFormat = "$memref `[` $indices `]` `,` $value $memory_order attr-dict `:` type($memref) `,` type($value)";
}

def Enigma_AtomicFetchAddOp : Enigma_AtomicRMWOp<"atomic_fetch_add",
    "Atomic fetch-and-add — atomic_fetch_add_explicit">;
def Enigma_AtomicFetchSubOp : Enigma_AtomicRMWOp<"atomic_fetch_sub",
    "Atomic fetch-and-subtract — atomic_fetch_sub_explicit">;
def Enigma_AtomicFetchMinOp : Enigma_AtomicRMWOp<"atomic_fetch_min",
    "Atomic fetch-and-min — atomic_fetch_min_explicit">;
def Enigma_AtomicFetchMaxOp : Enigma_AtomicRMWOp<"atomic_fetch_max",
    "Atomic fetch-and-max — atomic_fetch_max_explicit">;
def Enigma_AtomicFetchAndOp : Enigma_AtomicRMWOp<"atomic_fetch_and",
    "Atomic fetch-and-bitwise-AND — atomic_fetch_and_explicit">;
def Enigma_AtomicFetchOrOp  : Enigma_AtomicRMWOp<"atomic_fetch_or",
    "Atomic fetch-and-bitwise-OR — atomic_fetch_or_explicit">;
def Enigma_AtomicFetchXorOp : Enigma_AtomicRMWOp<"atomic_fetch_xor",
    "Atomic fetch-and-bitwise-XOR — atomic_fetch_xor_explicit">;

#endif // ENIGMA_ATOMIC_OPS_TD

//===- EnigmaSimdOps.td - SIMD group operations ------------*- tablegen -*-===//
//
// Maps 1:1 to Metal simd_* intrinsics. All operate within a SIMD group
// (warp) of typically 32 threads on Apple GPUs.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_SIMD_OPS_TD
#define ENIGMA_SIMD_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Reductions — reduce a value across all SIMD lanes
// ============================================================================

class Enigma_SimdReductionOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_SimdSumOp     : Enigma_SimdReductionOp<"simd_sum",
    "SIMD group sum reduction — simd_sum(x)">;
def Enigma_SimdProductOp : Enigma_SimdReductionOp<"simd_product",
    "SIMD group product reduction — simd_product(x)">;
def Enigma_SimdMinOp     : Enigma_SimdReductionOp<"simd_min",
    "SIMD group minimum reduction — simd_min(x)">;
def Enigma_SimdMaxOp     : Enigma_SimdReductionOp<"simd_max",
    "SIMD group maximum reduction — simd_max(x)">;

// ============================================================================
// Bitwise reductions (integer only)
// ============================================================================

class Enigma_SimdBitwiseOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyInteger:$value);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_SimdAndOp : Enigma_SimdBitwiseOp<"simd_and",
    "SIMD group bitwise AND reduction">;
def Enigma_SimdOrOp  : Enigma_SimdBitwiseOp<"simd_or",
    "SIMD group bitwise OR reduction">;
def Enigma_SimdXorOp : Enigma_SimdBitwiseOp<"simd_xor",
    "SIMD group bitwise XOR reduction">;

// ============================================================================
// Prefix scans
// ============================================================================

class Enigma_SimdScanOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_SimdPrefixExclusiveSumOp
    : Enigma_SimdScanOp<"simd_prefix_exclusive_sum",
        "SIMD exclusive prefix sum">;
def Enigma_SimdPrefixInclusiveSumOp
    : Enigma_SimdScanOp<"simd_prefix_inclusive_sum",
        "SIMD inclusive prefix sum">;
def Enigma_SimdPrefixExclusiveProductOp
    : Enigma_SimdScanOp<"simd_prefix_exclusive_product",
        "SIMD exclusive prefix product">;
def Enigma_SimdPrefixInclusiveProductOp
    : Enigma_SimdScanOp<"simd_prefix_inclusive_product",
        "SIMD inclusive prefix product">;

// ============================================================================
// Shuffle — exchange data between SIMD lanes
// ============================================================================

def Enigma_SimdShuffleOp : Enigma_Op<"simd_shuffle",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read value from arbitrary SIMD lane";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$lane);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $lane attr-dict `:` type($value)";
}

def Enigma_SimdShuffleUpOp : Enigma_Op<"simd_shuffle_up",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read value from SIMD lane (current - delta)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$delta);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $delta attr-dict `:` type($value)";
}

def Enigma_SimdShuffleDownOp : Enigma_Op<"simd_shuffle_down",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read value from SIMD lane (current + delta)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$delta);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $delta attr-dict `:` type($value)";
}

def Enigma_SimdShuffleXorOp : Enigma_Op<"simd_shuffle_xor",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read value from SIMD lane (current XOR mask)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$mask);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $mask attr-dict `:` type($value)";
}

def Enigma_SimdBroadcastOp : Enigma_Op<"simd_broadcast",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Broadcast value from one SIMD lane to all lanes";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$lane);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $lane attr-dict `:` type($value)";
}

#endif // ENIGMA_SIMD_OPS_TD

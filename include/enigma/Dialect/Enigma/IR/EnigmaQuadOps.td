//===- EnigmaQuadOps.td - Quad group operations ------------*- tablegen -*-===//
//
// Quad group ops — work on 2x2 pixel quads (4 threads). Used primarily
// in fragment shaders for derivative-like operations.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_QUAD_OPS_TD
#define ENIGMA_QUAD_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// --- Reductions ---

class Enigma_QuadReductionOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_QuadSumOp     : Enigma_QuadReductionOp<"quad_sum",     "Quad group sum">;
def Enigma_QuadProductOp : Enigma_QuadReductionOp<"quad_product", "Quad group product">;
def Enigma_QuadMinOp     : Enigma_QuadReductionOp<"quad_min",     "Quad group minimum">;
def Enigma_QuadMaxOp     : Enigma_QuadReductionOp<"quad_max",     "Quad group maximum">;

// --- Bitwise reductions (integer only) ---

class Enigma_QuadBitwiseOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyInteger:$value);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_QuadAndOp : Enigma_QuadBitwiseOp<"quad_and", "Quad group bitwise AND">;
def Enigma_QuadOrOp  : Enigma_QuadBitwiseOp<"quad_or",  "Quad group bitwise OR">;
def Enigma_QuadXorOp : Enigma_QuadBitwiseOp<"quad_xor", "Quad group bitwise XOR">;

// --- Shuffles ---

def Enigma_QuadShuffleOp : Enigma_Op<"quad_shuffle",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read value from specific quad lane";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$lane);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $lane attr-dict `:` type($value)";
}

def Enigma_QuadBroadcastOp : Enigma_Op<"quad_broadcast",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Broadcast value from one quad lane to all";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$lane);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $lane attr-dict `:` type($value)";
}

def Enigma_QuadShuffleDownOp : Enigma_Op<"quad_shuffle_down",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read from quad lane (current + delta)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$delta);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $delta attr-dict `:` type($value)";
}

def Enigma_QuadShuffleUpOp : Enigma_Op<"quad_shuffle_up",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read from quad lane (current - delta)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$delta);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $delta attr-dict `:` type($value)";
}

def Enigma_QuadShuffleXorOp : Enigma_Op<"quad_shuffle_xor",
    [Pure, AllTypesMatch<["value", "result"]>]> {
  let summary = "Read from quad lane (current XOR mask)";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value, Index:$mask);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value `,` $mask attr-dict `:` type($value)";
}

// --- Prefix scans ---

class Enigma_QuadScanOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value);
  let results = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def Enigma_QuadPrefixExclusiveSumOp
    : Enigma_QuadScanOp<"quad_prefix_exclusive_sum", "Quad exclusive prefix sum">;
def Enigma_QuadPrefixInclusiveSumOp
    : Enigma_QuadScanOp<"quad_prefix_inclusive_sum", "Quad inclusive prefix sum">;

#endif // ENIGMA_QUAD_OPS_TD

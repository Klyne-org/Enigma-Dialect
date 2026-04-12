//===- EnigmaIntOps.td - Integer built-in intrinsics -------*- tablegen -*-===//
//
// Metal integer math functions: bit manipulation, saturating arithmetic,
// and other integer-specific intrinsics.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_INT_OPS_TD
#define ENIGMA_INT_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/BuiltinAttributes.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Unary integer ops
// ============================================================================

class Enigma_UnaryIntOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyInteger:$input);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$input attr-dict `:` type($input)";
}

def Enigma_PopcountOp    : Enigma_UnaryIntOp<"popcount",
    "Population count — number of set bits">;
def Enigma_ClzOp         : Enigma_UnaryIntOp<"clz",
    "Count leading zeros">;
def Enigma_CtzOp         : Enigma_UnaryIntOp<"ctz",
    "Count trailing zeros">;
def Enigma_ReverseBitsOp : Enigma_UnaryIntOp<"reverse_bits",
    "Reverse bit order">;
def Enigma_AbsDiffUnaryOp : Enigma_UnaryIntOp<"abs_diff_unary",
    "Absolute value (integer)">;

// ============================================================================
// Binary integer ops
// ============================================================================

class Enigma_BinaryIntOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, SameOperandsAndResultType]> {
  let summary = doc;
  let arguments = (ins AnyInteger:$lhs, AnyInteger:$rhs);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs)";
}

def Enigma_AbsDiffBinOp : Enigma_BinaryIntOp<"abs_diff",
    "Absolute difference |a - b|">;
def Enigma_AddSatOp     : Enigma_BinaryIntOp<"add_sat",
    "Saturating add — clamps on overflow">;
def Enigma_SubSatOp     : Enigma_BinaryIntOp<"sub_sat",
    "Saturating subtract — clamps on underflow">;
def Enigma_MulHiOp      : Enigma_BinaryIntOp<"mul_hi",
    "High bits of multiplication">;
def Enigma_RotateOp     : Enigma_BinaryIntOp<"rotate",
    "Bitwise rotate left">;

// ============================================================================
// Bit extraction/insertion
// ============================================================================

def Enigma_ExtractBitsOp : Enigma_Op<"extract_bits", [Pure, SameOperandsAndResultType]> {
  let summary = "Extract bits from integer — extract_bits(x, offset, bits)";
  let arguments = (ins AnyInteger:$value, I32Attr:$offset, I32Attr:$bits);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$value $offset $bits attr-dict `:` type($value)";
}

def Enigma_InsertBitsOp : Enigma_Op<"insert_bits", [Pure, SameOperandsAndResultType]> {
  let summary = "Insert bits into integer — insert_bits(base, insert, offset, bits)";
  let arguments = (ins AnyInteger:$base, AnyInteger:$insert,
                       I32Attr:$offset, I32Attr:$bits);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$base `,` $insert $offset $bits attr-dict `:` type($base)";
}

// ============================================================================
// Ternary integer ops
// ============================================================================

def Enigma_MadSatOp : Enigma_Op<"mad_sat", [Pure, SameOperandsAndResultType]> {
  let summary = "Multiply-add with saturation — mad_sat(a, b, c) = clamp(a*b+c)";
  let arguments = (ins AnyInteger:$a, AnyInteger:$b, AnyInteger:$c);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$a `,` $b `,` $c attr-dict `:` type($a)";
}

#endif // ENIGMA_INT_OPS_TD

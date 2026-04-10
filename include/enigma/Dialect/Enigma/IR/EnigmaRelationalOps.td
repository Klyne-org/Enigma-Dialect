//===- EnigmaRelationalOps.td - Comparison + select ops ----*- tablegen -*-===//
//
// MSL relational functions: isnan, isinf, isfinite, signbit, isnormal, select.
// Also integer min/max/clamp (from <metal_integer>).
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_RELATIONAL_OPS_TD
#define ENIGMA_RELATIONAL_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Float comparison predicates — return i1
// ============================================================================

class Enigma_FloatPredicateOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure]> {
  let summary = doc;
  let arguments = (ins AnyFloat:$input);
  let results = (outs I1:$result);
  let assemblyFormat = "$input attr-dict `:` type($input)";
}

def Enigma_IsNanOp     : Enigma_FloatPredicateOp<"isnan",     "Test if value is NaN">;
def Enigma_IsInfOp     : Enigma_FloatPredicateOp<"isinf",     "Test if value is infinity">;
def Enigma_IsFiniteOp  : Enigma_FloatPredicateOp<"isfinite",  "Test if value is finite">;
def Enigma_SignbitOp   : Enigma_FloatPredicateOp<"signbit",   "Test if sign bit is set">;
def Enigma_IsNormalOp  : Enigma_FloatPredicateOp<"isnormal",  "Test if value is normal (not denorm/zero/nan/inf)">;

// ============================================================================
// Select — branchless conditional
// ============================================================================

def Enigma_SelectOp : Enigma_Op<"select",
    [Pure, AllTypesMatch<["false_val", "true_val", "result"]>]> {
  let summary = "Branchless select — select(a, b, cond) = cond ? b : a";
  let arguments = (ins AnyType:$false_val, AnyType:$true_val, I1:$condition);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$false_val `,` $true_val `,` $condition attr-dict `:` type($result)";
}

// ============================================================================
// Integer min / max / clamp (from <metal_integer>)
// ============================================================================

def Enigma_IMinOp : Enigma_Op<"imin", [Pure, SameOperandsAndResultType]> {
  let summary = "Integer minimum — min(x, y)";
  let arguments = (ins AnyInteger:$lhs, AnyInteger:$rhs);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs)";
}

def Enigma_IMaxOp : Enigma_Op<"imax", [Pure, SameOperandsAndResultType]> {
  let summary = "Integer maximum — max(x, y)";
  let arguments = (ins AnyInteger:$lhs, AnyInteger:$rhs);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs)";
}

def Enigma_IClampOp : Enigma_Op<"iclamp", [Pure, SameOperandsAndResultType]> {
  let summary = "Integer clamp — clamp(x, lo, hi)";
  let arguments = (ins AnyInteger:$value, AnyInteger:$lo, AnyInteger:$hi);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$value `,` $lo `,` $hi attr-dict `:` type($value)";
}

#endif // ENIGMA_RELATIONAL_OPS_TD

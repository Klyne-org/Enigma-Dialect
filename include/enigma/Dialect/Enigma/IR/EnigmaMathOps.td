//===- EnigmaMathOps.td - GPU math built-ins ---------------*- tablegen -*-===//
//
// Metal <metal_math> built-ins. Each supports a precision attribute
// (default/fast/precise) controlling accuracy vs throughput.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_MATH_OPS_TD
#define ENIGMA_MATH_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Unary float math — f(x) -> y
// ============================================================================

class Enigma_UnaryMathOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, AllTypesMatch<["input", "result"]>]> {
  let summary = doc;
  let arguments = (ins AnyFloat:$input,
                       DefaultValuedAttr<Enigma_MathPrecision,
                         "::enigma::MathPrecision::default_precision">:$precision);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$input attr-dict `:` type($input)";
}

def Enigma_AbsOp      : Enigma_UnaryMathOp<"abs",      "Absolute value (fabs)">;
def Enigma_CeilOp     : Enigma_UnaryMathOp<"ceil",     "Ceiling">;
def Enigma_FloorOp    : Enigma_UnaryMathOp<"floor",    "Floor">;
def Enigma_RoundOp    : Enigma_UnaryMathOp<"round",    "Round to nearest even">;
def Enigma_TruncOp    : Enigma_UnaryMathOp<"trunc",    "Truncate toward zero">;
def Enigma_SignOp     : Enigma_UnaryMathOp<"sign",     "Sign of value (-1/0/+1)">;
def Enigma_SaturateOp : Enigma_UnaryMathOp<"saturate", "Clamp to [0.0, 1.0]">;
def Enigma_FractOp    : Enigma_UnaryMathOp<"fract",    "Fractional part">;
def Enigma_SqrtOp     : Enigma_UnaryMathOp<"sqrt",     "Square root">;
def Enigma_RsqrtOp    : Enigma_UnaryMathOp<"rsqrt",    "Reciprocal square root (1/sqrt)">;
def Enigma_ExpOp      : Enigma_UnaryMathOp<"exp",      "Base-e exponential">;
def Enigma_Exp2Op     : Enigma_UnaryMathOp<"exp2",     "Base-2 exponential">;
def Enigma_LogOp      : Enigma_UnaryMathOp<"log",      "Natural logarithm">;
def Enigma_Log2Op     : Enigma_UnaryMathOp<"log2",     "Base-2 logarithm">;
def Enigma_Log10Op    : Enigma_UnaryMathOp<"log10",    "Base-10 logarithm">;
def Enigma_SinOp      : Enigma_UnaryMathOp<"sin",      "Sine">;
def Enigma_CosOp      : Enigma_UnaryMathOp<"cos",      "Cosine">;
def Enigma_TanOp      : Enigma_UnaryMathOp<"tan",      "Tangent">;
def Enigma_AsinOp     : Enigma_UnaryMathOp<"asin",     "Arc sine">;
def Enigma_AcosOp     : Enigma_UnaryMathOp<"acos",     "Arc cosine">;
def Enigma_AtanOp     : Enigma_UnaryMathOp<"atan",     "Arc tangent">;
def Enigma_SinhOp     : Enigma_UnaryMathOp<"sinh",     "Hyperbolic sine">;
def Enigma_CoshOp     : Enigma_UnaryMathOp<"cosh",     "Hyperbolic cosine">;
def Enigma_TanhOp     : Enigma_UnaryMathOp<"tanh",     "Hyperbolic tangent">;

// ============================================================================
// Binary float math — f(x, y) -> z
// ============================================================================

class Enigma_BinaryMathOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, AllTypesMatch<["lhs", "rhs", "result"]>]> {
  let summary = doc;
  let arguments = (ins AnyFloat:$lhs, AnyFloat:$rhs,
                       DefaultValuedAttr<Enigma_MathPrecision,
                         "::enigma::MathPrecision::default_precision">:$precision);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs)";
}

def Enigma_FminOp     : Enigma_BinaryMathOp<"fmin",     "Floating-point minimum">;
def Enigma_FmaxOp     : Enigma_BinaryMathOp<"fmax",     "Floating-point maximum">;
def Enigma_PowOp      : Enigma_BinaryMathOp<"pow",      "Power (x^y)">;
def Enigma_FmodOp     : Enigma_BinaryMathOp<"fmod",     "Floating-point modulus">;
def Enigma_Atan2Op    : Enigma_BinaryMathOp<"atan2",    "Two-argument arc tangent">;
def Enigma_StepOp     : Enigma_BinaryMathOp<"step",     "Step function (edge, x)">;
def Enigma_CopysignOp : Enigma_BinaryMathOp<"copysign", "Copy sign of y to x">;

// ============================================================================
// Ternary float math — f(a, b, c) -> d
// ============================================================================

class Enigma_TernaryMathOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure, AllTypesMatch<["a", "b", "c", "result"]>]> {
  let summary = doc;
  let arguments = (ins AnyFloat:$a, AnyFloat:$b, AnyFloat:$c,
                       DefaultValuedAttr<Enigma_MathPrecision,
                         "::enigma::MathPrecision::default_precision">:$precision);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$a `,` $b `,` $c attr-dict `:` type($a)";
}

def Enigma_ClampOp      : Enigma_TernaryMathOp<"clamp",      "Clamp value to [min, max]">;
def Enigma_FmaOp        : Enigma_TernaryMathOp<"fma",        "Fused multiply-add (a*b+c)">;
def Enigma_MixOp        : Enigma_TernaryMathOp<"mix",        "Linear interpolation (lerp)">;
def Enigma_SmoothstepOp : Enigma_TernaryMathOp<"smoothstep", "Hermite interpolation">;

#endif // ENIGMA_MATH_OPS_TD

//===- EnigmaGeomOps.td - Geometric / vector operations ----*- tablegen -*-===//
//
// Metal geometric functions operating on MLIR vector types.
// dot, cross, length, distance, normalize, reflect, refract, faceforward.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_GEOM_OPS_TD
#define ENIGMA_GEOM_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_DotOp : Enigma_Op<"dot",
    [Pure, AllTypesMatch<["lhs", "rhs"]>]> {
  let summary = "Dot product of two vectors — dot(a, b)";
  let arguments = (ins AnyVectorOfNonZeroRank:$lhs, AnyVectorOfNonZeroRank:$rhs);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs) `->` type($result)";
}

def Enigma_CrossOp : Enigma_Op<"cross", [Pure, SameOperandsAndResultType]> {
  let summary = "Cross product of two 3D vectors — cross(a, b)";
  let arguments = (ins AnyVectorOfNonZeroRank:$lhs, AnyVectorOfNonZeroRank:$rhs);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs)";
}

def Enigma_LengthOp : Enigma_Op<"length", [Pure]> {
  let summary = "Euclidean length of vector — length(v)";
  let arguments = (ins AnyVectorOfNonZeroRank:$input);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `->` type($result)";
}

def Enigma_DistanceOp : Enigma_Op<"distance",
    [Pure, AllTypesMatch<["lhs", "rhs"]>]> {
  let summary = "Euclidean distance between two points — distance(a, b)";
  let arguments = (ins AnyVectorOfNonZeroRank:$lhs, AnyVectorOfNonZeroRank:$rhs);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs) `->` type($result)";
}

def Enigma_NormalizeOp : Enigma_Op<"normalize",
    [Pure, AllTypesMatch<["input", "result"]>]> {
  let summary = "Normalize vector to unit length — normalize(v)";
  let arguments = (ins AnyVectorOfNonZeroRank:$input);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$input attr-dict `:` type($input)";
}

def Enigma_ReflectOp : Enigma_Op<"reflect",
    [Pure, AllTypesMatch<["incident", "normal", "result"]>]> {
  let summary = "Reflect incident vector about normal — reflect(I, N)";
  let arguments = (ins AnyVectorOfNonZeroRank:$incident, AnyVectorOfNonZeroRank:$normal);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$incident `,` $normal attr-dict `:` type($incident)";
}

def Enigma_RefractOp : Enigma_Op<"refract",
    [Pure, AllTypesMatch<["incident", "normal", "result"]>]> {
  let summary = "Refract through surface — refract(I, N, eta)";
  let arguments = (ins AnyVectorOfNonZeroRank:$incident, AnyVectorOfNonZeroRank:$normal, AnyFloat:$eta);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$incident `,` $normal `,` $eta attr-dict `:` type($incident) `,` type($eta)";
}

def Enigma_FaceforwardOp : Enigma_Op<"faceforward",
    [Pure, AllTypesMatch<["n", "incident", "nref", "result"]>]> {
  let summary = "Flip normal to face incident direction — faceforward(N, I, Nref)";
  let arguments = (ins AnyVectorOfNonZeroRank:$n, AnyVectorOfNonZeroRank:$incident, AnyVectorOfNonZeroRank:$nref);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$n `,` $incident `,` $nref attr-dict `:` type($n)";
}

#endif // ENIGMA_GEOM_OPS_TD

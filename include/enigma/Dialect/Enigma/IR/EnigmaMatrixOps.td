//===- EnigmaMatrixOps.td - Matrix operations --------------*- tablegen -*-===//
//
// MSL matrix types (float4x4 etc), construction, determinant, transpose.
// Simdgroup matrix ops for Apple GPU matrix hardware (8x8 tiles).
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_MATRIX_OPS_TD
#define ENIGMA_MATRIX_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Standard matrix operations (float4x4 etc)
// We model matrices as vector<CxRxf32> in MLIR for now.
// ============================================================================

def Enigma_MatMakeOp : Enigma_Op<"mat_make", [Pure]> {
  let summary = "Assemble a matrix from column vectors";
  let description = [{
    Build a `vector<CxRx{f|i}>` matrix from C column operands, each of type
    `vector<Rx{f|i}>`. C and R must each be in {2,3,4} (MSL native matrix
    widths). Lowers to `floatCxR(col0, col1, ...)` in MSL.
  }];
  let arguments = (ins Variadic<AnyVectorOfNonZeroRank>:$columns);
  let results   = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat =
      "$columns attr-dict `:` type($columns) `->` type($result)";
  let hasVerifier = 1;
}

def Enigma_MatMulOp : Enigma_Op<"matmul", [Pure]> {
  let summary = "Matrix multiply — A * B";
  let arguments = (ins AnyType:$lhs, AnyType:$rhs);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)";
}

def Enigma_TransposeOp : Enigma_Op<"transpose", [Pure]> {
  let summary = "Matrix transpose";
  let arguments = (ins AnyType:$input);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `->` type($result)";
}

def Enigma_DeterminantOp : Enigma_Op<"determinant", [Pure]> {
  let summary = "Matrix determinant (square matrices only)";
  let arguments = (ins AnyType:$input);
  let results = (outs AnyFloat:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `->` type($result)";
}

// ============================================================================
// Simdgroup matrix ops (Apple GPU, 8x8 tiles)
// ============================================================================

def Enigma_SimdgroupMatLoadOp : Enigma_Op<"simdgroup_matrix_load", []> {
  let summary = "Load 8x8 matrix tile from device/threadgroup memory";
  let arguments = (ins AnyMemRef:$src, Index:$elements_per_row);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$src `,` $elements_per_row attr-dict `:` type($src) `->` type($result)";
}

def Enigma_SimdgroupMatStoreOp : Enigma_Op<"simdgroup_matrix_store", []> {
  let summary = "Store 8x8 matrix tile to device/threadgroup memory";
  let arguments = (ins AnyType:$matrix, AnyMemRef:$dst, Index:$elements_per_row);
  let assemblyFormat = "$matrix `,` $dst `,` $elements_per_row attr-dict `:` type($matrix) `,` type($dst)";
}

def Enigma_SimdgroupMatMulAccOp : Enigma_Op<"simdgroup_multiply_accumulate", [Pure]> {
  let summary = "Simdgroup matrix multiply-accumulate: d = a * b + c";
  let arguments = (ins AnyType:$a, AnyType:$b, AnyType:$c);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$a `,` $b `,` $c attr-dict `:` type($a) `,` type($b) `,` type($c) `->` type($result)";
}

def Enigma_MakeFilledSimdgroupMatOp : Enigma_Op<"make_filled_simdgroup_matrix", [Pure]> {
  let summary = "Create 8x8 simdgroup matrix filled with a value";
  let arguments = (ins AnyTypeOf<[AnyFloat, AnyInteger]>:$value);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$value attr-dict `:` type($value) `->` type($result)";
}

#endif // ENIGMA_MATRIX_OPS_TD

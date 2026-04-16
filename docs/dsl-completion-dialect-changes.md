# Dialect changes for DSL completion

What landed in the Enigma dialect (wheel `enigma_dialect-0.1.0`) to unblock
the Python DSL features listed in the DSL repo's blocked-features doc.
Each section below shows the tablegen, the MSL the emitter produces, a
FileCheck-style example, and the concrete DSL-side integration to re-enable
the feature.

The features that were already shipped in the dialect before this round
(vec_make / vec_extract, texture_read/write/sample, simdgroup_matrix_*,
make_filled_simdgroup_matrix, scf.for / scf.if) are included at the bottom
for completeness — for those, the remaining work is DSL-side only.

---

## §1 Vector construction — `vec_make`, `vec_extract`

Already in the dialect (no change in this round; listed because the DSL
punch list flagged it as blocked).

### Tablegen — [EnigmaGeomOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaGeomOps.td)

```tablegen
def Enigma_VecMakeOp : Enigma_Op<"vec_make", [Pure]> {
  let arguments = (ins Variadic<AnyTypeOf<[AnyFloat, AnyInteger]>>:$elems);
  let results   = (outs AnyVectorOfNonZeroRank:$result);
  let hasVerifier = 1;
}
def Enigma_VecExtractOp : Enigma_Op<"vec_extract", [Pure]> {
  let arguments = (ins AnyVectorOfNonZeroRank:$input, I32Attr:$lane);
  let results   = (outs AnyTypeOf<[AnyFloat, AnyInteger]>:$result);
  let hasVerifier = 1;
}
```

Verifier rules (see [EnigmaDialect.cpp](../lib/Dialect/Enigma/IR/EnigmaDialect.cpp)):
- `vec_make`: width in {1,2,3,4}, operand count matches width, all operand
  types match result element type.
- `vec_extract`: `lane` in `[0, N)`, result type matches input element type.

### MSL emission

```mlir
%v = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
%y = enigma.vec_extract %v, 2 : vector<4xf32> -> f32
```

emits:

```msl
float4 v = float4(a, b, c, d);
float  y = v.z;
```

### DSL integration (unblocks `make_float2/3/4`, `vec_extract`, `dot`, `length`, `distance`, `cross`, `normalize`, `reflect`, `refract`, `faceforward`, and all `pack_*`/`unpack_*` ops)

Remove the `NotImplementedError` at `vec_make` in
`enigma/compiler/mlir_emitter.py` and dispatch to
`mlir.dialects.enigma.VecMakeOp`:

```python
from mlir import ir
from mlir.dialects import enigma

elem_ty = ir.F32Type.get()
vec_ty  = ir.VectorType.get([n], elem_ty)
op = enigma.VecMakeOp(vec_ty, list_of_scalar_mlir_values)

lane_attr = ir.IntegerAttr.get(ir.IntegerType.get_signless(32), lane)
extract   = enigma.VecExtractOp(elem_ty, vec_val, lane_attr)
```

All geometric ops (`dot`, `length`, `normalize`, …) are already in the
dialect and take vector operands, so once the DSL can produce vectors they
work unchanged.

---

## §2 Matrix construction — `mat_make` (NEW in this round)

### Rationale

Before this round `enigma.matmul` / `transpose` / `determinant` existed but
there was no way to **construct** a matrix from Python scalars, so
end-to-end compilation failed at the first use. We now model matrices as
2-D MLIR vectors (`vector<CxRxf32>` → MSL `floatCxR`) and added
`enigma.mat_make` as the matrix-constructor counterpart of `vec_make`.

### Tablegen — [EnigmaMatrixOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaMatrixOps.td)

```tablegen
def Enigma_MatMakeOp : Enigma_Op<"mat_make", [Pure]> {
  let summary = "Assemble a matrix from column vectors";
  let arguments = (ins Variadic<AnyVectorOfNonZeroRank>:$columns);
  let results   = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat =
      "$columns attr-dict `:` type($columns) `->` type($result)";
  let hasVerifier = 1;
}
```

Verifier rules (see `MatMakeOp::verify` in
[EnigmaDialect.cpp](../lib/Dialect/Enigma/IR/EnigmaDialect.cpp)):
- Result must be a 2-D vector `vector<CxRxT>` with C ∈ {2,3,4} and R ∈ {2,3,4}.
- Exactly C column operands.
- Every column must be `vector<RxT>` with the same element type T as the result.

### MSL emission

`getTypeString` now maps `vector<CxRxf32>` → `floatCxR` (and similarly
`half`, `int`, etc.). `emitMatMake` lowers the op to an MSL
matrix-constructor call. See
[MSLEmitterCore.cpp](../lib/Target/MSL/MSLEmitterCore.cpp) and
[MSLEmitterMatrix.cpp](../lib/Target/MSL/MSLEmitterMatrix.cpp).

```mlir
%col0 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
%col1 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
%col2 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
%col3 = enigma.vec_make %a, %b, %c, %d : f32, f32, f32, f32 -> vector<4xf32>
%M    = enigma.mat_make %col0, %col1, %col2, %col3
        : vector<4xf32>, vector<4xf32>, vector<4xf32>, vector<4xf32>
        -> vector<4x4xf32>
%T    = enigma.transpose %M : vector<4x4xf32> -> vector<4x4xf32>
%d    = enigma.determinant %T : vector<4x4xf32> -> f32
```

emits (verified by `xcrun metal -c`):

```msl
float4   col0 = float4(a, b, c, d);
float4   col1 = float4(a, b, c, d);
float4   col2 = float4(a, b, c, d);
float4   col3 = float4(a, b, c, d);
float4x4 M    = float4x4(col0, col1, col2, col3);
float4x4 T    = transpose(M);
float    d    = determinant(T);
```

### FileCheck pattern

```mlir
// CHECK: float4x4 {{.*}} = float4x4({{.*}}, {{.*}}, {{.*}}, {{.*}});
// CHECK: float4x4 {{.*}} = transpose({{.*}});
// CHECK: float {{.*}} = determinant({{.*}});
```

### DSL integration (unblocks `matmul`, `transpose`, `determinant`, and any DSL `Matrix`/`float4x4` constructor)

Build matrices column-by-column out of `vec_make` calls, then feed into
`enigma.MatMakeOp`. `MatMul` / `Transpose` / `Determinant` ops already exist
and accept the 2-D vector type directly.

```python
from mlir import ir
from mlir.dialects import enigma

f32   = ir.F32Type.get()
colTy = ir.VectorType.get([R], f32)        # vector<Rxf32>
matTy = ir.VectorType.get([C, R], f32)     # vector<CxRxf32>  → MSL floatCxR

# Build C columns from scalars (lists of mlir.Value).
cols = [enigma.VecMakeOp(colTy, scalars_for_col).result for scalars_for_col in column_scalars]

# Build the matrix.
M = enigma.MatMakeOp(matTy, cols).result

# Ops already in the dialect:
MT = enigma.TransposeOp(matTy, M).result
d  = enigma.DeterminantOp(f32, MT).result
MN = enigma.MatMulOp(matTy, M, MT).result
```

MSL restricts C, R to {2, 3, 4}. `mat_make` verifies both at parse time, so
bad widths fail loudly in the dialect rather than silently producing
garbage MSL.

---

## §3 Function constants — file-scope hoisting (FIXED in this round)

### Rationale

`[[function_constant(N)]]` is a **file-scope** declaration in MSL. The
previous emitter placed it inside the kernel body, which `xcrun metal -c`
rejects. The dialect op stays the same; emission changed.

### Tablegen — unchanged [EnigmaControlFlowOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaControlFlowOps.td)

```tablegen
def Enigma_FunctionConstantOp : Enigma_Op<"function_constant", [Pure]> {
  let arguments = (ins I32Attr:$index);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$index attr-dict `:` type($result)";
}
```

### Emission model

`translateToMSL` now calls `emitFunctionConstants(module)` after the
preamble and before emitting any kernel. That pass walks every
`FunctionConstantOp` in the module, assigns every result SSA value the
stable name `fc<N>`, and emits **one** file-scope declaration per unique
index. `emitFunctionConstant` at the body site is a no-op. See
[MSLEmitterCore.cpp](../lib/Target/MSL/MSLEmitterCore.cpp) and
[MSLEmitterControlFlow.cpp](../lib/Target/MSL/MSLEmitterControlFlow.cpp).

The same `function_constant N` used from multiple kernels emits exactly one
file-scope declaration and is shared across kernels.

### MSL emission

```mlir
enigma.kernel @k1(%A: memref<4xf32, 0>) {
  %alpha = enigma.function_constant 0 : f32
  %beta  = enigma.function_constant 1 : f32
  %sum = arith.addf %alpha, %beta : f32
  ...
}
enigma.kernel @k2(%B: memref<4xf32, 0>) {
  %alpha = enigma.function_constant 0 : f32         // same index as k1
  ...
}
```

emits (verified by `xcrun metal -c`):

```msl
#include <metal_stdlib>
using namespace metal;

constant float fc0 [[function_constant(0)]];
constant float fc1 [[function_constant(1)]];

kernel void k1(device float* v0 [[buffer(0)]]) {
    float v1 = fc0 + fc1;
    ...
}

kernel void k2(device float* v3 [[buffer(0)]]) {
    ...                      // references fc0
}
```

### FileCheck pattern

```mlir
// CHECK:      constant float fc0 [[function_constant(0)]];
// CHECK-NEXT: constant float fc1 [[function_constant(1)]];
// CHECK:      kernel void
// CHECK-NOT:  [[function_constant(0)]]          // no body-site duplicate
```

### DSL integration

No DSL change is required — `enigma.function_constant(index=N, dtype=...)`
on the DSL side already lowers to `enigma.FunctionConstantOp`. The
previously generated `.metal` file now compiles with `xcrun metal -c`
because the declaration is at file scope.

---

## §4 Simdgroup matrix ops

Already wired in the dialect and dispatched from the MSL emitter:

- `enigma.simdgroup_matrix_load`  → `simdgroup_load(d, src, stride)`
- `enigma.simdgroup_matrix_store` → `simdgroup_store(mat, dst, stride)`
- `enigma.simdgroup_multiply_accumulate` → `simdgroup_multiply_accumulate(d, a, b, c)`
- `enigma.make_filled_simdgroup_matrix` → `make_filled_simdgroup_matrix<T, 8, 8>(val)`

Dispatch is in
[MSLEmitterCore.cpp](../lib/Target/MSL/MSLEmitterCore.cpp)
under `// --- Matrix ---`.

### DSL integration

Add DSL surface (`enigma.simdgroup_matrix_load`, etc.) that produces these
ops directly. No dialect work left.

---

## §5 Textures

`enigma.texture_read` / `texture_write` / `texture_sample` /
`texture_get_width` / `texture_get_height` are in the dialect and the MSL
emitter already lowers them (see
[MSLEmitterTexture.cpp](../lib/Target/MSL/MSLEmitterTexture.cpp)).

Two xcrun tests are currently skipped because the dialect uses memref as a
stand-in for texture types — a real `!enigma.texture` type still needs to
be wired through the Python bindings. Tracked separately; no blocker for
the DSL's runtime-binding API design.

---

## §6 Control flow — `scf.if` / `scf.for`

The emitter translates upstream `scf.for` and `scf.if` directly, including
loop-carried `iter_args`. See
[MSLEmitterControlFlow.cpp](../lib/Target/MSL/MSLEmitterControlFlow.cpp).

### DSL integration

DSL-side only: add Python-level control-flow tracing that emits
`scf.ForOp` / `scf.IfOp` instead of straight-line IR. No dialect work
left.

---

## §7 Vertex / fragment shaders

`enigma.vertex` and `enigma.fragment` entry-point ops are in the dialect
and emit correctly (see `emitVertex` / `emitFragment` in
[MSLEmitterCore.cpp](../lib/Target/MSL/MSLEmitterCore.cpp)).

### DSL integration

DSL-side only: add `@enigma.vertex_kernel` / `@enigma.fragment_kernel`
decorators that build these entry points.

---

## §8 Relational ops — `all` / `any` / vector-`select`

Transitively unblocked by §1 (vec_make). `enigma.select` already exists
and accepts vector condition/value operands.

---

## Installing the updated wheel

```bash
pip install https://github.com/Klyne-Research/Enigma-Dialect/releases/download/v0.1.0/enigma_dialect-0.1.0-cp312-cp312-macosx_15_0_arm64.whl
```

Quick smoke test:

```python
from mlir import ir
from mlir.dialects import enigma

with ir.Context() as ctx, ir.Location.unknown():
    enigma.register_dialect(ctx)
    assert hasattr(enigma, "MatMakeOp")
    assert hasattr(enigma, "VecMakeOp")
    assert hasattr(enigma, "FunctionConstantOp")
    print("ok")
```

---

## Files changed this round

- [EnigmaMatrixOps.td](../include/enigma/Dialect/Enigma/IR/EnigmaMatrixOps.td) — `Enigma_MatMakeOp`.
- [EnigmaDialect.cpp](../lib/Dialect/Enigma/IR/EnigmaDialect.cpp) — `MatMakeOp::verify`.
- [MSLEmitter.h](../include/enigma/Target/MSL/MSLEmitter.h) — `emitMatMake`, `emitFunctionConstants`.
- [MSLEmitterCore.cpp](../lib/Target/MSL/MSLEmitterCore.cpp) — 2-D vector → `floatCxR`, `emitFunctionConstants` walker, `mat_make` dispatch, `translateToMSL` wiring.
- [MSLEmitterMatrix.cpp](../lib/Target/MSL/MSLEmitterMatrix.cpp) — `emitMatMake`.
- [MSLEmitterControlFlow.cpp](../lib/Target/MSL/MSLEmitterControlFlow.cpp) — `emitFunctionConstant` body-site no-op.

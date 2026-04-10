//===- EnigmaPackOps.td - Pack/unpack operations -----------*- tablegen -*-===//
//
// MSL <metal_pack> functions for packing float/half vectors into compact
// integer formats and unpacking them back.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_PACK_OPS_TD
#define ENIGMA_PACK_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// ============================================================================
// Pack: vector<Nxf32> or vector<Nxf16> → i32 (or i16 for 565)
// ============================================================================

class Enigma_PackOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure]> {
  let summary = doc;
  let arguments = (ins AnyVectorOfNonZeroRank:$input);
  let results = (outs AnyInteger:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `->` type($result)";
}

def Enigma_PackSnorm4x8Op     : Enigma_PackOp<"pack_float_to_snorm4x8",
    "Pack float4/half4 to snorm 4x8 → i32">;
def Enigma_PackUnorm4x8Op     : Enigma_PackOp<"pack_float_to_unorm4x8",
    "Pack float4/half4 to unorm 4x8 → i32">;
def Enigma_PackSnorm2x16Op    : Enigma_PackOp<"pack_float_to_snorm2x16",
    "Pack float2/half2 to snorm 2x16 → i32">;
def Enigma_PackUnorm2x16Op    : Enigma_PackOp<"pack_float_to_unorm2x16",
    "Pack float2/half2 to unorm 2x16 → i32">;
def Enigma_PackSrgbUnorm4x8Op : Enigma_PackOp<"pack_float_to_srgb_unorm4x8",
    "Pack float4/half4 to sRGB unorm 4x8 → i32">;
def Enigma_PackUnorm10a2Op    : Enigma_PackOp<"pack_float_to_unorm10a2",
    "Pack float4 to unorm 10-10-10-2 → i32">;

// ============================================================================
// Unpack: i32 (or i16) → vector<Nxf32> or vector<Nxf16>
// ============================================================================

class Enigma_UnpackOp<string mnemonic, string doc>
    : Enigma_Op<mnemonic, [Pure]> {
  let summary = doc;
  let arguments = (ins AnyInteger:$input);
  let results = (outs AnyVectorOfNonZeroRank:$result);
  let assemblyFormat = "$input attr-dict `:` type($input) `->` type($result)";
}

def Enigma_UnpackSnorm4x8ToFloatOp  : Enigma_UnpackOp<"unpack_snorm4x8_to_float",
    "Unpack snorm 4x8 → float4">;
def Enigma_UnpackUnorm4x8ToFloatOp  : Enigma_UnpackOp<"unpack_unorm4x8_to_float",
    "Unpack unorm 4x8 → float4">;
def Enigma_UnpackSnorm2x16ToFloatOp : Enigma_UnpackOp<"unpack_snorm2x16_to_float",
    "Unpack snorm 2x16 → float2">;
def Enigma_UnpackUnorm2x16ToFloatOp : Enigma_UnpackOp<"unpack_unorm2x16_to_float",
    "Unpack unorm 2x16 → float2">;
def Enigma_UnpackSrgbUnorm4x8ToFloatOp : Enigma_UnpackOp<"unpack_srgb_unorm4x8_to_float",
    "Unpack sRGB unorm 4x8 → float4">;
def Enigma_UnpackUnorm10a2ToFloatOp : Enigma_UnpackOp<"unpack_unorm10a2_to_float",
    "Unpack unorm 10-10-10-2 → float4">;

#endif // ENIGMA_PACK_OPS_TD

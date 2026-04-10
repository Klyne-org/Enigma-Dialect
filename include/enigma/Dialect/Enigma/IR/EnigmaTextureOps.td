//===- EnigmaTextureOps.td - Texture operations ------------*- tablegen -*-===//
//
// Metal texture read/write/sample operations and texture queries.
// Textures are currently modeled using memref; a future version will
// introduce custom !enigma.texture types.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_TEXTURE_OPS_TD
#define ENIGMA_TEXTURE_OPS_TD

include "enigma/Dialect/Enigma/IR/EnigmaDialect.td"
include "enigma/Dialect/Enigma/IR/EnigmaEnums.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def Enigma_TextureReadOp : Enigma_Op<"texture_read", [Pure]> {
  let summary = "Read texel at integer coordinates — tex.read(coord)";
  let description = [{
    Reads a texel from a texture at the given integer coordinates.

    ```mlir
    %val = enigma.texture_read %tex[%x, %y] : memref<?x?xvector<4xf32>> -> vector<4xf32>
    ```
  }];
  let arguments = (ins AnyMemRef:$texture, Variadic<Index>:$coords);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$texture `[` $coords `]` attr-dict `:` type($texture) `->` type($result)";
}

def Enigma_TextureWriteOp : Enigma_Op<"texture_write", []> {
  let summary = "Write texel at integer coordinates — tex.write(val, coord)";
  let arguments = (ins AnyType:$value, AnyMemRef:$texture, Variadic<Index>:$coords);
  let assemblyFormat = "$value `,` $texture `[` $coords `]` attr-dict `:` type($value) `,` type($texture)";
}

def Enigma_TextureSampleOp : Enigma_Op<"texture_sample", [Pure]> {
  let summary = "Sample texture with sampler — tex.sample(sampler, coord)";
  let description = [{
    Samples a texture using normalized floating-point coordinates with the
    specified sampler configuration.

    ```mlir
    %val = enigma.texture_sample %tex[%u, %v] filter nearest address repeat
        : memref<?x?xvector<4xf32>> -> vector<4xf32>
    ```
  }];
  let arguments = (ins AnyMemRef:$texture, Variadic<AnyFloat>:$coords,
                       Enigma_SamplerFilter:$filter,
                       Enigma_SamplerAddress:$address);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$texture `[` $coords `]` `filter` $filter `address` $address attr-dict `:` type($texture) `,` type($coords) `->` type($result)";
}

def Enigma_TextureGetWidthOp : Enigma_Op<"texture_get_width", [Pure]> {
  let summary = "Get texture width — tex.get_width()";
  let arguments = (ins AnyMemRef:$texture);
  let results = (outs Index:$result);
  let assemblyFormat = "$texture attr-dict `:` type($texture)";
}

def Enigma_TextureGetHeightOp : Enigma_Op<"texture_get_height", [Pure]> {
  let summary = "Get texture height — tex.get_height()";
  let arguments = (ins AnyMemRef:$texture);
  let results = (outs Index:$result);
  let assemblyFormat = "$texture attr-dict `:` type($texture)";
}

#endif // ENIGMA_TEXTURE_OPS_TD

//===- EnigmaEnums.td - Enum definitions for Enigma dialect -*- tablegen -*-===//
//
// All enum attributes used across the Enigma dialect: address spaces,
// dimensions, barrier flags, memory ordering, texture access modes,
// sampler config, and math precision qualifiers.
//
//===----------------------------------------------------------------------===//

#ifndef ENIGMA_ENUMS_TD
#define ENIGMA_ENUMS_TD

include "mlir/IR/EnumAttr.td"

// ============================================================================
// AddressSpace — Metal memory address spaces
// ============================================================================
//   0 = device      (GPU-wide, read/write)
//   1 = constant    (read-only, broadcast-optimized)
//   2 = threadgroup  (shared within threadgroup, tile memory on Apple GPUs)
//   3 = thread      (private per-thread, stack)

def Enigma_ASDevice      : I32EnumAttrCase<"device",      0>;
def Enigma_ASConstant    : I32EnumAttrCase<"constant",    1>;
def Enigma_ASThreadgroup : I32EnumAttrCase<"threadgroup", 2>;
def Enigma_ASThread      : I32EnumAttrCase<"thread",      3>;

def Enigma_AddressSpace : I32EnumAttr<"AddressSpace",
    "Metal memory address space",
    [Enigma_ASDevice, Enigma_ASConstant, Enigma_ASThreadgroup, Enigma_ASThread]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// Dimension — x / y / z axis selector
// ============================================================================

def Enigma_DimX : I32EnumAttrCase<"x", 0>;
def Enigma_DimY : I32EnumAttrCase<"y", 1>;
def Enigma_DimZ : I32EnumAttrCase<"z", 2>;

def Enigma_Dimension : I32EnumAttr<"Dimension",
    "GPU dimension index (x/y/z)",
    [Enigma_DimX, Enigma_DimY, Enigma_DimZ]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// MemFlags — barrier memory flag bits
// ============================================================================

def Enigma_MFNone                  : I32EnumAttrCase<"mem_none",                   0>;
def Enigma_MFDevice                : I32EnumAttrCase<"mem_device",                 1>;
def Enigma_MFThreadgroup           : I32EnumAttrCase<"mem_threadgroup",            2>;
def Enigma_MFDeviceAndThreadgroup  : I32EnumAttrCase<"mem_device_and_threadgroup", 3>;
def Enigma_MFTexture               : I32EnumAttrCase<"mem_texture",                4>;

def Enigma_MemFlags : I32EnumAttr<"MemFlags",
    "Metal barrier memory flags",
    [Enigma_MFNone, Enigma_MFDevice, Enigma_MFThreadgroup,
     Enigma_MFDeviceAndThreadgroup, Enigma_MFTexture]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// MemoryOrder — atomic memory ordering
// ============================================================================

def Enigma_MORelaxed : I32EnumAttrCase<"relaxed", 0>;
def Enigma_MOAcquire : I32EnumAttrCase<"acquire", 1>;
def Enigma_MORelease : I32EnumAttrCase<"release", 2>;
def Enigma_MOAcqRel  : I32EnumAttrCase<"acq_rel", 3>;

def Enigma_MemoryOrder : I32EnumAttr<"MemoryOrder",
    "Metal atomic memory ordering",
    [Enigma_MORelaxed, Enigma_MOAcquire, Enigma_MORelease, Enigma_MOAcqRel]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// TextureAccess — texture access qualifier
// ============================================================================

def Enigma_TARead      : I32EnumAttrCase<"read",       0>;
def Enigma_TAWrite     : I32EnumAttrCase<"write",      1>;
def Enigma_TAReadWrite : I32EnumAttrCase<"read_write",  2>;
def Enigma_TASample    : I32EnumAttrCase<"sample",     3>;

def Enigma_TextureAccess : I32EnumAttr<"TextureAccess",
    "Metal texture access qualifier",
    [Enigma_TARead, Enigma_TAWrite, Enigma_TAReadWrite, Enigma_TASample]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// SamplerFilter — texture sampling filter mode
// ============================================================================

def Enigma_SFNearest : I32EnumAttrCase<"nearest", 0>;
def Enigma_SFLinear  : I32EnumAttrCase<"linear",  1>;

def Enigma_SamplerFilter : I32EnumAttr<"SamplerFilter",
    "Metal sampler filter mode",
    [Enigma_SFNearest, Enigma_SFLinear]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// SamplerAddress — texture sampling address mode
// ============================================================================

def Enigma_SAClampToZero    : I32EnumAttrCase<"clamp_to_zero",    0>;
def Enigma_SAClampToEdge    : I32EnumAttrCase<"clamp_to_edge",    1>;
def Enigma_SARepeat          : I32EnumAttrCase<"repeat",           2>;
def Enigma_SAMirroredRepeat : I32EnumAttrCase<"mirrored_repeat",  3>;

def Enigma_SamplerAddress : I32EnumAttr<"SamplerAddress",
    "Metal sampler address mode",
    [Enigma_SAClampToZero, Enigma_SAClampToEdge, Enigma_SARepeat,
     Enigma_SAMirroredRepeat]> {
  let cppNamespace = "::enigma";
}

// ============================================================================
// MathPrecision — fast vs precise math variants
// ============================================================================

def Enigma_MPDefault : I32EnumAttrCase<"default_precision", 0>;
def Enigma_MPFast    : I32EnumAttrCase<"fast",              1>;
def Enigma_MPPrecise : I32EnumAttrCase<"precise",           2>;

def Enigma_MathPrecision : I32EnumAttr<"MathPrecision",
    "Metal math precision qualifier",
    [Enigma_MPDefault, Enigma_MPFast, Enigma_MPPrecise]> {
  let cppNamespace = "::enigma";
}

#endif // ENIGMA_ENUMS_TD

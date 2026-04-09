/*===- TableGen'erated file -------------------------------------*- C++ -*-===*\
|*                                                                            *|
|* Enum Utility Declarations                                                  *|
|*                                                                            *|
|* Automatically generated file, do not edit!                                 *|
|* From: MetalOps.td                                                          *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

namespace metal {

// GPU dimension
enum class Dimension : uint32_t {
  x = 0,
  y = 1,
  z = 2,
};

::std::optional<Dimension> symbolizeDimension(uint32_t);
::llvm::StringRef stringifyDimension(Dimension);
::std::optional<Dimension> symbolizeDimension(::llvm::StringRef);
inline constexpr unsigned getMaxEnumValForDimension() {
  return 2;
}


inline ::llvm::StringRef stringifyEnum(Dimension enumValue) {
  return stringifyDimension(enumValue);
}

template <typename EnumType>
::std::optional<EnumType> symbolizeEnum(::llvm::StringRef);

template <>
inline ::std::optional<Dimension> symbolizeEnum<Dimension>(::llvm::StringRef str) {
  return symbolizeDimension(str);
}

class DimensionAttr : public ::mlir::IntegerAttr {
public:
  using ValueType = Dimension;
  using ::mlir::IntegerAttr::IntegerAttr;
  static bool classof(::mlir::Attribute attr);
  static DimensionAttr get(::mlir::MLIRContext *context, Dimension val);
  Dimension getValue() const;
};

} // namespace metal

namespace mlir {
template <typename T, typename>
struct FieldParser;

template<>
struct FieldParser<::metal::Dimension, ::metal::Dimension> {
  template <typename ParserT>
  static FailureOr<::metal::Dimension> parse(ParserT &parser) {
    // Parse the keyword/string containing the enum.
    std::string enumKeyword;
    auto loc = parser.getCurrentLocation();
    if (failed(parser.parseOptionalKeywordOrString(&enumKeyword)))
      return parser.emitError(loc, "expected keyword for GPU dimension");

    // Symbolize the keyword.
    if (::std::optional<::metal::Dimension> attr = ::metal::symbolizeEnum<::metal::Dimension>(enumKeyword))
      return *attr;
    return parser.emitError(loc, "expected one of [x, y, z] for GPU dimension, got: ") << enumKeyword;
  }
};

/// Support for std::optional, useful in attribute/type definition where the enum is
/// used as:
///
///    let parameters = (ins OptionalParameter<"std::optional<TheEnumName>">:$value);
template<>
struct FieldParser<std::optional<::metal::Dimension>, std::optional<::metal::Dimension>> {
  template <typename ParserT>
  static FailureOr<std::optional<::metal::Dimension>> parse(ParserT &parser) {
    // Parse the keyword/string containing the enum.
    std::string enumKeyword;
    auto loc = parser.getCurrentLocation();
    if (failed(parser.parseOptionalKeywordOrString(&enumKeyword)))
      return std::optional<::metal::Dimension>{};

    // Symbolize the keyword.
    if (::std::optional<::metal::Dimension> attr = ::metal::symbolizeEnum<::metal::Dimension>(enumKeyword))
      return attr;
    return parser.emitError(loc, "expected one of [x, y, z] for GPU dimension, got: ") << enumKeyword;
  }
};
} // namespace mlir

namespace llvm {
inline ::llvm::raw_ostream &operator<<(::llvm::raw_ostream &p, ::metal::Dimension value) {
  auto valueStr = stringifyEnum(value);
  return p << valueStr;
}
} // namespace llvm

namespace llvm {
template<> struct DenseMapInfo<::metal::Dimension> {
  using StorageInfo = ::llvm::DenseMapInfo<uint32_t>;

  static inline ::metal::Dimension getEmptyKey() {
    return static_cast<::metal::Dimension>(StorageInfo::getEmptyKey());
  }

  static inline ::metal::Dimension getTombstoneKey() {
    return static_cast<::metal::Dimension>(StorageInfo::getTombstoneKey());
  }

  static unsigned getHashValue(const ::metal::Dimension &val) {
    return StorageInfo::getHashValue(static_cast<uint32_t>(val));
  }

  static bool isEqual(const ::metal::Dimension &lhs, const ::metal::Dimension &rhs) {
    return lhs == rhs;
  }
};
}



from std.sys import size_of


comptime SmallString2 = SmallString[DType.uint16]
comptime SmallString4 = SmallString[DType.uint32]
comptime SmallString8 = SmallString[DType.uint64]
comptime SmallString16 = SmallString[DType.uint128]

struct SmallString[dtype: DType = DType.uint32](ImplicitlyCopyable, Writable, Equatable, Hashable, RegisterPassable):
    """
    SmallString represents a string where the maximum length is determined by the size of the underlying data type.
    The string is stored in a single scalar value, and the maximum length is equal to the number of bytes in the data type.
    
    For example, if the data type is UInt32, the maximum length of the string is 4 bytes.
    If the data type is UInt64, the maximum length is 8 bytes, and so on.

    If the string includes the unicode character 0x0000, it will be treated as a null terminator
    and the string will be truncated at that point.

    If the string is shorter than the maximum length, it will be padded with null bytes.

    Example usage:
    ```mojo
    var s0 = SmallString[DType.uint32]("hi")  # 4 bytes
    var s1 = SmallString2("Hi")  # 2 bytes
    var s2 = SmallString4("Hello")  # 4 bytes, last character is discarded
    var s3 = SmallString8("World!")  # 8 bytes
    var s4 = SmallString16("Mojo 🔥")  # 16 bytes with non-ascii character
    ```
    """
 
    comptime max_bytes = size_of[Scalar[Self.dtype]]()
    
    var __code: Scalar[Self.dtype]

    @implicit
    def __init__(out self, code: StringSpan):
        """
        Initialize the SmallString from a Unicode string.
        """
        var raw_bytes = code.as_bytes()
        var byte_offset = 0
        self.__code = 0
        
        # Deal with each Unicode code point, which may be more than one byte in UTF-8.
        for cp in code.codepoints():
            var cp_len = cp.utf8_byte_length()
            if byte_offset + cp_len > Self.max_bytes:
                break

            if cp == Codepoint(0x0000):  # Null terminator
                break

            for i in range(cp_len):
                self.__code |= Scalar[Self.dtype](raw_bytes[byte_offset + i]) << Scalar[Self.dtype](
                    (byte_offset + i) * 8
                )

            byte_offset += cp_len

    def to_string(self) -> String:
        """Convert the SmallString back to a regular string."""
        var code = self.__code
        var bytes: List[UInt8] = []
        for _ in range(Self.max_bytes):
            var b = UInt8(code & 0xFF)
            if b == 0:
                break
            bytes.append(b)
            code >>= 8
        return String(unsafe_from_utf8=bytes)

    def __eq__(self, other: StringSpan) -> Bool:
        return self.to_string() == other

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.to_string())


struct SIMDString[width: Int = 4](
    ImplicitlyCopyable, Writable, Equatable, Hashable, RegisterPassable
):
    """
    SmallString backed by a fixed-width SIMD[DType.uint8, width] vector.

    Truncates at whole UTF-8 codepoints so multi-byte characters are not split.
    Stops at Unicode U+0000 (null terminator) and zero-pads remaining lanes.
    """

    comptime max_bytes = Self.width
    var __bytes: SIMD[DType.uint8, Self.width]

    @implicit
    def __init__(out self, code: StringSpan):
        var raw_bytes = code.as_bytes()
        var byte_offset = 0
        self.__bytes = SIMD[DType.uint8, Self.width](0)

        for cp in code.codepoints():
            var cp_len = cp.utf8_byte_length()
            if byte_offset + cp_len > Self.max_bytes:
                break

            if cp == Codepoint(0x0000):
                break

            for i in range(cp_len):
                self.__bytes[byte_offset + i] = raw_bytes[byte_offset + i]

            byte_offset += cp_len

    def to_string(self) -> String:
        """Convert back to a String, stopping at the first zero byte."""
        var buf = List[UInt8](capacity=Self.max_bytes)
        for i in range(Self.max_bytes):
            var b = self.__bytes[i]
            if b == 0:
                break
            buf.append(b)
        return String(unsafe_from_utf8=buf)

    def __eq__(self, other: StringSpan) -> Bool:
        return self.to_string() == other

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.to_string())
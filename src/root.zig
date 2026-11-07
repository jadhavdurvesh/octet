//! OCTET frame v1: bounded, deterministic, big-endian binary primitives.
const std = @import("std");

pub const MAGIC = "OCT1";
pub const HEADER_LEN: usize = 10;
pub const VERSION: u8 = 1;

pub const Error = error{
    OutputTooSmall, InputTooShort, BadMagic, UnsupportedVersion,
    LengthMismatch, PayloadTooLarge, InvalidUtf8, InvalidBoolean,
};

pub const FrameView = struct { version: u8, flags: u8, payload: []const u8 };

pub fn encode(flags: u8, payload: []const u8, output: []u8, max_payload: usize) Error![]u8 {
    if (payload.len > max_payload or payload.len > 0xffff_ffff) return Error.PayloadTooLarge;
    const total = HEADER_LEN + payload.len;
    if (output.len < total) return Error.OutputTooSmall;
    @memcpy(output[0..4], MAGIC);
    output[4] = VERSION;
    output[5] = flags;
    var length_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &length_bytes, @intCast(payload.len), .big);
    @memcpy(output[6..10], &length_bytes);
    @memcpy(output[HEADER_LEN..total], payload);
    return output[0..total];
}

pub fn decode(input: []const u8, max_payload: usize) Error!FrameView {
    if (input.len < HEADER_LEN) return Error.InputTooShort;
    if (!std.mem.eql(u8, input[0..4], MAGIC)) return Error.BadMagic;
    if (input[4] != VERSION) return Error.UnsupportedVersion;
    var length_bytes: [4]u8 = undefined;
    @memcpy(&length_bytes, input[6..10]);
    const wire_len = std.mem.readInt(u32, &length_bytes, .big);
    const payload_len: usize = @intCast(wire_len);
    if (payload_len > max_payload) return Error.PayloadTooLarge;
    if (input.len != HEADER_LEN + payload_len) return Error.LengthMismatch;
    return .{ .version = input[4], .flags = input[5], .payload = input[HEADER_LEN..] };
}

/// Primitive writer. All integers use network byte order.
pub const Writer = struct {
    output: []u8,
    position: usize = 0,

    fn reserve(self: *Writer, count: usize) Error![]u8 {
        if (count > self.output.len -| self.position) return Error.OutputTooSmall;
        const slice = self.output[self.position .. self.position + count];
        self.position += count;
        return slice;
    }
    pub fn putU8(self: *Writer, value: u8) Error!void { (try self.reserve(1))[0] = value; }
    pub fn putBool(self: *Writer, value: bool) Error!void { try self.putU8(if (value) 1 else 0); }
    pub fn putU16(self: *Writer, value: u16) Error!void {
        var b: [2]u8 = undefined; std.mem.writeInt(u16, &b, value, .big); @memcpy(try self.reserve(2), &b);
    }
    pub fn putU32(self: *Writer, value: u32) Error!void {
        var b: [4]u8 = undefined; std.mem.writeInt(u32, &b, value, .big); @memcpy(try self.reserve(4), &b);
    }
    pub fn putU64(self: *Writer, value: u64) Error!void {
        var b: [8]u8 = undefined; std.mem.writeInt(u64, &b, value, .big); @memcpy(try self.reserve(8), &b);
    }
    pub fn putBytes(self: *Writer, value: []const u8) Error!void {
        if (value.len > 0xffff_ffff) return Error.PayloadTooLarge;
        try self.putU32(@intCast(value.len)); @memcpy(try self.reserve(value.len), value);
    }
    pub fn putString(self: *Writer, value: []const u8) Error!void {
        if (!std.unicode.utf8ValidateSlice(value)) return Error.InvalidUtf8;
        try self.putBytes(value);
    }
    pub fn written(self: *Writer) []u8 { return self.output[0..self.position]; }
};

pub const Reader = struct {
    input: []const u8,
    position: usize = 0,

    fn take(self: *Reader, count: usize) Error![]const u8 {
        if (count > self.input.len -| self.position) return Error.InputTooShort;
        const slice = self.input[self.position .. self.position + count];
        self.position += count;
        return slice;
    }
    pub fn getU8(self: *Reader) Error!u8 { return (try self.take(1))[0]; }
    pub fn getBool(self: *Reader) Error!bool {
        return switch (try self.getU8()) { 0 => false, 1 => true, else => Error.InvalidBoolean };
    }
    pub fn getU16(self: *Reader) Error!u16 {
        var b: [2]u8 = undefined; @memcpy(&b, try self.take(2)); return std.mem.readInt(u16, &b, .big);
    }
    pub fn getU32(self: *Reader) Error!u32 {
        var b: [4]u8 = undefined; @memcpy(&b, try self.take(4)); return std.mem.readInt(u32, &b, .big);
    }
    pub fn getU64(self: *Reader) Error!u64 {
        var b: [8]u8 = undefined; @memcpy(&b, try self.take(8)); return std.mem.readInt(u64, &b, .big);
    }
    pub fn getBytes(self: *Reader, max_len: usize) Error![]const u8 {
        const len: usize = @intCast(try self.getU32());
        if (len > max_len) return Error.PayloadTooLarge;
        return self.take(len);
    }
    pub fn getString(self: *Reader, max_len: usize) Error![]const u8 {
        const value = try self.getBytes(max_len);
        if (!std.unicode.utf8ValidateSlice(value)) return Error.InvalidUtf8;
        return value;
    }
    pub fn finished(self: *const Reader) bool { return self.position == self.input.len; }
};

test "frame round trip" {
    var bytes: [64]u8 = undefined;
    const encoded = try encode(3, "robot-state", &bytes, 32);
    const decoded = try decode(encoded, 32);
    try std.testing.expectEqual(@as(u8, 1), decoded.version);
    try std.testing.expectEqual(@as(u8, 3), decoded.flags);
    try std.testing.expectEqualStrings("robot-state", decoded.payload);
}
test "primitive values round trip" {
    var bytes: [128]u8 = undefined;
    var writer = Writer{ .output = &bytes };
    try writer.putU8(255);
    try writer.putBool(true);
    try writer.putU16(0x1234);
    try writer.putU32(0x12345678);
    try writer.putU64(0x0102030405060708);
    try writer.putString("OCTET");
    var reader = Reader{ .input = writer.written() };
    try std.testing.expectEqual(@as(u8, 255), try reader.getU8());
    try std.testing.expect(try reader.getBool());
    try std.testing.expectEqual(@as(u16, 0x1234), try reader.getU16());
    try std.testing.expectEqual(@as(u32, 0x12345678), try reader.getU32());
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), try reader.getU64());
    try std.testing.expectEqualStrings("OCTET", try reader.getString(16));
    try std.testing.expect(reader.finished());
}
test "rejects malformed, oversized and truncated input" {
    var bytes: [64]u8 = undefined;
    const encoded = try encode(0, "payload", &bytes, 32);
    try std.testing.expectError(Error.PayloadTooLarge, decode(encoded, 2));
    try std.testing.expectError(Error.BadMagic, decode("NOPE000000", 32));
    var reader = Reader{ .input = &.{} };
    try std.testing.expectError(Error.InputTooShort, reader.getU32());
}

//! OCTET frame v0 draft: bounded, deterministic, big-endian envelope.

const std = @import("std");

pub const MAGIC = "OCT1";
pub const HEADER_LEN: usize = 10;
pub const VERSION: u8 = 1;

pub const Error = error{
    OutputTooSmall,
    InputTooShort,
    BadMagic,
    UnsupportedVersion,
    LengthMismatch,
    PayloadTooLarge,
};

pub const FrameView = struct {
    version: u8,
    flags: u8,
    payload: []const u8,
};

/// Encode into caller-owned memory. No allocation is performed.
pub fn encode(flags: u8, payload: []const u8, output: []u8, max_payload: usize) Error![]u8 {
    if (payload.len > max_payload or payload.len > std.math.maxInt(u32)) return Error.PayloadTooLarge;
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

/// Decode a borrowed view. The returned payload aliases the input buffer.
pub fn decode(input: []const u8, max_payload: usize) Error!FrameView {
    if (input.len < HEADER_LEN) return Error.InputTooShort;
    if (!std.mem.eql(u8, input[0..4], MAGIC)) return Error.BadMagic;
    if (input[4] != VERSION) return Error.UnsupportedVersion;
    const length_bytes: *const [4]u8 = @ptrCast(input[6..10].ptr);
    const len = std.mem.readInt(u32, length_bytes, .big);
    if (len > max_payload) return Error.PayloadTooLarge;
    if (input.len != HEADER_LEN + len) return Error.LengthMismatch;
    return .{ .version = input[4], .flags = input[5], .payload = input[HEADER_LEN..] };
}

test "round trips a frame without allocating" {
    var bytes: [64]u8 = undefined;
    const encoded = try encode(3, "robot-state", &bytes, 32);
    const decoded = try decode(encoded, 32);
    try std.testing.expectEqual(@as(u8, 1), decoded.version);
    try std.testing.expectEqual(@as(u8, 3), decoded.flags);
    try std.testing.expectEqualStrings("robot-state", decoded.payload);
}

test "rejects malformed and oversized frames" {
    var bytes: [64]u8 = undefined;
    const encoded = try encode(0, "payload", &bytes, 32);
    try std.testing.expectError(Error.PayloadTooLarge, decode(encoded, 2));
    try std.testing.expectError(Error.BadMagic, decode("NOPE000000", 32));
}

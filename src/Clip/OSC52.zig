/// OSC52 Clipboard backend
/// Fullfils `Clip` interface
pub const OSC52 = @This();

const std = @import("std");
const Io = std.Io;

alloc: std.mem.Allocator,
io: std.Io,

base64buffer: std.ArrayList(u8),

leftover_bytes: [3]u8,
leftover_count: u8,

const base64encoder = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, '=');

pub fn init(alloc: std.mem.Allocator, io: Io, buf_size: usize) !OSC52 {
    return .{
        .alloc = alloc,
        .io = io,
        .base64buffer = try std.ArrayList(u8).initCapacity(alloc, buf_size),
        .leftover_bytes = undefined,
        .leftover_count = 0,
    };
}

pub fn free(self: *OSC52) void {
    self.base64buffer.clearAndFree(self.alloc);
}

pub fn writeCopyBuffer(self: *OSC52, buf: []const u8) anyerror!void {
    if (buf.len == 0) return;

    // Start of buffer after dealing with leftover bytes
    const buf_idx = 3 - self.leftover_count;

    // When we dont fill the leftover buffer, just copy data
    if (buf_idx > buf.len) {
        const end = self.leftover_count + buf.len;
        @memcpy(self.leftover_bytes[self.leftover_count..end], buf[0..buf.len]);
        self.leftover_count = @intCast(end);
        return;
    }

    @memcpy(self.leftover_bytes[self.leftover_count..3], buf[0..buf_idx]);
    var temp: [5]u8 = undefined;
    var s = OSC52.base64encoder.encode(&temp, &self.leftover_bytes);
    try self.base64buffer.appendSlice(self.alloc, s);

    const chunkable_length = buf.len - ((buf.len - buf_idx) % 3);
    var chunker = std.mem.window(u8, buf[buf_idx..chunkable_length], 3, 3);
    while (chunker.next()) |chunk| {
        // var temp: [5]u8 = undefined;
        s = OSC52.base64encoder.encode(&temp, chunk);
        try self.base64buffer.appendSlice(self.alloc, s);
    }

    self.leftover_count = @intCast(buf.len - chunkable_length);
    if (self.leftover_count != 0) {
        @memmove(self.leftover_bytes[0..self.leftover_count], buf[chunkable_length..]);
    }
}

pub fn encodeRemaining(self: *OSC52) anyerror!void {
    var temp: [5]u8 = undefined;
    const s = OSC52.base64encoder.encode(&temp, self.leftover_bytes[0..self.leftover_count]);
    try self.base64buffer.appendSlice(self.alloc, s);
}

pub fn writePasteboard(self: *OSC52) anyerror!void {
    try self.encodeRemaining();

    // https://ghostty.org/docs/vt/osc/52
    const osc_header = &[_]u8{
        0x1b, // ESC
        0x5d, // ']'
        0x35, 0x32, // Code 52
        0x3b, // ';'
        // 0x70, // 'p' Primary Clipboard
        0x63, // 'c' Standard Clipboard
        0x3b, // ';'
    };
    const osc_footer = &[_]u8{
        0x1b, // ESC
        0x5c, // '\'
    };

    // Write data to stdout
    const stdout = Io.File.stdout();
    try stdout.writeStreamingAll(self.io, osc_header);
    try stdout.writeStreamingAll(self.io, self.base64buffer.items);
    try stdout.writeStreamingAll(self.io, osc_footer);
}

test "basic base64 encode" {
    var osc = try OSC52.init(std.testing.allocator, std.testing.io, 1024);
    defer osc.free();
    try osc.writeCopyBuffer("part1");
    try osc.encodeRemaining();
    try std.testing.expectEqualSlices(u8, "cGFydDE=", osc.base64buffer.items);
}

test "multi part base64 encode" {
    var osc = try OSC52.init(std.testing.allocator, std.testing.io, 1024);
    defer osc.free();
    try osc.writeCopyBuffer("part1");
    try osc.writeCopyBuffer("part2");
    try osc.encodeRemaining();
    try std.testing.expectEqualSlices(u8, "cGFydDFwYXJ0Mg==", osc.base64buffer.items);
}

test "tiny buffers base64 encode" {
    var osc = try OSC52.init(std.testing.allocator, std.testing.io, 1024);
    defer osc.free();
    try osc.writeCopyBuffer("part1");
    try osc.writeCopyBuffer("part2");
    try osc.writeCopyBuffer("1");
    try osc.writeCopyBuffer("2");
    try osc.writeCopyBuffer("3");
    try osc.writeCopyBuffer("45");
    try osc.writeCopyBuffer("6");
    try osc.writeCopyBuffer("78");
    try osc.writeCopyBuffer("90fin");
    try osc.encodeRemaining();
    try std.testing.expectEqualSlices(u8, "cGFydDFwYXJ0MjEyMzQ1Njc4OTBmaW4=", osc.base64buffer.items);
}

test "big buffers base64 encode" {
    var osc = try OSC52.init(std.testing.allocator, std.testing.io, 1024);
    defer osc.free();
    try osc.writeCopyBuffer("part1part1part1part1part1part1part1part1part1|");
    try osc.writeCopyBuffer("part2part2part2part2part2part2part2part2part2");
    try osc.encodeRemaining();
    try std.testing.expectEqualSlices(u8, "cGFydDFwYXJ0MXBhcnQxcGFydDFwYXJ0MXBhcnQxcGFydDFwYXJ0MXBhcnQxfHBhcnQycGFydDJwYXJ0MnBhcnQycGFydDJwYXJ0MnBhcnQycGFydDJwYXJ0Mg==", osc.base64buffer.items);
}

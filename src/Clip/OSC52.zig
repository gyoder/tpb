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

const base64encoder = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, null);

pub fn init(alloc: std.mem.Allocator, io: Io, buf_size: usize) !OSC52 {
    return .{
        .alloc = alloc,
        .io = io,
        .base64buffer = try std.ArrayList(u8).initCapacity(alloc, buf_size),
        .leftover_bytes = undefined,
        .leftover_count = 0,
    };
}

pub fn writeCopyBuffer(self: *OSC52, buf: []u8) !void {
    if (buf.len == 0) return;

    // Start of buffer after dealing with leftover bytes
    const buf_idx = 3 - self.leftover_count;

    if (buf.len + self.leftover_count < 3) {
        const len = buf.len + self.leftover_count;
        @memcpy(self.leftover_bytes[self.leftover_count..len], buf[0..buf.len]);
        self.leftover_count = @intCast(len);
        return;
    }

    if (self.leftover_count != 0) {
        @memcpy(self.leftover_bytes[self.leftover_count..3], buf[0..buf_idx]);
        var temp: [5]u8 = undefined;
        const s = OSC52.base64encoder.encode(&temp, &self.leftover_bytes);
        try self.base64buffer.appendSlice(self.alloc, s);
    }

    const chunkable_length = buf.len - ((buf.len - buf_idx) % 3);
    var chunker = std.mem.window(u8, buf[0..chunkable_length], 3, 3);
    while (chunker.next()) |chunk| {
        var temp: [5]u8 = undefined;
        const s = OSC52.base64encoder.encode(&temp, chunk);
        try self.base64buffer.appendSlice(self.alloc, s);
    }

    self.leftover_count = @intCast(buf.len - chunkable_length);
    if (self.leftover_count != 0) {
        @memmove(self.leftover_bytes[0..self.leftover_count], buf[chunkable_length..]);
    }
}

pub fn writePasteboard(self: *OSC52) !void {

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

    // Write leftover bytes
    var temp: [5]u8 = undefined;
    const s = OSC52.base64encoder.encode(&temp, self.leftover_bytes[0..self.leftover_count]);
    try self.base64buffer.appendSlice(self.alloc, s);

    // Write data to stdout
    const stdout = Io.File.stdout();
    try stdout.writeStreamingAll(self.io, osc_header);
    try stdout.writeStreamingAll(self.io, self.base64buffer.items);
    try stdout.writeStreamingAll(self.io, osc_footer);
}

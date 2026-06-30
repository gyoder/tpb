/// NSPasteBoard Clipboard backend
/// Fulfills `Clip` interface
pub const NSPasteboard = @This();

const std = @import("std");

extern fn sendPB(text: [*:0]const u8) void;
extern fn initPB() void;

alloc: std.mem.Allocator,
io: std.Io,

buffer: std.ArrayList(u8),

pub fn init(alloc: std.mem.Allocator, io: std.Io, buf_size: usize) !NSPasteboard {
    return .{
        .alloc = alloc,
        .io = io,
        .buffer = try std.ArrayList(u8).initCapacity(alloc, buf_size),
    };
}

pub fn free(self: *NSPasteboard) void {
    self.buffer.clearAndFree(self.alloc);
}

pub fn writeCopyBuffer(self: *NSPasteboard, buf: []const u8) anyerror!void {
    try self.buffer.appendSlice(self.alloc, buf);
}

pub fn writePasteboard(self: *NSPasteboard) anyerror!void {
    // Null Terminate string for C function Call
    if (self.buffer.items[self.buffer.items.len - 1] == '\n') {
        self.buffer.items[self.buffer.items.len - 1] = '\x00';
    } else {
        try self.buffer.append(self.alloc, '\x00');
    }
    initPB();
    sendPB(@ptrCast(self.buffer.items.ptr));
}

test "objc bridge" {
    initPB();
    sendPB("test_string");

    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{"pbpaste"},
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    try std.testing.expectEqualStrings("test_string", std.mem.trim(u8, result.stdout, "\n"));
}

/// ForkOut Clipboard backend
/// Fulfills `Clip` interface
pub const ForkOut = @This();

const std = @import("std");

extern fn sendPB(text: [*:0]const u8) void;
extern fn initPB() void;

io: std.Io,

child: std.process.Child,

pub fn init(io: std.Io, argv: []const []const u8) !ForkOut {
    return .{ .child = try std.process.spawn(io, .{ .argv = argv, .stdin = .pipe }), .io = io };
}

pub fn writeCopyBuffer(self: *ForkOut, buf: []const u8) anyerror!void {
    try self.child.stdin.?.writeStreamingAll(self.io, buf);
}

pub fn writePasteboard(self: *ForkOut) anyerror!void {
    self.child.stdin.?.close(self.io);
}

const std = @import("std");

extern fn sendPB(text: [*:0]const u8) void;
extern fn initPB() void;

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


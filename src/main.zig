const std = @import("std");
const builtin = @import("builtin");

const os = builtin.target.os.tag;
const File = std.Io.File;
const Clip = @import("Clip.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // This program should not be run interactively
    if (try File.stdin().isTty(io)) {
        std.debug.print(
            \\ This program is not meant to be run interactively.
            \\ Please pipe into this program.
            \\
        , .{});
        std.process.exit(1);
    }

    // We want to avoid doing as many allocations as possible so having raw
    // pages with it being larger should be totally fine
    const alloc = std.heap.page_allocator;
    const size = std.heap.pageSize();

    const is_ssh =
        init.environ_map.get("SSH_CONNECTION") != null or
        init.environ_map.get("SSH_CLIENT") != null or
        init.environ_map.get("SSH_TTY") != null;

    if (is_ssh) {
        var clip = try Clip.OSC52.init(alloc, io, size);
        defer clip.free();
        try run(io, &clip);
        return;
    }

    if (comptime os == .macos) {
        var clip = try Clip.NSPasteboard.init(alloc, io, size);
        defer clip.free();
        try run(io, &clip);
        return;
    }

    // Fallback Clipboard
    var clip = try Clip.OSC52.init(alloc, io, size);
    defer clip.free();
    try run(io, &clip);
}

pub fn run(io: std.Io, clip: anytype) !void {
    std.debug.print("\x1b[0;32mCopying the following to Pasteboard\x1b[0m\n", .{});

    var buf: [4096]u8 = undefined;
    while (true) {
        // Read as much of stdin there is
        const bytes = File.stdin().readStreaming(io, &.{&buf}) catch |err| {
            if (err == File.ReadStreamingError.EndOfStream) {
                break;
            } else {
                return err;
            }
        };
        // Passthrough to stdout
        _ = try File.stdout().writeStreamingAll(io, buf[0..bytes]);

        // Write to clip
        try clip.writeCopyBuffer(buf[0..bytes]);
    }

    try clip.writePasteboard();

    std.debug.print("\x1b[0;32mCopied To Pasteboard!\x1b[0m\n", .{});
}

test {
    _ = @import("Clip.zig");
}

const std = @import("std");
const builtin = @import("builtin");

const os = builtin.target.os.tag;
const File = std.Io.File;
const Clip = @import("Clip.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // We want to avoid doing as many allocations as possible so having raw
    // pages with it being larger should be totally fine
    const alloc = init.arena.child_allocator;
    const size = std.heap.pageSize() >> 1;

    // This program should not be run interactively
    const input: File = file: {
        if (try File.stdin().isTty(io)) {
            if (init.minimal.args.vector.len == 2) {
                const path: []const u8 = (try init.minimal.args.toSlice(alloc))[1];
                break :file try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, path, .{});
            }
            std.debug.print(
                \\ This program is not meant to be run interactively.
                \\ Please pipe into this program or pass filename.
                \\
            , .{});
            std.process.exit(1);
        }
        break :file File.stdin();
    };

    const is_ssh =
        init.environ_map.get("SSH_CONNECTION") != null or
        init.environ_map.get("SSH_CLIENT") != null or
        init.environ_map.get("SSH_TTY") != null;

    const is_tmux =
        init.environ_map.get("TMUX") != null;

    if (is_ssh) {
        var clip = try Clip.OSC52.init(alloc, io, size, is_tmux);
        defer clip.free();
        try run(io, input, &clip);
        return;
    }

    if (comptime os == .macos) {
        var clip = try Clip.NSPasteboard.init(alloc, io, size);
        defer clip.free();
        try run(io, input, &clip);
        return;
    }

    // I don't like this but it will stay until I review how dispatch works
    // with zig since I will probably be refactoring there
    linux: {
        if (comptime os == .linux) {
            const xdg_type = init.environ_map.get("XDG_SESSION_TYPE") orelse "";

            if (std.mem.eql(u8, xdg_type, "wayland")) {
                var clip = Clip.ForkOut.init(io, &[_][]const u8{"wl-copy"}) catch break :linux;
                try run(io, input, &clip);
                return;
            } else if (std.mem.eql(u8, xdg_type, "x11")) {
                var clip = Clip.ForkOut.init(io, &[_][]const u8{ "xclip", "-selection", "clipboard" }) catch break :linux;
                try run(io, input, &clip);
                return;
            }
        }
    }

    // Fallback Clipboard
    var clip = try Clip.OSC52.init(alloc, io, size, is_tmux);
    defer clip.free();
    try run(io, input, &clip);
}

pub fn run(io: std.Io, file: File, clip: anytype) !void {
    std.debug.print("\x1b[0;32mCopying the following to Pasteboard\x1b[0m\n", .{});

    var buf: [1 << 15]u8 = undefined;
    while (true) {
        // Read as much of stdin there is
        const bytes = file.readStreaming(io, &.{&buf}) catch |err| {
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

    file.close(io);
}

test {
    _ = @import("Clip.zig");
}

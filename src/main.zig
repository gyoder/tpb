const std = @import("std");
const File = std.Io.File;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // This program should not be run interactively
    if (try File.stdin().isTty(io)) {
        std.debug.print("This program is not meant to be run interactively. Please pipe into this program.\n", .{});
        std.process.exit(1);
    }

    std.debug.print("\x1b[0;32mCopying the following to Pasteboard\x1b[0m\n", .{});

    // We want to avoid doing as many allocations as possible so having raw
    // pages with it being larger should be totally fine
    const alloc = std.heap.page_allocator;

    var buf: [4096]u8 = undefined;
    var copy_index: u8 = 0;

    var encoded_buffer = try std.ArrayList(u8).initCapacity(alloc, std.heap.pageSize());
    var encoder = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, null);

    while (true) {
        // Read as much of stdin there is
        const bytes = File.stdin().readStreaming(io, &.{buf[copy_index..]}) catch |err| {
            if (err == File.ReadStreamingError.EndOfStream) {
                break;
            } else {
                return err;
            }
        };
        const length = copy_index + bytes;

        // Passthrough to stdout
        _ = try File.stdout().writeStreamingAll(io, buf[copy_index..length]);

        // Base64 encode
        const chunkable_length = length - (length % 3);
        var chunker = std.mem.window(u8, buf[0..chunkable_length], 3, 3);
        while (chunker.next()) |chunk| {
            var temp: [5]u8 = undefined;
            const s = encoder.encode(&temp, chunk);
            try encoded_buffer.appendSlice(alloc, s);
        }

        // Move left over bits to the start of the array
        copy_index = @intCast(length - chunkable_length);
        if (copy_index != 0) {
            @memmove(buf[0..copy_index], buf[chunkable_length..length]);
        }
    }
    // Encode last bytes
    var temp: [5]u8 = undefined;
    const s = encoder.encode(&temp, buf[0..copy_index]);
    try encoded_buffer.appendSlice(alloc, s);

    // OSC 52 Copying — written as one contiguous buffer so the terminal
    // receives the complete sequence in a single write.
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

    _ = try File.stdout().writeStreamingAll(io, osc_header);
    _ = try File.stdout().writeStreamingAll(io, encoded_buffer.items);
    _ = try File.stdout().writeStreamingAll(io, osc_footer);
    std.debug.print("\x1b[0;32mCopied To Pasteboard!\x1b[0m\n", .{});
}

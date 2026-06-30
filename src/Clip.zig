const std = @import("std");
const builtin = @import("builtin");

pub const OSC52 = @import("Clip/OSC52.zig");
// Ideally we would make else be `@compileError` but that
// messes up with the interface checking
pub const NSPasteboard =
    if (builtin.target.os.tag == .macos) @import("Clip/NSPasteboard.zig") else void;

// I am not sure if this is super idiomatic Zig or if this is bad practice, but
// by ensuring that all Clip backends implement the same methods, we are able
// to use the `anytype` type and we are able to have an interface that is able
// to dispatch statically

/// Check if a function with the given name and type exists.
/// `@compileError` if not
fn assertFn(comptime T: type, comptime name: []const u8, comptime Sig: type) void {
    if (!@import("std").meta.hasFn(T, name))
        @compileError(@typeName(T) ++ " missing fn " ++ name);
    if (@TypeOf(@field(T, name)) != Sig)
        @compileError(@typeName(T) ++ "." ++ name ++ " must be " ++ @typeName(Sig));
}

test {
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        // Only grab types of structs
        const T = @field(@This(), decl.name);
        if (@TypeOf(T) != type) continue;
        if (@typeInfo(T) != .@"struct") continue;

        // ==============================
        // === Interface Requirements ===
        // ==============================
        assertFn(T, "writeCopyBuffer", fn (*T, []const u8) anyerror!void);
        assertFn(T, "writePasteboard", fn (*T) anyerror!void);
    }
}

const std = @import("std");

pub const Warn = struct {
    pub fn warn(comptime fmt: []const u8, args: anytype) void {
        std.debug.print(fmt, args);
    }
};

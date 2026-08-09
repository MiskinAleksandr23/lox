const std = @import("std");
const Io = std.Io;
const Scanner = @import("scanner.zig").Scanner;

fn run(io: Io, alloc: std.mem.Allocator, source: []const u8) !void {
    _ = io;
    var scanner = try Scanner.init(alloc, source);
    errdefer scanner.deinit();

    try scanner.scanTokens();
    for (scanner.tokens.items) |token| {
        std.debug.print("{any}: {s}\n", .{ token.tokenType, token.lexeme });
    }
}

pub fn runFile(io: Io, alloc: std.mem.Allocator, path: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const contents = try cwd.readFileAlloc(io, path, alloc, .unlimited);
    try run(io, alloc, contents);
}
pub fn runPrompt(io: Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = alloc;
}

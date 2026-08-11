const std = @import("std");
const Io = std.Io;
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const Interpreter = @import("interpreter.zig").Interpreter;

fn run(io: Io, alloc: std.mem.Allocator, source: []const u8) !void {
    _ = io;
    var scanner = try Scanner.init(alloc, source);
    errdefer scanner.deinit();

    try scanner.scanTokens();
    const tokens = scanner.tokens.items;

    var parser: Parser = .init(tokens, alloc);
    const expr = try parser.parse();

    var interpreter: Interpreter = .init(alloc);
    try interpreter.interpret(expr);
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

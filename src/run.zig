const std = @import("std");
const Io = std.Io;
const Environment = @import("environment.zig").Environment;
const Reporter = @import("diagnostic.zig").Reporter;
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const Interpreter = @import("interpreter.zig").Interpreter;
const errors = @import("errors.zig");

pub const RunFailure =
    errors.ScannerFailure ||
    errors.ParserFailure ||
    errors.InterpreterFailure;

pub const RunFileFailure = Io.Dir.ReadFileAllocError || RunFailure;

fn run(ast_alloc: std.mem.Allocator, runtime_alloc: std.mem.Allocator, source: []const u8, reporter: *Reporter, output: *Io.Writer, diagnostics: *Io.Writer) RunFailure!void {
    reporter.clear();
    var scanner = try Scanner.init(ast_alloc, source, reporter);
    defer scanner.deinit();

    try scanner.scanTokens();
    const tokens = scanner.tokens.items;

    var parser: Parser = .init(tokens, ast_alloc, reporter);
    const expr = try parser.parse();

    var globals: Environment = .init(runtime_alloc);
    defer globals.deinit();

    var interpreter: Interpreter = .init(ast_alloc, &globals, reporter, output, diagnostics);
    try interpreter.interpret(expr);
}

pub fn runFile(io: Io, program_alloc: std.mem.Allocator, runtime_alloc: std.mem.Allocator, path: []const u8, reporter: *Reporter, output: *Io.Writer, diagnostics: *Io.Writer) RunFileFailure!void {
    reporter.clear();
    const cwd = std.Io.Dir.cwd();
    const contents = try cwd.readFileAlloc(io, path, program_alloc, .unlimited);
    try run(program_alloc, runtime_alloc, contents, reporter, output, diagnostics);
}
pub fn runPrompt(io: Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = alloc;
}

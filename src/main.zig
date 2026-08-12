const std = @import("std");
const Reporter = @import("diagnostic.zig").Reporter;
const run = @import("run.zig");

const usage_exit_code = 64;
const compile_exit_code = 65;
const infrastructure_exit_code = 71;
const io_exit_code = 74;
const runtime_exit_code = 70;

pub fn main(init: std.process.Init) u8 {
    const io = init.io;

    var program_arena = std.heap.ArenaAllocator.init(init.gpa);
    defer program_arena.deinit();
    const allocator = program_arena.allocator();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writerStreaming(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;

    const args = init.minimal.args.toSlice(allocator) catch {
        stderr.writeAll("Interpreter failure: out of memory.\n") catch return io_exit_code;
        return finish(stderr, infrastructure_exit_code);
    };

    if (args.len < 2) {
        printUsage(stderr) catch return io_exit_code;
        return finish(stderr, usage_exit_code);
    }

    if (args.len > 2) {
        stderr.writeAll("Error: expected exactly one script path.\n") catch return io_exit_code;
        printUsage(stderr) catch return io_exit_code;
        return finish(stderr, usage_exit_code);
    }
    const path = args[1];

    var reporter: Reporter = .{};

    run.runFile(io, allocator, init.gpa, path, &reporter, stdout, stderr) catch |err| {
        stdout.flush() catch {
            stderr.writeAll("I/O failure: could not flush stdout.\n") catch return io_exit_code;
            return finish(stderr, io_exit_code);
        };
        if (!(reporter.printLast(stderr) catch return io_exit_code)) {
            printInfrastructureFailure(stderr, err) catch return io_exit_code;
        }
        return finish(stderr, exitCode(err));
    };

    stdout.flush() catch {
        stderr.writeAll("I/O failure: could not flush stdout.\n") catch return io_exit_code;
        return finish(stderr, io_exit_code);
    };

    return 0;
}

fn printUsage(stderr: *std.Io.Writer) std.Io.Writer.Error!void {
    try stderr.writeAll("Usage: lox <script>\n");
}

fn printInfrastructureFailure(stderr: *std.Io.Writer, err: run.RunFileFailure) std.Io.Writer.Error!void {
    switch (err) {
        error.OutOfMemory => try stderr.writeAll("Interpreter failure: out of memory.\n"),
        error.WriteFailed => try stderr.writeAll("I/O failure: could not write output.\n"),
        error.ExecutionDepthExceeded => try stderr.writeAll("Interpreter failure: maximum execution depth exceeded.\n"),
        error.FeatureNotImplemented => try stderr.writeAll("Internal error: feature not implemented.\n"),
        else => try stderr.print("I/O failure: {s}.\n", .{@errorName(err)}),
    }
}

fn finish(stderr: *std.Io.Writer, code: u8) u8 {
    stderr.flush() catch return io_exit_code;
    return code;
}

fn exitCode(err: run.RunFileFailure) u8 {
    return switch (err) {
        error.InvalidCharacter,
        error.UnterminatedString,
        error.InvalidSyntax,
        error.NestingTooDeep,
        error.NumberLiteralOutOfRange,
        => compile_exit_code,

        error.InvalidOperand,
        error.DivisionByZero,
        error.IntegerOverflow,
        error.UndefinedVariable,
        => runtime_exit_code,

        error.OutOfMemory,
        error.ExecutionDepthExceeded,
        error.FeatureNotImplemented,
        => infrastructure_exit_code,

        error.WriteFailed => io_exit_code,

        else => io_exit_code,
    };
}

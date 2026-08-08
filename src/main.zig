const std = @import("std");
const run = @import("run.zig");
const Scanner = @import("scanner.zig").Scanner;
const AstPrinter = @import("visitors.zig").AstPrinter;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    const path = "lox/basic.lox";
    run.runFile(io, allocator, path[0..]) catch {
        std.debug.print("Compilation failed\n", .{});
    };
}

const std = @import("std");
const run = @import("run.zig");
const Scanner = @import("scanner.zig").Scanner;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    const path = "source/hello_world.lox";
    try run.runFile(io, allocator, path[0..]);
}
